import Foundation
import Security
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What the AI says about a word the dictionary doesn't have.
struct AIWordInfo: Codable, Hashable {
    var pos: String          // "n." / "v./n." …, may be empty
    var meanings: [String]   // Traditional Chinese (Taiwan)
    var def: String = ""     // short English definition
    var ipa: String = ""

    func entry(for term: String) -> DictEntry {
        DictEntry(w: term.lowercased(), ipa: ipa, pos: pos, zh: meanings, def: def, ex: "", exZh: "", lv: "—")
    }
}

/// Translates words that are not in the built-in dictionary (scanned off-list words, typed words, imported files).
/// Off by default (設定 › API); when on:
/// 1. the user's own OpenAI-compatible API (Agnes, OpenRouter, Groq, …) when a key is saved
/// 2. otherwise Apple Intelligence on the device (free, offline)
/// When off (or neither works) WordConfirmSheet falls back to Apple Translation.
/// Results are cached in Application Support/translations.json so a word is only asked once.
@MainActor @Observable
final class WordTranslator {
    static let shared = WordTranslator()

    enum Provider: Equatable { case api, onDevice, none }

    private(set) var cache: [String: AIWordInfo]
    private(set) var working: Set<String> = []
    private(set) var lastError: String?

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("translations.json")
    }

    private init() {
        cache = (try? JSONDecoder().decode([String: AIWordInfo].self, from: Data(contentsOf: Self.fileURL))) ?? [:]
    }

    var provider: Provider {
        guard AppSettings.shared.aiTranslate else { return .none }
        if !APIKey.value.isEmpty { return .api }
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return .onDevice }
        #endif
        return .none
    }

    var providerName: String {
        switch provider {
        case .api: AppSettings.shared.apiModel
        case .onDevice: "Apple Intelligence（裝置端）"
        case .none: AppSettings.shared.aiTranslate ? "無法使用" : "關閉"
        }
    }

    func cached(_ term: String) -> AIWordInfo? { cache[term.lowercased()] }

    /// One word (the 確認單字 sheet).
    func translate(_ term: String) async -> AIWordInfo? {
        await translate([term])[term.lowercased()]
    }

    /// Several words at once; the API gets up to 25 per request (free tiers allow few requests a minute).
    func translate(_ terms: [String]) async -> [String: AIWordInfo] {
        let keys = Array(Set(terms.map { $0.lowercased() }))
        var out: [String: AIWordInfo] = [:]
        var todo: [String] = []
        for k in keys { if let c = cache[k] { out[k] = c } else if !working.contains(k) { todo.append(k) } }
        guard !todo.isEmpty else { return out }
        working.formUnion(todo)
        defer { working.subtract(todo) }
        lastError = nil

        var got: [String: AIWordInfo] = [:]
        let provider = provider
        if provider == .api {
            let s = AppSettings.shared, key = APIKey.value
            for chunk in stride(from: 0, to: todo.count, by: 25).map({ Array(todo[$0..<min($0 + 25, todo.count)]) }) {
                do { got.merge(try await ChatAPI.translate(chunk, baseURL: s.apiBaseURL, model: s.apiModel, key: key)) { a, _ in a } }
                catch { lastError = error.localizedDescription; break }
            }
        }
        // Apple Intelligence for whatever the API didn't answer (or when there is no key)
        #if canImport(FoundationModels)
        if provider != .none, case .available = SystemLanguageModel.default.availability {
            for k in todo where got[k] == nil {
                if let r = await OnDevice.translate(k) { got[k] = r }
            }
        }
        #endif
        for (k, v) in got where !v.meanings.isEmpty { cache[k] = v; out[k] = v }
        save()
        return out
    }

    /// Saved words that have no meaning yet (added from a scan or a file before the AI answered):
    /// translate them in the background and fill them in, then let ExampleStore write an example.
    func fill(_ words: [Word], in ctx: ModelContext) {
        let empty = words.filter { $0.meanings.isEmpty }
        guard !empty.isEmpty else { return }
        Task {
            let r = await translate(empty.map(\.term))
            var done: [Word] = []
            for w in empty {
                guard let i = r[w.term.lowercased()], w.meanings.isEmpty else { continue }
                w.meanings = i.meanings
                if w.pos.isEmpty { w.pos = i.pos }
                if w.definition.isEmpty { w.definition = i.def }
                if w.ipa.isEmpty { w.ipa = i.ipa }
                done.append(w)
            }
            try? ctx.save()
            if !done.isEmpty { ExampleStore.shared.backfill(done) }
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(cache) { try? d.write(to: Self.fileURL, options: .atomic) }
    }
}

