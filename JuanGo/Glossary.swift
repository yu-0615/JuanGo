import Foundation
import CoreGraphics

/// One line of a textbook word list (單字統整), e.g. "3. pressure n. 壓力；壓迫".
struct GlossaryEntry: Hashable {
    /// lowercased; may be a phrase ("give up")
    var term: String
    /// normalised like the dictionary ("v.", "n./v."); empty when the page gives none
    var pos: String
    /// the Chinese meanings printed on the page
    var meanings: [String]
}

/// Reads a photographed word list: rows of "word  [phonetics]  part-of-speech  中文意思",
/// numbered or not, one or several columns per row.
nonisolated enum GlossaryParser {
    /// Abbreviations textbooks use, mapped onto the dictionary's spelling.
    static let posMap: [String: String] = [
        "n": "n.", "v": "v.", "vt": "v.", "vi": "v.", "adj": "adj.", "a": "adj.", "adv": "adv.", "ad": "adv.",
        "prep": "prep.", "conj": "conj.", "pron": "pron.", "aux": "aux.", "phr": "phr.", "ph": "phr.",
        "int": "int.", "interj": "int.", "art": "art.", "num": "num.",
    ]

    private static let regex: NSRegularExpression = {
        let pos = "(?:n|v|vt|vi|adj|adv|a|ad|prep|conj|pron|aux|phr|ph|int|interj|art|num)"
        let pattern = #"(?<term>[A-Za-z][A-Za-z'’\-]*(?:\s[A-Za-z][A-Za-z'’\-]*){0,3})\b"#
            + #"\s*(?:\[[^\]]{1,40}\]|/[^/]{1,40}/)?"#                                   // KK / IPA
            + #"\s*(?<pos>(?:\(?"# + pos + #"\.?\)?\s*(?:[/&,、]\s*)?)*)"#
            + #"\s*(?<zh>[\p{Han}（(〈][^A-Za-z]*)"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// Parses OCR rows. Returns the entries only when the page really is a word list: at least three
    /// rows read as "word (pos) 中文", and they make up at least half of the bilingual rows (so an
    /// English passage with a Chinese translation underneath is not mistaken for one).
    static func parse(rows: [String]) -> [GlossaryEntry] {
        var found: [GlossaryEntry] = []
        var seen = Set<String>()
        var bilingualRows = 0
        for raw in rows {
            // Chinese OCR prints ASCII brackets and letters full-width (［ ］ （adj.）)
            let row = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
            let hasHan = row.range(of: #"\p{Han}"#, options: .regularExpression) != nil
            let hasLatin = row.range(of: "[A-Za-z]{2}", options: .regularExpression) != nil
            guard hasHan && hasLatin else { continue }
            bilingualRows += 1
            let ns = row as NSString
            for m in regex.matches(in: row, range: NSRange(location: 0, length: ns.length)) {
                var term = ns.substring(with: m.range(withName: "term")).trimmingCharacters(in: .whitespaces)
                var posText = ns.substring(with: m.range(withName: "pos"))
                // "capable adj 有能力的": an undotted abbreviation ends up in the term
                var words = term.split(separator: " ").map(String.init)
                if words.count > 1, let last = words.last, posMap[last.lowercased()] != nil {
                    words.removeLast(); term = words.joined(separator: " "); posText = last + " " + posText
                }
                let tags = unique(posText.lowercased().components(separatedBy: CharacterSet.letters.inverted)
                    .compactMap { posMap[$0] })
                // Counts only if the page gives a part of speech, or the English part of the match is the
                // whole start of the row ("abandon 放棄" lists without parts of speech).
                let before = ns.substring(to: m.range.location)
                let startsRow = before.range(of: "[A-Za-z]", options: .regularExpression) == nil
                guard term.count >= 2, words.count <= 4, !tags.isEmpty || startsRow else { continue }
                let meanings = meaningList(ns.substring(with: m.range(withName: "zh")))
                guard !meanings.isEmpty else { continue }
                let key = term.lowercased()
                guard seen.insert(key).inserted else { continue }
                found.append(GlossaryEntry(term: key, pos: tags.joined(separator: "/"), meanings: meanings))
            }
        }
        return found.count >= 3 && found.count * 2 >= bilingualRows ? found : []
    }

    /// "放棄；拋棄 2." → ["放棄", "拋棄"]; "藝術形式 *5" → ["藝術形式"]
    static func meaningList(_ raw: String) -> [String] {
        return unique(raw.components(separatedBy: CharacterSet(charactersIn: "；;，,／/"))
            .map { tidy(stripMarks($0).replacingOccurrences(of: #"[\s\d.)、､(（]+$"#, with: "", options: .regularExpression)) }
            .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "。.、"))) }
            .filter { $0.range(of: #"\p{Han}"#, options: .regularExpression) != nil })
    }

    /// Textbooks flag a word's level or importance with marks like "*5", "★", "※"; they're not part of the meaning.
    /// A mark followed by more text starts a legend that OCR read into the row ("種類 ★表示近五年大考出現字彙"),
    /// so everything from that mark on goes. A legend that has already lost its mark is cut at 表示.
    static func stripMarks(_ s: String) -> String {
        let marks = "[*＊★☆※]"
        var t = s.replacingOccurrences(of: "^\\s*" + marks + "+\\s*\\d*\\s*", with: "", options: .regularExpression)
        if let r = t.range(of: marks, options: .regularExpression) { t = String(t[..<r.lowerBound]) }
        t = t.replacingOccurrences(of: "表示.*(大考|出現|字彙|字汇|字货|考試).*$", with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Undoes what reading the page did to a meaning: the half-width 、 ("調整､安排") from the full-width
    /// conversion, a closing bracket cut off with the row's trailing numbering ("入境檢查(處"), level marks.
    static func tidy(_ m: String) -> String {
        var t = stripMarks(m).replacingOccurrences(of: "､", with: "、")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        let open = t.filter { $0 == "(" || $0 == "（" }.count, close = t.filter { $0 == ")" || $0 == "）" }.count
        if open > close { t += String(repeating: ")", count: open - close) }
        return t
    }

    /// Joins OCR lines that sit on the same printed row (Vision often splits "pressure" and "壓力"
    /// into separate boxes when the columns are far apart), left to right.
    static func rows(from lines: [(text: String, box: CGRect)]) -> [String] {
        var rows: [[(text: String, box: CGRect)]] = []
        for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let i = rows.firstIndex(where: { r in
                let b = r[0].box
                return abs(b.midY - line.box.midY) < min(b.height, line.box.height) * 0.5
            }) {
                rows[i].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ") }
    }

    private static func unique(_ a: [String]) -> [String] { var s = Set<String>(); return a.filter { s.insert($0).inserted } }
}

extension GlossaryParser {
    /// OCR reads the KK phonetics printed after a word as letters ("[ˈækjərəsɪ]" → "takjoresi") and glues them
    /// onto it: "accuracy takjoresi", "combattkam". Keeps the part the dictionary knows.
    static func cleanTerm(_ term: String) -> String {
        guard Dictionary_.lookup(term) == nil else { return term }
        var words = term.split(separator: " ").map(String.init)
        if words.count > 1 {
            // words phrases are made of, which the dictionary may not list on their own
            let glue: Set<String> = ["sth", "sb", "one's", "oneself", "someone", "something", "a", "an", "the", "to", "of",
                                     "in", "on", "at", "for", "with", "up", "out", "off", "down", "from", "by", "into",
                                     "about", "over", "away", "back", "be", "do", "get", "make", "take"]
            while words.count > 1, let last = words.last, !glue.contains(last), looksLikePhonetics(last),
                  Dictionary_.lookup(last) == nil { words.removeLast() }
            let kept = words.joined(separator: " ")
            return Dictionary_.lookup(kept) != nil ? kept : term   // a word of the user's own stays as it is
        }
        // "combattkam": a known word followed by phonetics that began with the "[" read as t (or "/" read as l)
        for n in stride(from: term.count - 3, through: 3, by: -1) {
            let head = String(term.prefix(n)), tail = term.dropFirst(n)
            if tail.count >= 4, looksLikePhonetics(String(tail)), let e = Dictionary_.lookup(head), e.w.lowercased() == head { return head }
        }
        return term
    }

    /// "[ˈdɛfənɪtlɪ]" comes out of OCR as "tdefonutlil": the brackets turn into t / l.
    private static func looksLikePhonetics(_ w: String) -> Bool {
        w.count >= 3 && (w.hasPrefix("t") || w.hasSuffix("l")) && w.allSatisfy { $0.isLetter || $0 == "'" }
    }
}
