import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - File format

/// A JuanGo file: either a full backup (words with progress, lists, review history, settings)
/// or one shared word list (words only, no one's progress). Plain JSON so it survives LINE / AirDrop / 檔案.
struct BackupFile: Codable {
    enum Kind: String, Codable { case backup, list }

    var app = "JuanGo"
    var format = 1
    var kind: Kind
    var exportedAt = Date()
    var words: [WordRecord]
    var lists: [ListRecord]
    var logs: [LogRecord]? = nil
    var settings: [String: SettingValue]? = nil

    struct WordRecord: Codable {
        var term, ipa, pos: String
        var meanings: [String]
        var definition, example, exampleZh, cefr: String
        // progress (backups only)
        var srsLevel: Int? = nil
        var dueDate: Date? = nil
        var lastReviewed: Date? = nil
        var addedAt: Date? = nil
        var favorite: Bool? = nil
        var inMyWords: Bool? = nil
        var reviewCount: Int? = nil
    }
    struct ListRecord: Codable {
        var name: String
        var createdAt: Date? = nil
        var terms: [String]
    }
    struct LogRecord: Codable {
        var term: String
        var date: Date
        var result: Int
        var wasNew: Bool
    }
    enum SettingValue: Codable, Equatable {
        case bool(Bool), int(Int), double(Double), string(String)
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode(Bool.self) { self = .bool(v) }
            else if let v = try? c.decode(Int.self) { self = .int(v) }
            else if let v = try? c.decode(Double.self) { self = .double(v) }
            else { self = .string(try c.decode(String.self)) }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .bool(let v): try c.encode(v)
            case .int(let v): try c.encode(v)
            case .double(let v): try c.encode(v)
            case .string(let v): try c.encode(v)
            }
        }
        var bool: Bool? { if case .bool(let v) = self { v } else { nil } }
        var int: Int? { if case .int(let v) = self { v } else { nil } }
        var double: Double? { switch self { case .double(let v): v; case .int(let v): Double(v); default: nil } }
        var string: String? { if case .string(let v) = self { v } else { nil } }
    }

    var summary: String {
        var parts = ["\(words.count) 個單字"]
        if !lists.isEmpty { parts.append("\(lists.count) 個清單") }
        if let logs, !logs.isEmpty { parts.append("\(logs.count) 筆複習紀錄") }
        return parts.joined(separator: "、")
    }
    var title: String {
        switch kind {
        case .backup: "JuanGo 備份（\(exportedAt.formatted(date: .abbreviated, time: .shortened))）"
        case .list: "單字清單「\(lists.first?.name ?? "未命名")」"
        }
    }
}

// MARK: - Export / restore