// MARK: - OpenAI-compatible chat API

nonisolated private let instructions = "English→Traditional Chinese (Taiwan) dictionary for students. Never use Simplified Chinese."

nonisolated enum ChatAPI {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func endpoint(_ base: String) -> URL? {
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while b.hasSuffix("/") { b.removeLast() }
        if !b.hasSuffix("/chat/completions") { b += "/chat/completions" }
        return URL(string: b)
    }

    static func translate(_ words: [String], baseURL: String, model: String, key: String) async throws -> [String: AIWordInfo] {
        guard let url = endpoint(baseURL), url.scheme == "https" else { throw Failure(message: "API 網址要用 https://") }
        let prompt = """
            Words: \(words.joined(separator: ", "))
            JSON only: {"word": {"pos": "n./v./adj.…", "meanings": ["1–3 common meanings"], "def": "short English definition", "ipa": ""}}
            """
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [["role": "system", "content": instructions], ["role": "user", "content": prompt]],
        ]
        var req = URLRequest(url: url, timeoutInterval: 40)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
            throw Failure(message: status == 401 ? "API key 無效" : status == 429 ? "請求太頻繁，稍後再試" : (msg ?? "HTTP \(status)"))
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = ((root["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        else { throw Failure(message: "回應格式不對") }
        return parse(content, words: words)
    }

    /// The model's text → infos; tolerant of ```json fences and of extra text around the object.
    static func parse(_ content: String, words: [String]) -> [String: AIWordInfo] {
        guard let a = content.firstIndex(of: "{"), let b = content.lastIndex(of: "}"),
              let obj = try? JSONSerialization.jsonObject(with: Data(content[a...b].utf8)) as? [String: Any]
        else { return [:] }
        var out: [String: AIWordInfo] = [:]
        for (k, v) in obj {
            guard let d = v as? [String: Any] else { continue }
            let meanings = (d["meanings"] as? [String] ?? (d["meanings"] as? String).map { [$0] } ?? [])
                .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: "；;，,、")) }
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            out[k.lowercased()] = AIWordInfo(pos: d["pos"] as? String ?? "", meanings: Array(meanings.prefix(4)),
                                             def: d["def"] as? String ?? "",
                                             ipa: (d["ipa"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/[] ")))
        }
        return out
    }
}

// MARK: - Apple Intelligence

#if canImport(FoundationModels)
@Generable
struct GeneratedWordInfo {
    @Guide(description: "Part of speech such as n., v., adj., adv.; several joined with /")
    var pos: String
    @Guide(description: "Two or three common meanings in Traditional Chinese (Taiwan)", .count(1...3))
    var meanings: [String]
    @Guide(description: "A short English definition")
    var definition: String
}

nonisolated enum OnDevice {
    static func translate(_ word: String) async -> AIWordInfo? {
        let session = LanguageModelSession(instructions: instructions)
        guard let r = try? await session.respond(to: "Word: \(word)", generating: GeneratedWordInfo.self).content else { return nil }
        let meanings = r.meanings.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return meanings.isEmpty ? nil : AIWordInfo(pos: r.pos, meanings: meanings, def: r.definition)
    }
}
#endif

// MARK: - Keychain

/// The user's own API key, kept in the Keychain (never in the source code or UserDefaults).
nonisolated enum APIKey {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                               kSecAttrService as String: "JuanGo.api", kSecAttrAccount as String: "apiKey"]

    static var value: String {
        get {
            var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let d = item as? Data else { return "" }
            return String(data: d, encoding: .utf8) ?? ""
        }
        set {
            SecItemDelete(query as CFDictionary)
            let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return }
            var q = query; q[kSecValueData as String] = Data(v.utf8)
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
