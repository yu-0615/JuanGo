import Foundation
enum WordMatch {
    static func pattern(for term: String) -> String? {
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
        // sth / sb stand for any few words: "harm to sth" matches "harm to the environment"
        let placeholders: Set<String> = ["sth", "sth.", "sb", "sb.", "sb's", "someone", "something", "one's", "oneself", "somebody", "…", "...", "~", "sb/sth", "sth/sb"]
        let rest = parts.dropFirst().map {
            placeholders.contains($0) ? "((?:\\s+[\\w'’-]+){1,3}?)" : "\\s+" + NSRegularExpression.escapedPattern(for: $0)
        }.joined()
        return "\\b" + head + rest + (parts.count > 1 ? "\\w*" : "")
    }

    static func found(_ term: String, in sentence: String) -> Bool {
        guard let p = pattern(for: term) else { return false }
        return sentence.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
