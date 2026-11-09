import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Example sentences for words whose dictionary entry has none (about 98% of the 大考 list).
/// Every 探索 card shows an example + translation, so Lexi writes one with the on-device
/// model the first time a word needs it and keeps it in Application Support/examples.json.
@MainActor @Observable
final class ExampleStore {
    static let shared = ExampleStore()

    struct Example: Codable, Hashable { var en: String; var zh: String }

    private(set) var cache: [String: Example]
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

    func isGenerating(_ e: DictEntry) -> Bool { inFlight == e.w || queue.contains { $0.key == e.w } }

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

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        let (e, key) = queue.removeFirst()
        inFlight = key
        Task {
            let r = await Self.generate(e)
            inFlight = nil
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

    nonisolated private static func generate(_ e: DictEntry) async -> Example? {
        #if canImport(FoundationModels)
        let session = LanguageModelSession(instructions: """
            You write example sentences for Taiwanese high-school students learning English vocabulary. \
            Each sentence is natural, everyday, 8 to 16 words long, and uses the target word in the given meaning. \
            The translation is fluent Traditional Chinese as used in Taiwan (never Simplified).
            """)
        let prompt = "Word: \(e.w)\nPart of speech: \(e.pos)\nMeaning: \(e.zh.prefix(3).joined(separator: "、"))\(e.def.isEmpty ? "" : " (\(e.def))")"
        for _ in 0..<2 {
            guard let r = try? await session.respond(to: prompt, generating: GeneratedExample.self).content else { continue }
            let en = r.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let zh = r.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            // The sentence must really use the word (any inflection: stem of up to 5 letters).
            let stem = String(e.w.lowercased().prefix(max(3, min(5, e.w.count - 1))))
            guard en.lowercased().contains(stem), !zh.isEmpty, en.split(separator: " ").count <= 24 else { continue }
            return Example(en: en, zh: zh)
        }
        #endif
        return nil
    }
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
