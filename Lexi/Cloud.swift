import Foundation
import SwiftData
import Security

/// JuanGo's Supabase project. The publishable key is meant to ship inside apps: what it can reach is limited by
/// the row-level security in supabase/schema.sql (each account sees only its own backup; shared lists only by code).
enum CloudConfig {
    static let url = URL(string: "https://zqvxfundqjegjveifqus.supabase.co")!
    static let key = "sb_publishable_gUOXTGlBLJQPrfEE1edEag_NAo5mI68"
    static let redirect = "juango://login-callback"
    static var configured: Bool { !url.absoluteString.contains("PROJECT") }
}

/// Account (email sign-in link), backup sync and share codes, talking to Supabase's REST API directly.
@MainActor @Observable
final class Cloud {
    static let shared = Cloud()

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
        var email: String
    }
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    struct SharedList: Decodable, Identifiable {
        var code: String
        var name: String
        var word_count: Int
        var updated_at: String?
        var id: String { code }
    }

    private(set) var session: Session?
    private(set) var syncing = false
    private(set) var lastSync: Date?
    /// set when a sign-in link comes back, so the UI can show what happened
    var notice: String?

    var signedIn: Bool { session != nil }

    private init() {
        session = Keychain.read("session").flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
        lastSync = UserDefaults.standard.object(forKey: "cloud.lastSync") as? Date
    }

    // MARK: Sign in

    /// Emails a sign-in link; opening it on this iPhone comes back through juango://login-callback.
    func sendLink(to email: String) async throws {
        var c = URLComponents(url: CloudConfig.url.appendingPathComponent("auth/v1/otp"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "redirect_to", value: CloudConfig.redirect)]
        _ = try await send(c.url!, method: "POST", json: ["email": email.trimmingCharacters(in: .whitespaces), "create_user": true],
                           auth: false)
    }

    /// juango://login-callback#access_token=…&refresh_token=…&expires_in=…  (or #error=…&error_description=…)
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "juango" else { return false }
        let raw = url.fragment ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?.query ?? ""
        var p: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") ?? String($0) }
            if kv.count == 2 { p[kv[0]] = kv[1] }
        }
        if let err = p["error_description"] ?? p["error"] {
            notice = err.contains("expired") ? "登入連結已過期，請重新寄一次" : "登入失敗：\(err)"
            return true
        }
        guard let access = p["access_token"], let refresh = p["refresh_token"] else { return true }
        let expires = Double(p["expires_in"] ?? "") ?? 3600
        guard let claims = Self.claims(access), let sub = claims["sub"] as? String else { notice = "登入失敗：看不懂登入資料"; return true }
        store(Session(accessToken: access, refreshToken: refresh, expiresAt: .now.addingTimeInterval(expires - 60),
                      userID: sub, email: claims["email"] as? String ?? ""))
        notice = "已登入 \(session?.email ?? "")"
        return true
    }

    func signOut() {
        if let token = session?.accessToken {
            var req = URLRequest(url: CloudConfig.url.appendingPathComponent("auth/v1/logout"))
            req.httpMethod = "POST"
            req.setValue(CloudConfig.key, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            Task { _ = try? await URLSession.shared.data(for: req) }
        }
        store(nil)
        lastSync = nil
        UserDefaults.standard.removeObject(forKey: "cloud.lastSync")
    }

    private func store(_ s: Session?) {
        session = s
        if let s, let d = try? JSONEncoder().encode(s) { Keychain.write("session", d) } else { Keychain.delete("session") }
    }

    private static func claims(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }

    private func accessToken() async throws -> String {
        guard var s = session else { throw Failure(message: "請先登入") }
        if s.expiresAt > .now { return s.accessToken }
        var c = URLComponents(url: CloudConfig.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        do {
            let d = try await send(c.url!, method: "POST", json: ["refresh_token": s.refreshToken], auth: false)
            guard let o = try JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let access = o["access_token"] as? String, let refresh = o["refresh_token"] as? String
            else { throw Failure(message: "登入資料更新失敗") }
            s.accessToken = access; s.refreshToken = refresh
            s.expiresAt = .now.addingTimeInterval((o["expires_in"] as? Double ?? 3600) - 60)
            store(s)
            return access
        } catch let f as Failure where f.message.contains("401") || f.message.contains("400") || f.message.contains("無效") {
            store(nil)
            throw Failure(message: "登入已過期，請重新登入")
        }
    }

    // MARK: Backup sync

    /// Pulls the cloud backup into this device (merge, nothing deleted), then pushes the merged result back.
    @discardableResult
    func sync(_ ctx: ModelContext) async throws -> String {
        guard signedIn, !syncing else { return "" }
        syncing = true
        defer { syncing = false }
        var result = "已上傳"
        if let remote = try await download() {
            let r = Backup.restore(remote, into: ctx, settings: false)
            result = "已同步（\(r)）"
        }
        try await upload(Backup.full(ctx))
        lastSync = .now
        UserDefaults.standard.set(lastSync, forKey: "cloud.lastSync")
        return result
    }

    /// Quiet push when the app goes to the background.
    func backgroundPush(_ ctx: ModelContext) {
        guard signedIn, !syncing else { return }
        let file = Backup.full(ctx)
        Task {
            try? await upload(file)
            lastSync = .now
            UserDefaults.standard.set(lastSync, forKey: "cloud.lastSync")
        }
    }

    private func upload(_ f: BackupFile) async throws {
        guard let s = session else { return }
        _ = try await send(rest("user_backups"), method: "POST",
                           json: ["user_id": s.userID, "data": try Self.json(f), "updated_at": ISO8601DateFormatter().string(from: .now)],
                           prefer: "resolution=merge-duplicates,return=minimal")
    }

    private func download() async throws -> BackupFile? {
        var c = URLComponents(url: rest("user_backups"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "select", value: "data")]
        let d = try await send(c.url!, method: "GET")
        guard let rows = try JSONSerialization.jsonObject(with: d) as? [[String: Any]], let data = rows.first?["data"] else { return nil }
        return try Self.decode(data)
    }

    // MARK: Share codes

    /// Uploads a list and returns its code; sharing the same list again updates it under the same code.
    func share(_ f: BackupFile, key: String) async throws -> String {
        let name = String((f.lists.first?.name ?? "清單").prefix(60))
        let body: [String: Any] = ["name": name, "data": try Self.json(f), "word_count": f.words.count,
                                   "updated_at": ISO8601DateFormatter().string(from: .now)]
        let codes = UserDefaults.standard.dictionary(forKey: "cloud.shareCodes") as? [String: String] ?? [:]
        if let code = codes[key] {
            var c = URLComponents(url: rest("shared_lists"), resolvingAgainstBaseURL: false)!
            c.queryItems = [URLQueryItem(name: "code", value: "eq.\(code)")]
            let d = try await send(c.url!, method: "PATCH", json: body, prefer: "return=representation")
            if let rows = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]], !rows.isEmpty { return code }
        }
        let d = try await send(rest("shared_lists"), method: "POST", json: body, prefer: "return=representation")
        guard let rows = try JSONSerialization.jsonObject(with: d) as? [[String: Any]], let code = rows.first?["code"] as? String
        else { throw Failure(message: "建立分享代碼失敗") }
        var updated = codes; updated[key] = code
        UserDefaults.standard.set(updated, forKey: "cloud.shareCodes")
        return code
    }

    /// Anyone (signed in or not) can fetch a list by its code.
    func fetch(code: String) async throws -> BackupFile {
        let d = try await send(rest("rpc/get_shared_list"), method: "POST", json: ["p_code": code], auth: session != nil)
        guard let rows = try JSONSerialization.jsonObject(with: d) as? [[String: Any]], let data = rows.first?["data"] else {
            throw Failure(message: "找不到代碼「\(Self.pretty(code))」的清單")
        }
        return try Self.decode(data)
    }

    func myLists() async throws -> [SharedList] {
        var c = URLComponents(url: rest("shared_lists"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "select", value: "code,name,word_count,updated_at"),
                        URLQueryItem(name: "order", value: "updated_at.desc")]
        return try JSONDecoder().decode([SharedList].self, from: try await send(c.url!, method: "GET"))
    }

    func deleteList(_ code: String) async throws {
        var c = URLComponents(url: rest("shared_lists"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "code", value: "eq.\(code)")]
        _ = try await send(c.url!, method: "DELETE")
        var codes = UserDefaults.standard.dictionary(forKey: "cloud.shareCodes") as? [String: String] ?? [:]
        codes = codes.filter { $0.value != code }
        UserDefaults.standard.set(codes, forKey: "cloud.shareCodes")
    }

    /// "K7Q3P9XM" → "K7Q3-P9XM"
    static func pretty(_ code: String) -> String {
        let c = code.uppercased().filter { $0.isLetter || $0.isNumber }
        return c.count == 8 ? "\(c.prefix(4))-\(c.suffix(4))" : c
    }

    // MARK: HTTP

    private func rest(_ path: String) -> URL { CloudConfig.url.appendingPathComponent("rest/v1/" + path) }

    private func send(_ url: URL, method: String, json: [String: Any]? = nil, prefer: String? = nil, auth: Bool = true) async throws -> Data {
        guard CloudConfig.configured else { throw Failure(message: "雲端還沒設定好") }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue(CloudConfig.key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(auth ? try await accessToken() : CloudConfig.key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json { req.httpBody = try JSONSerialization.data(withJSONObject: json) }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw Failure(message: "連不上伺服器，請檢查網路") }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (o?["msg"] ?? o?["message"] ?? o?["error_description"] ?? o?["error"]) as? String
            if status == 429 { throw Failure(message: "太頻繁了，請稍後再試") }
            throw Failure(message: "\(msg ?? "伺服器錯誤")（\(status)）")
        }
        return data
    }

    private static func json(_ f: BackupFile) throws -> Any {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: e.encode(f))
    }

    private static func decode(_ any: Any) throws -> BackupFile {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        guard let f = try? d.decode(BackupFile.self, from: JSONSerialization.data(withJSONObject: any)), f.app == "JuanGo"
        else { throw Failure(message: "雲端資料格式不對") }
        return f
    }
}

/// Small Keychain wrapper for the sign-in session.
nonisolated enum Keychain {
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "JuanGo.cloud", kSecAttrAccount as String: account]
    }
    static func read(_ account: String) -> Data? {
        var q = query(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
    }
    static func write(_ account: String, _ data: Data) {
        delete(account)
        var q = query(account); q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
    static func delete(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}