@MainActor
enum Backup {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Everything on this device.
    static func full(_ ctx: ModelContext) -> BackupFile {
        let words = (try? ctx.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
        let lists = (try? ctx.fetch(FetchDescriptor<WordList>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let logs = (try? ctx.fetch(FetchDescriptor<ReviewLog>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return BackupFile(kind: .backup,
                          words: words.map { record($0, progress: true) },
                          lists: lists.map { .init(name: $0.name, createdAt: $0.createdAt, terms: $0.words.map(\.term)) },
                          logs: logs.map { .init(term: $0.term, date: $0.date, result: $0.result, wasNew: $0.wasNew) },
                          settings: AppSettings.shared.backupValues)
    }

    /// One list to give to someone else: the words and their meanings, without progress.
    static func list(name: String, words: [Word]) -> BackupFile {
        BackupFile(kind: .list, words: words.map { record($0, progress: false) },
                   lists: [.init(name: name, terms: words.map(\.term))])
    }

    private static func record(_ w: Word, progress: Bool) -> BackupFile.WordRecord {
        var r = BackupFile.WordRecord(term: w.term, ipa: w.ipa, pos: w.pos, meanings: w.meanings, definition: w.definition,
                                      example: w.example, exampleZh: w.exampleZh, cefr: w.cefr)
        if progress {
            r.srsLevel = w.srsLevel; r.dueDate = w.dueDate; r.lastReviewed = w.lastReviewed; r.addedAt = w.addedAt
            r.favorite = w.favorite; r.inMyWords = w.inMyWords; r.reviewCount = w.reviewCount
        }
        return r
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    /// Writes the file to a temporary folder (for the share sheet) and returns its URL.
    static func write(_ f: BackupFile) throws -> URL {
        let day = f.exportedAt.formatted(.iso8601.year().month().day())
        let base: String
        switch f.kind {
        case .backup: base = "JuanGo 備份 \(day)"
        case .list: base = "\(f.lists.first?.name ?? "清單") - JuanGo 清單"
        }
        let safe = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "-")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(safe + ".json")
        try encoder.encode(f).write(to: url, options: .atomic)
        return url
    }

    static func read(_ url: URL) throws -> BackupFile {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let f = try? d.decode(BackupFile.self, from: data), f.app == "JuanGo" else {
            throw Failure(message: "這不是 JuanGo 的備份或清單檔")
        }
        guard f.format <= 1 else { throw Failure(message: "這個檔案來自較新版的 JuanGo，請先更新 App") }
        return f
    }

    /// Merges a file into this device; nothing already here is deleted.
    /// Words already saved keep whichever progress was reviewed more recently.
    @discardableResult
    static func restore(_ f: BackupFile, into ctx: ModelContext, settings: Bool = true) -> String {
        var existing: [String: Word] = [:]
        for w in (try? ctx.fetch(FetchDescriptor<Word>())) ?? [] { existing[w.term] = w }
        var added = 0, updated = 0

        for r in f.words where !r.term.isEmpty {
            let w: Word
            if let e = existing[r.term] {
                w = e
                if e.meanings.isEmpty { e.meanings = r.meanings }
                if e.pos.isEmpty { e.pos = r.pos }
                if e.definition.isEmpty { e.definition = r.definition }
                if e.example.isEmpty { e.example = r.example; e.exampleZh = r.exampleZh }
                if e.ipa.isEmpty { e.ipa = r.ipa }
                if f.kind == .backup, (r.lastReviewed ?? .distantPast) > (e.lastReviewed ?? .distantPast) {
                    applyProgress(r, to: e); updated += 1
                }
                if r.favorite == true { e.favorite = true }
                if r.inMyWords == true || f.kind == .list { e.inMyWords = true }
            } else {
                w = Word(entry: DictEntry(w: r.term, ipa: r.ipa, pos: r.pos, zh: r.meanings, def: r.definition,
                                          ex: r.example, exZh: r.exampleZh, lv: r.cefr))
                if f.kind == .backup {
                    applyProgress(r, to: w)
                    if let d = r.addedAt { w.addedAt = d }
                    w.favorite = r.favorite ?? false
                    w.inMyWords = r.inMyWords ?? true
                }
                ctx.insert(w)
                existing[r.term] = w
                added += 1
            }
        }

        var lists: [String: WordList] = [:]
        for l in (try? ctx.fetch(FetchDescriptor<WordList>())) ?? [] { lists[l.name] = l }
        for r in f.lists {
            let l: WordList
            if let e = lists[r.name] { l = e } else {
                l = WordList(name: r.name)
                if let d = r.createdAt { l.createdAt = d }
                ctx.insert(l); lists[r.name] = l
            }
            for t in r.terms {
                guard let w = existing[t], !w.lists.contains(where: { $0.persistentModelID == l.persistentModelID }) else { continue }
                w.lists.append(l)
            }
        }

        var logCount = 0
        if let logs = f.logs, !logs.isEmpty {
            let key = { (t: String, d: Date) in "\(t)|\(Int(d.timeIntervalSince1970))" }
            var have = Set(((try? ctx.fetch(FetchDescriptor<ReviewLog>())) ?? []).map { key($0.term, $0.date) })
            for r in logs where !have.contains(key(r.term, r.date)) {
                let log = ReviewLog(term: r.term, result: r.result, wasNew: r.wasNew)
                log.date = r.date
                ctx.insert(log); have.insert(key(r.term, r.date)); logCount += 1
            }
        }

        if f.kind == .backup, settings, let s = f.settings { AppSettings.shared.apply(backup: s) }
        try? ctx.save()

        var parts = ["新增 \(added) 個單字"]
        if updated > 0 { parts.append("更新 \(updated) 個字的進度") }
        if logCount > 0 { parts.append("還原 \(logCount) 筆複習紀錄") }
        if f.kind == .list, let name = f.lists.first?.name { parts.append("加入清單「\(name)」") }
        return parts.joined(separator: "，")
    }

    private static func applyProgress(_ r: BackupFile.WordRecord, to w: Word) {
        if let v = r.srsLevel { w.srsLevel = v }
        w.dueDate = r.dueDate
        w.lastReviewed = r.lastReviewed
        if let v = r.reviewCount { w.reviewCount = v }
    }
}

// MARK: - Settings in backups

extension AppSettings {
    var backupValues: [String: BackupFile.SettingValue] {
        ["level": .string(level), "dailyGoal": .int(dailyGoal), "reminderOn": .bool(reminderOn),
         "reminderMinutes": .int(reminderMinutes), "appearance": .int(appearance), "fontStyle": .int(fontStyle),
         "themeID": .string(themeID), "muted": .bool(muted), "showTranslation": .bool(showTranslation),
         "haptics": .bool(haptics), "speechRate": .double(speechRate), "listShowMeaning": .bool(listShowMeaning),
         "detailAutoSpeak": .bool(detailAutoSpeak), "exploreShowIPA": .bool(exploreShowIPA),
         "aiTranslate": .bool(aiTranslate), "apiBaseURL": .string(apiBaseURL), "apiModel": .string(apiModel)]
    }

    func apply(backup s: [String: BackupFile.SettingValue]) {
        if let v = s["level"]?.string { level = v }
        if let v = s["dailyGoal"]?.int { dailyGoal = v }
        if let v = s["reminderMinutes"]?.int { reminderMinutes = v }
        if let v = s["reminderOn"]?.bool { reminderOn = v }
        if let v = s["appearance"]?.int { appearance = v }
        if let v = s["fontStyle"]?.int { fontStyle = v }
        if let v = s["themeID"]?.string { themeID = v }
        if let v = s["muted"]?.bool { muted = v }
        if let v = s["showTranslation"]?.bool { showTranslation = v }
        if let v = s["haptics"]?.bool { haptics = v }
        if let v = s["speechRate"]?.double { speechRate = v }
        if let v = s["listShowMeaning"]?.bool { listShowMeaning = v }
        if let v = s["detailAutoSpeak"]?.bool { detailAutoSpeak = v }
        if let v = s["exploreShowIPA"]?.bool { exploreShowIPA = v }
        if let v = s["aiTranslate"]?.bool { aiTranslate = v }
        if let v = s["apiBaseURL"]?.string { apiBaseURL = v }
        if let v = s["apiModel"]?.string { apiModel = v }
    }
}

// MARK: - UI helpers

/// Shows the system share sheet (AirDrop, LINE, 儲存到「檔案」…) for a file, on top of whatever is on screen —
/// presenting it from UIKit avoids clashing with SwiftUI sheets, file importers and dialogs on the same view.
@MainActor
func presentShareSheet(_ url: URL) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          var top = scene.keyWindow?.rootViewController else { return }
    while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    vc.popoverPresentationController?.sourceView = top.view
    vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
    top.present(vc, animated: true)
}

extension View {
    /// Asks before merging a picked JuanGo file into this device, then reports what happened.
    func backupImport(_ file: Binding<BackupFile?>, ctx: ModelContext, done: @escaping (String) -> Void) -> some View {
        modifier(BackupImportConfirm(file: file, ctx: ctx, done: done))
    }
}

private struct BackupImportConfirm: ViewModifier {
    @Binding var file: BackupFile?
    let ctx: ModelContext
    let done: (String) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(file?.title ?? "", isPresented: Binding(get: { file != nil }, set: { if !$0 { file = nil } }),
                                   titleVisibility: .visible, presenting: file) { f in
            Button(f.kind == .backup ? "合併還原" : "加入清單") { done(Backup.restore(f, into: ctx)); file = nil }
            Button("取消", role: .cancel) { file = nil }
        } message: { f in
            Text(f.kind == .backup
                 ? "\(f.summary)。會和這台裝置上的資料合併，不會刪除任何東西；同一個字保留最近複習過的進度。設定也會換成備份裡的。"
                 : "\(f.summary)。會加進「我的單字」和同名清單，你自己的進度不受影響。")
        }
    }
}

#if DEBUG
extension Backup {
    /// `SIMCTL_CHILD_LEXI_BACKUP_SELFTEST=1`: round-trips a backup and a shared list through files,
    /// using in-memory stores only (the app's own data is not touched), prints the result and exits.
    static func selfTest() {
        func store() -> ModelContext {
            let c = try! ModelContainer(for: Word.self, WordList.self, ReviewLog.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            return ModelContext(c)
        }
        let a = store()
        let entries = Array(Dictionary_.all.prefix(5))
        for e in entries { Library.add(e, in: a) }
        let words = try! a.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.term)]))
        words[0].srsLevel = 3; words[0].reviewCount = 7; words[0].lastReviewed = .now; words[0].favorite = true
        let l = WordList(name: "測試/清單"); a.insert(l); words[1].lists.append(l); words[2].lists.append(l)
        a.insert(ReviewLog(term: words[0].term, result: 2, wasNew: true))
        try! a.save()

        let url = try! write(full(a))
        let f = try! read(url)
        let b = store()
        let r1 = restore(f, into: b)
        let r2 = restore(f, into: b)   // second time: nothing new
        let bw = try! b.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.term)]))
        let bl = try! b.fetch(FetchDescriptor<WordList>())
        let logs = try! b.fetchCount(FetchDescriptor<ReviewLog>())
        let w0 = bw.first { $0.term == words[0].term }!
        print("SELFTEST file:", url.lastPathComponent)
        print("SELFTEST restore1:", r1, "| restore2:", r2)
        print("SELFTEST words", bw.count, "lists", bl.map { "\($0.name)=\($0.words.count)" }, "logs", logs,
              "w0 level", w0.srsLevel, "reviews", w0.reviewCount, "fav", w0.favorite)

        let lu = try! write(list(name: l.name, words: l.words))
        let lf = try! read(lu)
        let c = store()
        print("SELFTEST list file:", lu.lastPathComponent, "|", restore(lf, into: c),
              "| progress kept out:", (try! c.fetch(FetchDescriptor<Word>())).allSatisfy { $0.srsLevel == 0 })
        exit(0)
    }
}
#endif
