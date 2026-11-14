import Foundation
import SwiftData
/// Finds a word in a sentence, allowing simple inflections: use → using, study → studied, run → running,
/// and for phrases an inflected first word: look forward to → looking forward to.
enum WordMatch {
    nonisolated static func pattern(for term: String) -> String? {
        let parts = term.lowercased().split(separator: " ").map(String.init)
        guard let first = parts.first else { return nil }
        // the word itself plus any ending (uses, used, running); dropped -e and y → i only before a real suffix,
        // so "use" matches "using" but not "us"
        var forms = [NSRegularExpression.escapedPattern(for: first) + "\\w*"]
        if first.count >= 3, first.hasSuffix("e") {
            forms.append(NSRegularExpression.escapedPattern(for: String(first.dropLast())) + "(?:ing|ion|ions|able)\\b")
        }
        if first.count >= 3, first.hasSuffix("y") {
            forms.append(NSRegularExpression.escapedPattern(for: String(first.dropLast())) + "i(?:ed|es|er|est|ly|ness|ful)\\b")
        }
        let head = "(?:" + forms.joined(separator: "|") + ")"
        let rest = parts.dropFirst().map { "\\s+" + NSRegularExpression.escapedPattern(for: $0) }.joined()
        return "\\b" + head + rest + (parts.count > 1 ? "\\w*" : "")
    }

