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
        // common irregular verbs, which phrases start with most (kept the fire alive, took it into account)
        let irregular: [String: [String]] = [
            "keep": ["kept"], "take": ["took", "taken"], "make": ["made"], "give": ["gave", "given"],
            "get": ["got", "gotten"], "come": ["came"], "go": ["went", "gone"], "bring": ["brought"],
            "think": ["thought"], "find": ["found"], "hold": ["held"], "run": ["ran"], "see": ["saw", "seen"],
            "tell": ["told"], "say": ["said"], "leave": ["left"], "feel": ["felt"], "stand": ["stood"],
            "fall": ["fell", "fallen"], "break": ["broke", "broken"], "catch": ["caught"], "buy": ["bought"],
            "teach": ["taught"], "lose": ["lost"], "pay": ["paid"], "lay": ["laid"], "lead": ["led"],
            "send": ["sent"], "spend": ["spent"], "build": ["built"], "write": ["wrote", "written"],
            "speak": ["spoke", "spoken"], "drive": ["drove", "driven"], "rise": ["rose", "risen"],
            "grow": ["grew", "grown"], "know": ["knew", "known"], "throw": ["threw", "thrown"],
            "show": ["showed", "shown"], "wear": ["wore", "worn"], "tear": ["tore", "torn"],
            "choose": ["chose", "chosen"], "begin": ["began", "begun"], "drink": ["drank", "drunk"],
            "sing": ["sang", "sung"], "swim": ["swam", "swum"], "fly": ["flew", "flown"], "draw": ["drew", "drawn"],
            "eat": ["ate", "eaten"], "forget": ["forgot", "forgotten"], "hide": ["hid", "hidden"],
            "ride": ["rode", "ridden"], "shake": ["shook", "shaken"], "steal": ["stole", "stolen"],
            "wake": ["woke", "woken"], "sell": ["sold"], "seek": ["sought"], "fight": ["fought"],
            "sleep": ["slept"], "meet": ["met"], "sit": ["sat"], "win": ["won"], "hang": ["hung"],
            "dig": ["dug"], "stick": ["stuck"], "strike": ["struck"], "lend": ["lent"], "bend": ["bent"],
            "feed": ["fed"], "hear": ["heard"], "mean": ["meant"], "deal": ["dealt"], "light": ["lit"],
        ]
        if let past = irregular[first] { forms += past.map { NSRegularExpression.escapedPattern(for: $0) + "\\b" } }
        // "be aware of" is written "is / was / were aware of" in a sentence
        if first == "be" { forms = ["be", "is", "am", "are", "was", "were", "been", "being", "'s", "'re", "'m"] }
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
