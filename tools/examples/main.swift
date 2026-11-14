import Foundation
import FoundationModels

// Usage: gen <words.json> <out.jsonl> <levels comma list> <shard index> <shard count>
@Generable struct GeneratedExample {
    @Guide(description: "One natural English example sentence that uses the target word")
    var sentence: String
    @Guide(description: "The sentence translated into Traditional Chinese (Taiwan)")
    var translation: String
}
struct Entry: Decodable { let w: String; let pos: String; let zh: [String]; let def: String?; let ex: String?; let lv: String? }

func cleanZh(_ z: String) -> String {
    var t = z
    if let i = t.firstIndex(where: { "{}".contains($0) }) { t = String(t[..<i]) }
    t = t.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasSuffix("」"), !t.contains("「") { t.removeLast() }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}
let instructions = """
    You write example sentences for Taiwanese high-school students learning English vocabulary. \
    Each sentence is natural, everyday, 6 to 12 words long, and uses the target word in the given meaning. \
    The translation is fluent Traditional Chinese as used in Taiwan (never Simplified).
    """
let plainInstructions = """
    You write example sentences for Taiwanese high-school students learning English vocabulary. \
    Reply with exactly two lines: a natural everyday English sentence of 6 to 12 words that uses the target \
    word in the given meaning, then its fluent Traditional Chinese (Taiwan) translation. Nothing else.
    """

@main struct Gen {
    static func main() async throws {
        let a = CommandLine.arguments
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: URL(fileURLWithPath: a[1])))
        let outURL = URL(fileURLWithPath: a[2])
        let levels = a[3].split(separator: ",").map(String.init)
        let shard = Int(a[4])!, shards = Int(a[5])!
        var done = Set<String>()
        // every out*.jsonl beside the output counts, so the shard count can change between runs
        let dir = outURL.deletingLastPathComponent()
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where f.hasPrefix("out") && f.hasSuffix(".jsonl") {
            guard let old = try? String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8) else { continue }
            for line in old.split(separator: "\n") {
                if let d = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: String], let w = d["w"] { done.insert(w) }
            }
        }
        if !FileManager.default.fileExists(atPath: outURL.path) { FileManager.default.createFile(atPath: outURL.path, contents: nil) }
        let fh = try FileHandle(forWritingTo: outURL); try fh.seekToEnd()
        var todo: [Entry] = []
        for lv in levels { todo += entries.filter { ($0.lv ?? "") == lv && ($0.ex ?? "").isEmpty && !done.contains($0.w) } }
        todo = todo.enumerated().filter { $0.offset % shards == shard }.map(\.element)
        print("todo \(todo.count)"); fflush(stdout)
        let permissive = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        var n = 0
        for e in todo {
            let prompt = "Word: \(e.w)\nPart of speech: \(e.pos)\nMeaning: \(e.zh.prefix(3).joined(separator: "、"))\((e.def ?? "").isEmpty ? "" : " (\(e.def!))")"
                + "\nUse the word \"\(e.w)\" itself in the sentence (an ending like -s, -ed or -ing is fine, a different word of the same family is not)."
            var result: (String, String)?
            var blocked = false
            for attempt in 0..<2 where result == nil && !blocked {
                let s = LanguageModelSession(instructions: instructions)
                let opt = attempt == 0 ? GenerationOptions(sampling: .greedy, maximumResponseTokens: 120) : GenerationOptions(maximumResponseTokens: 120)
                do {
                    let r = try await s.respond(to: prompt, generating: GeneratedExample.self, options: opt).content
                    let en = r.sentence.trimmingCharacters(in: .whitespacesAndNewlines), zh = cleanZh(r.translation)
                    if WordMatch.found(e.w, in: en), !zh.isEmpty, zh.count <= 60, en.split(separator: " ").count <= 24 { result = (en, zh) }
                } catch LanguageModelSession.GenerationError.guardrailViolation { blocked = true } catch {}
            }
            if result == nil {
                let s = LanguageModelSession(model: permissive, instructions: plainInstructions)
                if let text = try? await s.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 120)).content {
                    let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    let han = #"\p{Han}"#
                    if let en = lines.first(where: { $0.range(of: han, options: .regularExpression) == nil }),
                       let zl = lines.first(where: { $0.range(of: han, options: .regularExpression) != nil }),
                       WordMatch.found(e.w, in: en), en.split(separator: " ").count <= 24 {
                        let zh = cleanZh(zl); if !zh.isEmpty && zh.count <= 60 { result = (en, zh) }
                    }
                }
            }
            if let (en, zh) = result {
                let d = try JSONSerialization.data(withJSONObject: ["w": e.w, "en": en, "zh": zh])
                fh.write(d); fh.write(Data("\n".utf8))
            } else {
                fh.write(try JSONSerialization.data(withJSONObject: ["w": e.w, "fail": "1"])); fh.write(Data("\n".utf8))
            }
            n += 1
            if n % 25 == 0 { print("\(n)/\(todo.count)"); fflush(stdout) }
        }
        print("done \(n)")
    }
}