    nonisolated static func found(_ term: String, in sentence: String) -> Bool {
        guard let p = pattern(for: term) else { return false }
        return sentence.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Example sentences for words whose dictionary entry has none (about 98% of the 大考 list).
/// Every 探索 card shows an example + translation, so JuanGo writes one with the on-device
/// model the first time a word needs it and keeps it in Application Support/examples.json.
@MainActor @Observable
final class ExampleStore {
    static let shared = ExampleStore()

    struct Example: Codable, Hashable { var en: String; var zh: String }

    private(set) var cache: [String: Example]
    /// The sentence being written right now, as far as the model has got (shown on the card while it streams in).
    private(set) var partial: [String: Example] = [:]
    private var queue: [(e: DictEntry, key: String)] = []
    private var inFlight: String?
    private var failed: Set<String> = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("examples.json")
    }

    private init() {
        cache = (try? JSONDecoder().decode([String: Example].self, from: Data(contentsOf: Self.fileURL))) ?? [:]
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    /// The entry's own example, or a generated one if we have it.
    func example(for e: DictEntry) -> Example? {
        if !e.ex.isEmpty { return Example(en: e.ex, zh: e.exZh) }
        return cache[e.w]
    }

    /// Cache key for a word taught with these meanings: the word itself for the dictionary's main sense,
    /// "book|預訂" when a word list teaches another sense (so "book v. 預訂" never gets "I read a new book").
    static func key(term: String, meanings: [String]) -> String {
        guard let first = meanings.first, let d = Dictionary_.lookup(term), d.w == term, let main = d.zh.first else { return term }
        let same = meanings.contains { main.contains($0) || $0.contains(main) }
        return same ? term : "\(term)|\(first)"
    }

    /// Fills `ex`/`exZh` from the cache so new `Word`s get the example too.
    func filled(_ e: DictEntry) -> DictEntry {
        guard e.ex.isEmpty, let c = cache[Self.key(term: e.w, meanings: e.zh)] else { return e }
        var e = e; e.ex = c.en; e.exZh = c.zh; return e
    }

    func partial(for w: Word) -> Example? { partial[Self.key(term: w.term, meanings: w.meanings)] }
    func partial(for e: DictEntry) -> Example? { partial[e.w] }

    func isGenerating(_ e: DictEntry) -> Bool { inFlight == e.w || queue.contains { $0.key == e.w } }
    func isGenerating(_ w: Word) -> Bool {
        guard w.example.isEmpty else { return false }
        let key = Self.key(term: w.term, meanings: w.meanings)
        return inFlight == key || queue.contains { $0.key == key }
    }

    /// Practice calls this for the card on screen and the next few: the first one jumps the queue, the rest follow it,
    /// so a sentence is usually written before its card comes up. Words that already have one are skipped.
    func prepare(_ words: [Word]) {
        for w in words.reversed() where w.example.isEmpty {
            let key = Self.key(term: w.term, meanings: w.meanings)
            if let c = cache[key] { w.example = c.en; w.exampleZh = c.zh; continue }
            let e = key == w.term ? (Dictionary_.lookup(w.term) ?? Self.entry(for: w))
                                  : Self.entry(for: w)
            request(e, urgent: true, key: key)
        }
        warmUp()
    }

    private static func entry(for w: Word) -> DictEntry {
        DictEntry(w: w.term, ipa: w.ipa, pos: w.pos, zh: w.meanings, def: w.definition, ex: "", exZh: "", lv: w.cefr)
    }

    /// Queue a word; the newest requests go first so the card on screen is served before prefetches.
    func request(_ e: DictEntry, urgent: Bool = false, key: String? = nil) {
        let key = key ?? e.w
        guard e.ex.isEmpty, cache[key] == nil, !failed.contains(key), Self.isAvailable, inFlight != key else { return }
        queue.removeAll { $0.key == key }
        if urgent { queue.insert((e, key), at: 0) } else { queue.append((e, key)) }
        if queue.count > 40 { queue.removeLast(queue.count - 40) }
        pump()
    }

    /// Give saved words without an example one (runs quietly in the background, a few at a time).
    func backfill(_ words: [Word]) {
        for w in words where w.example.isEmpty {
            let key = Self.key(term: w.term, meanings: w.meanings)
            if let c = cache[key] { w.example = c.en; w.exampleZh = c.zh; continue }
            if key == w.term, let e = Dictionary_.lookup(w.term) { request(e); continue }
            // a sense of its own: write the example from the word's own part of speech and meanings
            request(DictEntry(w: w.term, ipa: w.ipa, pos: w.pos, zh: w.meanings, def: w.definition, ex: "", exZh: "", lv: w.cefr), key: key)
        }
        try? words.first?.modelContext?.save()
    }

    #if canImport(FoundationModels)
    /// A session made and pre-loaded ahead of time, so the next sentence doesn't wait for the model to load.
    @ObservationIgnored private var warm: LanguageModelSession?
    #endif
    private func warmUp() {
        #if canImport(FoundationModels)
        guard Self.isAvailable, warm == nil else { return }
        let s = Self.makeSession()
        s.prewarm()
        warm = s
        #endif
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        let (e, key) = queue.removeFirst()
        inFlight = key
        #if canImport(FoundationModels)
        let session = warm ?? Self.makeSession()
        warm = nil
        #endif
        Task {
            #if canImport(FoundationModels)
            let r = await Self.generate(e, session: session) { p in
                Task { @MainActor in if ExampleStore.shared.inFlight == key { ExampleStore.shared.partial[key] = p } }
            }
            if !queue.isEmpty { warmUp() }
            #else
            let r: Example? = nil
            #endif
            inFlight = nil
            partial[key] = nil
            if let r {
                cache[key] = r
                save()
                applyToSavedWord(e.w, key, r)
            } else {
                failed.insert(key)
            }
            pump()
        }
    }

    /// Words saved before their example existed pick it up here.
    var container: ModelContainer?
    private func applyToSavedWord(_ term: String, _ key: String, _ r: Example) {
        guard let ctx = container?.mainContext else { return }
        var fd = FetchDescriptor<Word>(predicate: #Predicate { $0.term == term }); fd.fetchLimit = 1
        if let w = try? ctx.fetch(fd).first, w.example.isEmpty, Self.key(term: w.term, meanings: w.meanings) == key {
            w.example = r.en; w.exampleZh = r.zh; try? ctx.save()
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(cache) { try? d.write(to: Self.fileURL, options: .atomic) }
    }

    #if canImport(FoundationModels)
    nonisolated private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You write example sentences for Taiwanese high-school students learning English vocabulary. \
            Each sentence is natural, everyday, 8 to 16 words long, and uses the target word in the given meaning. \
            The translation is fluent Traditional Chinese as used in Taiwan (never Simplified).
            """)
    }

    nonisolated private static func generate(_ e: DictEntry, session: LanguageModelSession,
                                             onPartial: @escaping @Sendable (Example) -> Void) async -> Example? {
        let prompt = "Word: \(e.w)\nPart of speech: \(e.pos)\nMeaning: \(e.zh.prefix(3).joined(separator: "、"))\(e.def.isEmpty ? "" : " (\(e.def))")"
        for attempt in 0..<2 {
            // greedy and capped: a short sentence comes back noticeably faster; the retry samples for a different one
            let options = attempt == 0 ? GenerationOptions(sampling: .greedy, maximumResponseTokens: 160)
                                       : GenerationOptions(maximumResponseTokens: 160)
            let s = attempt == 0 ? session : makeSession()
            // streamed, so the card can show the sentence word by word instead of a spinner for several seconds
            let stream = s.streamResponse(to: prompt, generating: GeneratedExample.self, options: options)
            var en = "", zh = ""
            do {
                for try await snap in stream {
                    en = snap.content.sentence ?? en
                    zh = snap.content.translation ?? zh
                    if !en.isEmpty { onPartial(Example(en: en, zh: zh)) }
                }
            } catch { continue }
            en = en.trimmingCharacters(in: .whitespacesAndNewlines)
            zh = zh.trimmingCharacters(in: .whitespacesAndNewlines)
            // The sentence must really use this word, not a relative of it ("machines" for "machinery"),
            // so it can also be blanked out for a cloze question.
            guard WordMatch.found(e.w, in: en), !zh.isEmpty, en.split(separator: " ").count <= 24 else { continue }
            return Example(en: en, zh: zh)
        }
        return nil
    }
    #endif
}

#if canImport(FoundationModels)
@Generable
struct GeneratedExample {
    @Guide(description: "One natural English example sentence that uses the target word")
    var sentence: String
    @Guide(description: "The sentence translated into Traditional Chinese (Taiwan)")
    var translation: String
}
#endif
