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
        let rest = parts.dropFirst().map {
            placeholders.contains($0) ? "((?:\\s+[\\w'’-]+){1,3}?)" : "\\s+" + NSRegularExpression.escapedPattern(for: $0)
        }.joined()
        return "\\b" + head + rest + (parts.count > 1 ? "\\w*" : "")
    }

    // sth / sb stand for any few words: "harm to sth" matches "harm to the environment"
    nonisolated static let placeholders: Set<String> = ["sth", "sth.", "sb", "sb.", "sb's", "someone", "something", "one's", "oneself", "somebody"]

    /// What a match of `pattern(for:)` is replaced with in a cloze: the word's own words become one blank each
    /// run, and what stood for sth / sb stays, so "keep the project alive" reads "____ the project ____"
    /// instead of the whole phrase vanishing into one blank.
    nonisolated static func clozeTemplate(for term: String) -> String {
        var out = "", group = 0, lastWasBlank = false
        for part in term.lowercased().split(separator: " ").map(String.init) {
            if placeholders.contains(part) && !out.isEmpty {
                group += 1; out += "$\(group)"; lastWasBlank = false
            } else if !lastWasBlank {
                out += out.isEmpty ? "____" : " ____"; lastWasBlank = true
            }
        }
        return out
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
    /// How soon a sentence is needed: the card on screen, the next few cards, or saved words filled in quietly.
    enum Priority: Int, Comparable {
        case now, soon, background
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }
    private var queue: [(e: DictEntry, key: String, priority: Priority)] = []
    private var inFlight: String?
    private var failed: Set<String> = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("examples.json")
    }

    private init() {
        let saved = (try? JSONDecoder().decode([String: Example].self, from: Data(contentsOf: Self.fileURL))) ?? [:]
        // Sentences cached under the old, looser check may not use the word at all ("famed": "She gained fame…");
        // drop those so they're written again.
        cache = saved.filter { key, ex in
            let term = String(key.split(separator: "|").first ?? "")
            return WordMatch.found(term, in: ex.en) && GlossaryParser.cleanTerm(term) == term
        }
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
            if let b = Self.bundled(for: w, key: key) { w.example = b.en; w.exampleZh = b.zh; continue }
            request(Self.entry(for: w), urgent: true, key: key)
        }
        warmUp()
    }

    /// The sentence that ships with the dictionary, when the word is taught in the dictionary's own sense.
    private static func bundled(for w: Word, key: String) -> Example? {
        guard key == w.term, let d = Dictionary_.lookup(w.term), d.w == w.term, !d.ex.isEmpty else { return nil }
        return Example(en: d.ex, zh: d.exZh)
    }

    /// What to write a saved word's sentence from: the word itself, in its own part of speech and meanings.
    /// (Taking the dictionary entry instead went wrong two ways: a lookup of "exhausted" or "famed" lands on
    /// "exhaust" / "fame", whose sentence then never reached the saved word; and an entry that already has an
    /// example was skipped, though the word had dropped it for teaching another sense.)
    private static func entry(for w: Word) -> DictEntry {
        let d = Dictionary_.lookup(w.term).flatMap { $0.w == w.term ? $0 : nil }
        return DictEntry(w: w.term, ipa: w.ipa, pos: w.pos.isEmpty ? d?.pos ?? "" : w.pos,
                         zh: w.meanings.isEmpty ? d?.zh ?? [] : w.meanings,
                         def: w.definition.isEmpty ? d?.def ?? "" : w.definition, ex: "", exZh: "", lv: w.cefr)
    }

    /// Queue a word. The card on screen goes first, then the next few cards, then background filling — so the
    /// launch-time backfill of saved words (up to 40 of them) no longer holds up the cards about to be swiped to.
    func request(_ e: DictEntry, urgent: Bool = false, priority: Priority? = nil, key: String? = nil) {
        let key = key ?? e.w
        // a scanned word with phonetics still glued on ("accuracy takjoresi") gets no sentence: the model
        // would dutifully write the junk into it
        guard GlossaryParser.cleanTerm(e.w) == e.w else { return }
        guard e.ex.isEmpty, cache[key] == nil, !failed.contains(key), Self.isAvailable, inFlight != key else { return }
        var p = priority ?? (urgent ? .now : .soon)
        if let old = queue.first(where: { $0.key == key }) { p = min(p, old.priority) }   // never pushed back
        queue.removeAll { $0.key == key }
        // newest first within the same priority, so the latest card on screen is served first
        let at = p == .background ? queue.count : (queue.firstIndex { $0.priority >= p } ?? queue.count)
        queue.insert((e, key, p), at: at)
        if queue.count > 40 { queue.removeLast(queue.count - 40) }
        pump()
    }

    /// Give saved words without an example one (runs quietly in the background, a few at a time).
    func backfill(_ words: [Word]) {
        for w in words where w.example.isEmpty {
            let key = Self.key(term: w.term, meanings: w.meanings)
            if let c = cache[key] { w.example = c.en; w.exampleZh = c.zh; continue }
            if let b = Self.bundled(for: w, key: key) { w.example = b.en; w.exampleZh = b.zh; continue }
            request(Self.entry(for: w), priority: .background, key: key)
        }
        try? words.first?.modelContext?.save()
    }

    #if canImport(FoundationModels)
    /// A session made and pre-loaded ahead of time, so the next sentence doesn't wait for the model to load.
    @ObservationIgnored private var warm: LanguageModelSession?
    #endif
    /// Also called at launch: a cold model took several seconds longer to start the first sentence.
    func warmUp() {
        #if canImport(FoundationModels)
        guard Self.isAvailable, warm == nil else { return }
        let s = Self.makeSession()
        s.prewarm()
        warm = s
        #endif
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        let (e, key, _) = queue.removeFirst()
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
            warmUp()   // always keep one ready: the next card's sentence then starts without loading anything
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
            Each sentence is natural, everyday, 6 to 12 words long, and uses the target word in the given meaning. \
            The translation is fluent Traditional Chinese as used in Taiwan (never Simplified).
            """)
    }

    nonisolated private static func generate(_ e: DictEntry, session: LanguageModelSession,
                                             onPartial: @escaping @Sendable (Example) -> Void) async -> Example? {
        let prompt = "Word: \(e.w)\nPart of speech: \(e.pos)\nMeaning: \(e.zh.prefix(3).joined(separator: "、"))\(e.def.isEmpty ? "" : " (\(e.def))")"
            // without this the model often reaches for a relative ("recovering" for recovery), which fails the check below
            + "\nUse the word \"\(e.w)\" itself in the sentence (an ending like -s, -ed or -ing is fine, a different word of the same family is not)."
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
                    if !en.isEmpty { onPartial(Example(en: en, zh: cleanZh(zh))) }
                }
            } catch LanguageModelSession.GenerationError.guardrailViolation {
                break   // retrying the same way is refused again; go straight to the plain-text fallback
            } catch { continue }
            en = en.trimmingCharacters(in: .whitespacesAndNewlines)
            zh = cleanZh(zh)
            // The sentence must really use this word, not a relative of it ("machines" for "machinery"),
            // so it can also be blanked out for a cloze question.
            guard WordMatch.found(e.w, in: en), !zh.isEmpty, zh.count <= 60, en.split(separator: " ").count <= 24 else { continue }
            return Example(en: en, zh: zh)
        }
        return await plainFallback(e, prompt: prompt)
    }

    /// Some harmless words (ban, immigration) trip the default safety filter every time, so they never got an
    /// example. Asked for two plain lines under the setting meant for transforming text, they come back fine.
    nonisolated private static func plainFallback(_ e: DictEntry, prompt: String) async -> Example? {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard model.isAvailable else { return nil }
        let s = LanguageModelSession(model: model, instructions: """
            You write example sentences for Taiwanese high-school students learning English vocabulary. \
            Reply with exactly two lines: a natural everyday English sentence of 6 to 12 words that uses the target \
            word in the given meaning, then its fluent Traditional Chinese (Taiwan) translation. Nothing else.
            """)
        guard let text = try? await s.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 120)).content
        else { return nil }
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let han = #"\p{Han}"#
        guard let en = lines.first(where: { $0.range(of: han, options: .regularExpression) == nil }),
              let zhLine = lines.first(where: { $0.range(of: han, options: .regularExpression) != nil }),
              WordMatch.found(e.w, in: en), en.split(separator: " ").count <= 24 else { return nil }
        let zh = cleanZh(zhLine)
        return zh.isEmpty || zh.count > 60 ? nil : Example(en: en, zh: zh)
    }

    /// Greedy decoding sometimes runs on past the translation ("…革命。」}  }  }  }"); keep the sentence only.
    nonisolated static func cleanZh(_ z: String) -> String {
        var t = z
        if let i = t.firstIndex(where: { "{}".contains($0) }) { t = String(t[..<i]) }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("」"), !t.contains("「") { t.removeLast() }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
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
