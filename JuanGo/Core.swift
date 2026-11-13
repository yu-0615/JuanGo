import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

// MARK: - SwiftData models

@Model final class Word {
    @Attribute(.unique) var term: String
    var ipa: String
    var pos: String
    var meanings: [String]
    var definition: String
    var example: String
    var exampleZh: String
    var cefr: String
    /// 0 = never studied, 1...5 = mastery level
    var srsLevel: Int
    var dueDate: Date?
    var lastReviewed: Date?
    var addedAt: Date
    var favorite: Bool
    var inMyWords: Bool
    var reviewCount: Int
    var lists: [WordList] = []

    init(entry: DictEntry, meanings: [String]? = nil) {
        term = entry.w
        ipa = entry.ipa
        pos = entry.pos
        self.meanings = meanings ?? entry.zh
        definition = entry.def
        example = entry.ex
        exampleZh = entry.exZh
        cefr = entry.lv
        srsLevel = 0
        addedAt = .now
        favorite = false
        inMyWords = true
        reviewCount = 0
    }

    var primaryMeaning: String { meanings.first ?? "—" }
    var meaningLine: String { meanings.joined(separator: " · ") }
    var isNew: Bool { srsLevel == 0 }
    var isDue: Bool { !isNew && (dueDate ?? .distantPast) <= .now }
    var isMastered: Bool { srsLevel >= 5 }
}

@Model final class WordList {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Word.lists) var words: [Word] = []
    init(name: String) { self.name = name; createdAt = .now }
}

@Model final class ReviewLog {
    var term: String
    var date: Date
    /// 0 again, 1 unsure, 2 good
    var result: Int
    var wasNew: Bool
    init(term: String, result: Int, wasNew: Bool) {
        self.term = term; self.result = result; self.wasNew = wasNew; date = .now
    }
}

// MARK: - Built-in dictionary

struct DictEntry: Codable, Hashable, Identifiable {
    var w: String
    var ipa: String
    var pos: String
    var zh: [String]
    var def: String
    var ex: String
    var exZh: String
    /// 大考中心 level "1"..."6"
    var lv: String
    /// spelling variants / short forms (e.g. phone for telephone)
    var alt: [String]? = nil
    /// word lists the word belongs to besides the 大考 levels: "elem" 國中小 1200, "toeic", "ielts", "toefl"
    var tags: [String]? = nil
    var id: String { w }
    /// "v./(n.)" -> ["v.", "n."]
    var posTags: [String] { pos.split(separator: "/").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "() ")) } }

    static func custom(_ term: String, meaning: String) -> DictEntry {
        DictEntry(w: term.lowercased(), ipa: "", pos: "", zh: meaning.isEmpty ? [] : [meaning],
                  def: "", ex: "", exZh: "", lv: "—")
    }
}

enum Deck: String, CaseIterable, Identifiable {
    case recommended = "推薦探索", basic = "基礎 2000", middle = "進階 4000", advanced = "學測 6000+"
    case elementary = "國中小 1200", toeic = "多益 TOEIC", ielts = "雅思 IELTS", toefl = "托福 TOEFL"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .recommended: "依你的程度推薦"
        case .basic: "大考詞彙第 1–2 級"
        case .middle: "大考詞彙第 3–4 級"
        case .advanced: "大考詞彙第 5–6 級"
        case .elementary: "教育部國中小基本字彙"
        case .toeic: "職場與生活常用字"
        case .ielts: "雅思考試常見字"
        case .toefl: "托福考試常見字"
        }
    }
    var levels: [String] {
        switch self {
        case .recommended: examLevels
        case .basic: ["1", "2"]
        case .middle: ["3", "4"]
        case .advanced: ["5", "6"]
        default: []
        }
    }
    /// the `DictEntry.tags` value of a word-list deck
    var tag: String? {
        switch self {
        case .elementary: "elem"
        case .toeic: "toeic"
        case .ielts: "ielts"
        case .toefl: "toefl"
        default: nil
        }
    }
    func contains(_ e: DictEntry) -> Bool {
        if let tag { return e.tags?.contains(tag) ?? false }
        return levels.contains(e.lv)
    }
    /// 大考 decks, then the school / test-prep word lists
    static var examDecks: [Deck] { [.basic, .middle, .advanced] }
    static var testDecks: [Deck] { [.elementary, .toeic, .ielts, .toefl] }
    static var studyDecks: [Deck] { examDecks + testDecks }
}

/// 大考中心《高中英文參考詞彙表》levels.
let examLevels = ["1", "2", "3", "4", "5", "6"]
func levelLabel(_ lv: String) -> String { examLevels.contains(lv) ? "第\(lv)級" : lv }
/// Words saved before the 7000-word list used CEFR levels.
let cefrToExam = ["A1": "1", "A2": "2", "B1": "3", "B2": "4", "C1": "5", "C2": "6"]

enum Dictionary_ {
    static let all: [DictEntry] = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DictEntry].self, from: data) else { return [] }
        return list
    }()
    private static let index: [String: DictEntry] = {
        var m = [String: DictEntry]()
        for e in all { m[e.w.lowercased()] = m[e.w.lowercased()] ?? e }
        for e in all { for a in e.alt ?? [] where m[a.lowercased()] == nil { m[a.lowercased()] = e } }
        return m
    }()
    private static let irregular = ["went": "go", "gone": "go", "was": "be", "were": "be", "been": "be", "is": "be", "are": "be",
        "had": "have", "has": "have", "did": "do", "does": "do", "done": "do", "made": "make", "said": "say", "took": "take",
        "taken": "take", "came": "come", "saw": "see", "seen": "see", "got": "get", "gotten": "get", "gave": "give", "given": "give",
        "knew": "know", "known": "know", "thought": "think", "told": "tell", "found": "find", "left": "leave", "felt": "feel",
        "brought": "bring", "bought": "buy", "began": "begin", "begun": "begin", "kept": "keep", "held": "hold", "wrote": "write",
        "written": "write", "stood": "stand", "heard": "hear", "meant": "mean", "met": "meet", "ran": "run", "paid": "pay",
        "sat": "sit", "spoke": "speak", "spoken": "speak", "led": "lead", "grew": "grow", "grown": "grow", "lost": "lose",
        "fell": "fall", "fallen": "fall", "sent": "send", "built": "build", "understood": "understand", "drew": "draw",
        "broke": "break", "broken": "break", "spent": "spend", "rose": "rise", "drove": "drive", "driven": "drive", "ate": "eat",
        "eaten": "eat", "chose": "choose", "chosen": "choose", "wore": "wear", "worn": "wear", "children": "child", "men": "man",
        "women": "woman", "people": "person", "feet": "foot", "teeth": "tooth", "mice": "mouse", "better": "good", "best": "good",
        "worse": "bad", "worst": "bad", "taught": "teach", "caught": "catch", "fought": "fight", "flew": "fly", "slept": "sleep",
        "threw": "throw", "thrown": "throw", "sold": "sell", "won": "win", "sang": "sing", "swam": "swim", "drank": "drink",
        "lives": "life", "leaves": "leaf", "wives": "wife", "knives": "knife", "halves": "half", "shelves": "shelf", "wolves": "wolf",
        "thieves": "thief", "loaves": "loaf", "geese": "goose", "data": "datum", "criteria": "criterion", "phenomena": "phenomenon",
        "analyses": "analysis", "crises": "crisis", "hid": "hide", "hidden": "hide", "lay": "lie", "lain": "lie", "laid": "lay",
        "rode": "ride", "ridden": "ride", "shook": "shake", "shaken": "shake", "stole": "steal", "stolen": "steal", "struck": "strike",
        "swore": "swear", "sworn": "swear", "tore": "tear", "torn": "tear", "woke": "wake", "woken": "wake", "wove": "weave",
        "bent": "bend", "bled": "bleed", "bred": "breed", "dealt": "deal", "dug": "dig", "fed": "feed", "fled": "flee", "hung": "hang",
        "lent": "lend", "lit": "light", "sought": "seek", "shot": "shoot", "slid": "slide", "spun": "spin", "stuck": "stick",
        "stung": "sting", "swept": "sweep", "swung": "swing", "wept": "weep", "wound": "wind", "arose": "arise", "arisen": "arise",
        "forgot": "forget", "forgotten": "forget", "forgave": "forgive", "forgiven": "forgive", "froze": "freeze", "frozen": "freeze",
        "mistook": "mistake", "mistaken": "mistake", "overcame": "overcome", "withdrew": "withdraw", "withdrawn": "withdraw"]

    private static let byMeaning: [String: [DictEntry]] = {
        var m: [String: [DictEntry]] = [:]
        for e in all { for z in e.zh { m[z, default: []].append(e) } }
        return m
    }()

    /// 同義字: other list words that share a Chinese meaning, same part of speech first.
    static func synonyms(of term: String, meanings: [String], pos: String, limit: Int = 4) -> [DictEntry] {
        let tags = Set(pos.split(separator: "/").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "() ")) })
        var score: [String: (e: DictEntry, n: Int)] = [:]
        for z in meanings { for e in byMeaning[z] ?? [] where e.w != term { score[e.w, default: (e, 0)].n += 1 } }
        return score.values.sorted { a, b in
            let pa = tags.isDisjoint(with: a.e.posTags) ? 0 : 1, pb = tags.isDisjoint(with: b.e.posTags) ? 0 : 1
            return (pa, a.n, b.e.w) > (pb, b.n, a.e.w)
        }.prefix(limit).map(\.e)
    }

    static func lookup(_ term: String) -> DictEntry? {
        let t = term.lowercased().replacingOccurrences(of: "'", with: "’")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if let e = index[t] ?? index[t.replacingOccurrences(of: "’", with: "'")] { return e }
        if let base = irregular[t], let e = index[base] { return e }
        if t.hasSuffix("ies"), let e = index[String(t.dropLast(3)) + "y"] { return e }
        if t.hasSuffix("ied"), let e = index[String(t.dropLast(3)) + "y"] { return e }
        // naive lemmatization for plurals / tenses
        for suffix in ["s", "es", "ed", "d", "ing", "ly", "er", "est"] where t.hasSuffix(suffix) && t.count > suffix.count + 2 {
            let stem = String(t.dropLast(suffix.count))
            if let e = index[stem] ?? index[stem + "e"] { return e }
            if let last = stem.last, stem.dropLast().last == last, let e = index[String(stem.dropLast())] { return e } // stopped, running
        }
        return nil
    }
    static func contains(_ term: String) -> Bool { lookup(term) != nil }


    static func suggestions(for query: String, limit: Int = 8) -> [DictEntry] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if q.unicodeScalars.contains(where: { $0.value > 0x2E80 }) {
            let exact = all.filter { $0.zh.contains { $0 == q || $0 == q + "的" } }
            let partial = all.filter { e in !exact.contains(e) && e.zh.contains { $0.contains(q) } }
            return Array((exact + partial).prefix(limit))
        }
        let prefix = all.filter { $0.w.lowercased().hasPrefix(q) }.sorted { $0.w.count < $1.w.count }
        let inner = all.filter { !$0.w.lowercased().hasPrefix(q) && $0.w.lowercased().contains(q) }
        return Array((prefix + inner).prefix(limit))
    }

    /// entries per level and per deck, built once (filtering 10k entries inside view bodies dropped frames)
    private static let byLevel: [String: [DictEntry]] = Dictionary(grouping: all, by: \.lv)
    static func entries(level: String) -> [DictEntry] { byLevel[level] ?? [] }
    @MainActor private static var deckCache: [Deck: [DictEntry]] = [:]
    @MainActor static func entries(deck: Deck) -> [DictEntry] {
        if let e = deckCache[deck] { return e }
        let e = all.filter(deck.contains)
        deckCache[deck] = e
        return e
    }
    /// entries grouped by part of speech, for picking quiz distractors
    static let byPos: [String: [DictEntry]] = Dictionary(grouping: all.filter { !$0.zh.isEmpty }, by: \.pos)
}

// MARK: - Spaced repetition

enum Grade: Int { case again = 0, unsure = 1, good = 2 }

enum SRS {
    /// days until next review after reaching level n (index = level)
    static let intervals: [Double] = [0, 1, 2, 4, 7, 15, 30]

    static func apply(_ grade: Grade, to word: Word, now: Date = .now) {
        switch grade {
        case .good:
            let wasMastered = word.srsLevel >= 5
            word.srsLevel = min(5, word.srsLevel + 1)
            let days = wasMastered ? intervals[6] : intervals[word.srsLevel]
            word.dueDate = now.addingTimeInterval(days * 86_400)
        case .unsure:
            word.srsLevel = max(1, word.srsLevel)
            word.dueDate = now.addingTimeInterval(86_400)
        case .again:
            word.srsLevel = max(1, word.srsLevel - 1)
            word.dueDate = now.addingTimeInterval(20 * 60)
        }
        word.lastReviewed = now
        word.reviewCount += 1
    }
}

// MARK: - Settings

@Observable final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let d = UserDefaults.standard

    var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    var language: String { didSet { d.set(language, forKey: "language") } }
    var level: String { didSet { d.set(level, forKey: "level") } }
    var dailyGoal: Int { didSet { d.set(dailyGoal, forKey: "dailyGoal") } }
    var reminderOn: Bool { didSet { d.set(reminderOn, forKey: "reminderOn"); Reminders.sync(self) } }
    var reminderMinutes: Int { didSet { d.set(reminderMinutes, forKey: "reminderMinutes"); Reminders.sync(self) } }
    var reminderAsked: Bool { didSet { d.set(reminderAsked, forKey: "reminderAsked") } }
    var appearance: Int { didSet { d.set(appearance, forKey: "appearance") } }
    var fontStyle: Int { didSet { d.set(fontStyle, forKey: "fontStyle") } }
    var themeID: String { didSet { d.set(themeID, forKey: "themeID") } }
    var muted: Bool { didSet { d.set(muted, forKey: "muted") } }
    var showTranslation: Bool { didSet { d.set(showTranslation, forKey: "showTranslation") } }
    var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }
    var speechRate: Double { didSet { d.set(speechRate, forKey: "speechRate") } }
    var exploreTipsDone: Bool { didSet { d.set(exploreTipsDone, forKey: "exploreTipsDone") } }
    var studyRulesSeen: Bool { didSet { d.set(studyRulesSeen, forKey: "studyRulesSeen") } }
    var listShowMeaning: Bool { didSet { d.set(listShowMeaning, forKey: "listShowMeaning") } }
    var detailAutoSpeak: Bool { didSet { d.set(detailAutoSpeak, forKey: "detailAutoSpeak") } }
    var exploreShowIPA: Bool { didSet { d.set(exploreShowIPA, forKey: "exploreShowIPA") } }
    /// translate words the dictionary doesn't know with a language model (off by default: it's slow)
    var aiTranslate: Bool { didSet { d.set(aiTranslate, forKey: "aiTranslate") } }
    /// any OpenAI-compatible chat API; the key lives in the Keychain (APIKey)
    var apiBaseURL: String { didSet { d.set(apiBaseURL, forKey: "apiBaseURL") } }
    var apiModel: String { didSet { d.set(apiModel, forKey: "apiModel") } }

    init() {
        d.register(defaults: ["language": "zh-Hant", "level": "3", "dailyGoal": 10, "reminderMinutes": 20 * 60,
                              "themeID": "phoenix", "fontStyle": 0, "showTranslation": true, "haptics": true,
                              "speechRate": 0.45, "listShowMeaning": true, "exploreShowIPA": true,
                              "apiBaseURL": "https://apihub.agnes-ai.com/v1", "apiModel": "agnes-3.0-flash"])
        onboarded = d.bool(forKey: "onboarded")
        language = d.string(forKey: "language")!
        let storedLevel = d.string(forKey: "level")!
        level = cefrToExam[storedLevel] ?? storedLevel
        dailyGoal = d.integer(forKey: "dailyGoal")
        reminderOn = d.bool(forKey: "reminderOn")
        reminderMinutes = d.integer(forKey: "reminderMinutes")
        reminderAsked = d.bool(forKey: "reminderAsked")
        appearance = d.integer(forKey: "appearance")
        fontStyle = d.integer(forKey: "fontStyle")
        themeID = d.string(forKey: "themeID")!
        muted = d.bool(forKey: "muted")
        showTranslation = d.bool(forKey: "showTranslation")
        haptics = d.bool(forKey: "haptics")
        speechRate = d.double(forKey: "speechRate")
        exploreTipsDone = d.bool(forKey: "exploreTipsDone")
        studyRulesSeen = d.bool(forKey: "studyRulesSeen")
        listShowMeaning = d.bool(forKey: "listShowMeaning")
        detailAutoSpeak = d.bool(forKey: "detailAutoSpeak")
        exploreShowIPA = d.bool(forKey: "exploreShowIPA")
        aiTranslate = d.bool(forKey: "aiTranslate")
        apiBaseURL = d.string(forKey: "apiBaseURL")!
        apiModel = d.string(forKey: "apiModel")!
    }

    var theme: AppTheme {
        if let t = cachedTheme, t.id == themeID { return t }
        let t = AppTheme.all.first { $0.id == themeID } ?? AppTheme.all[0]
        cachedTheme = t
        return t
    }
    @ObservationIgnored private var cachedTheme: AppTheme?
    var colorScheme: ColorScheme? { appearance == 1 ? .light : appearance == 2 ? .dark : nil }
    var fontDesign: Font.Design { [.default, .rounded, .serif, .monospaced][min(3, max(0, fontStyle))] }
    var reminderDate: Date {
        get { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now)! }
        set { let c = Calendar.current.dateComponents([.hour, .minute], from: newValue); reminderMinutes = c.hour! * 60 + c.minute! }
    }
    var reminderText: String { String(format: "%d:%02d", reminderMinutes / 60, reminderMinutes % 60) }
}

enum Reminders {
    static func sync(_ s: AppSettings) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily"])
        guard s.reminderOn else { return }
        let minutes = s.reminderMinutes
        Task {
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "該複習單字囉"
            content.body = "花幾分鐘把今天到期的字複習完，別讓剛學的字又忘光。"
            content.sound = .default
            var comps = DateComponents(); comps.hour = minutes / 60; comps.minute = minutes % 60
            let req = UNNotificationRequest(identifier: "daily", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            try? await center.add(req)
        }
    }
}

// MARK: - Theme

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let accentHex: UInt32
    let bgHex: UInt32

    /// In dark mode the accent is lifted towards white so it stays readable on the dark paper.
    var accent: Color {
        Color(UIColor { t in
            let base = UIColor(Color(hex: accentHex))
            return t.userInterfaceStyle == .dark ? base.mix(with: .white, by: 0.38) : base
        })
    }
    /// Swatch paper colour, only used to preview the theme in the theme picker.
    var swatch: Color { Color(hex: bgHex) }
    /// Page paper: a faint wash of the theme's own hue (light: almost white, dark: deep tinted night).
    var background: Color { Self.tones(for: self).background }
    /// Section surface: the same hue one step deeper than the page, so stacks read as pressed-in
    /// blocks of colour instead of white cards (light and dark both go darker).
    var section: Color { Self.tones(for: self).section }

    /// Built once per theme: a fresh dynamic UIColor on every access made SwiftUI see a "new" colour on each
    /// render and repaint every row background.
    @MainActor private static var toneCache: [String: (background: Color, section: Color)] = [:]
    @MainActor private static func tones(for t: AppTheme) -> (background: Color, section: Color) {
        if let c = toneCache[t.id] { return c }
        let c = (t.tone(light: (0.07, 0.975), dark: (0.30, 0.20)), t.tone(light: (0.13, 0.915), dark: (0.30, 0.135)))
        toneCache[t.id] = c
        return c
    }

    /// A colour with the accent's hue at the given saturation/brightness. Saturation is scaled by
    /// how colourful the accent is, so a grey theme (石墨) stays a neutral grey.
    private func tone(light: (s: CGFloat, b: CGFloat), dark: (s: CGFloat, b: CGFloat)) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: accentHex)).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let k = min(1, s / 0.6)
        return Color(UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(hue: h, saturation: v.s * k, brightness: v.b, alpha: 1)
        })
    }

    /// JuanGo's own palette, built around the phoenix-red logo.
    static let all: [AppTheme] = [
        .init(id: "phoenix", name: "鳳凰紅", accentHex: 0xA3162E, bgHex: 0xF8F2EA),
        .init(id: "amber", name: "琥珀", accentHex: 0xB0661A, bgHex: 0xF9F1E3),
        .init(id: "pine", name: "松針", accentHex: 0x2F6B4F, bgHex: 0xF1F3EA),
        .init(id: "ink", name: "墨藍", accentHex: 0x24407A, bgHex: 0xF1F1F0),
        .init(id: "plum", name: "梅子", accentHex: 0x7A2C5C, bgHex: 0xF7EFF0),
        .init(id: "graphite", name: "石墨", accentHex: 0x3B3A38, bgHex: 0xF4F2EE),
        .init(id: "action", name: "天空藍", accentHex: 0x0066CC, bgHex: 0xF5F5F7),
    ]
}

extension UIColor {
    func mix(with other: UIColor, by t: CGFloat) -> UIColor {
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    /// Section / card surface of the current theme (one step deeper than the page background).
    static var cardFill: Color { AppSettings.shared.theme.section }
    static let knowGreen = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.17, green: 0.33, blue: 0.25, alpha: 1) : UIColor(red: 0.84, green: 0.92, blue: 0.86, alpha: 1) })
    static let unsureYellow = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.38, green: 0.29, blue: 0.13, alpha: 1) : UIColor(red: 0.98, green: 0.90, blue: 0.74, alpha: 1) })
    static let againPink = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.40, green: 0.16, blue: 0.18, alpha: 1) : UIColor(red: 0.97, green: 0.85, blue: 0.84, alpha: 1) })
}

/// DESIGN.md radius grammar: compact utility 8, the rare pearl button 11, cards and tiles 18; actions are pills.
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 11
    static let lg: CGFloat = 18
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Radius.lg
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardFill, in: shape)
            .containerShape(shape)   // nested ConcentricRectangle shapes follow this card's corners
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = Radius.lg) -> some View { modifier(CardBackground(padding: padding, radius: radius)) }
}

/// JuanGo's buttons are native iOS 26 buttons, not hand-drawn shapes (DESIGN.md: the pill is the action signal).
/// - `glass: true` or a `fill`: Liquid Glass prominent button tinted with that colour (the main action, the answer buttons).
/// - otherwise: a plain Liquid Glass button for secondary actions.
/// Buttons up to 56 pt tall are pills; taller ones are 18 pt tiles (`Radius.lg`).
struct PillButtonStyle: PrimitiveButtonStyle {
    var fill: Color? = nil
    var foreground: Color? = nil
    var height: CGFloat = 50
    var glass = false

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(.app(.headline))
                .foregroundStyle(foreground.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
                .frame(minHeight: max(44, height) - 30)
        }
        Group {
            if glass || fill != nil {
                button.buttonStyle(.glassProminent).tint(fill ?? .themeAccent)
            } else {
                button.buttonStyle(.glass)
            }
        }
        .buttonBorderShape(height > 56 ? .roundedRectangle(radius: Radius.lg) : .capsule)
        .buttonSizing(.flexible)
        .controlSize(.large)
    }
}

/// A selectable tile (goal, font, question type): native glass, prominent and tinted when selected.
struct ChoiceTileStyle: PrimitiveButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label.foregroundStyle(selected ? Color.onAccent : Color.primary)
        }
        Group {
            if selected { button.buttonStyle(.glassProminent).tint(.themeAccent) } else { button.buttonStyle(.glass) }
        }
        .buttonBorderShape(.roundedRectangle(radius: Radius.lg))
        .buttonSizing(.flexible)
    }
}

// MARK: - Speech

@MainActor enum Speech {
    private static let synth = AVSpeechSynthesizer()
    private static var voice: AVSpeechSynthesisVoice?
    /// Latest request while the voice is still loading (only the newest one is spoken).
    private static var pending: (text: String, rate: Double?)?

    static func say(_ text: String, rate: Double? = nil) {
        guard !text.isEmpty else { return }
        guard voice != nil else {
            // Looking up a voice the first time can block on the main thread forever
            // (seen when 探索 speaks its first card during launch), so load it in the background.
            let loading = pending != nil
            pending = (text, rate)
            if !loading {
                Task.detached(priority: .userInitiated) {
                    let v = AVSpeechSynthesisVoice(language: "en-US")
                    await MainActor.run {
                        voice = v ?? AVSpeechSynthesisVoice()
                        if let p = pending { pending = nil; say(p.text, rate: p.rate) }
                    }
                }
            }
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = Float(rate ?? AppSettings.shared.speechRate)
        synth.speak(u)
    }
}

// MARK: - Library helpers

enum Library {
    static func word(_ term: String, in ctx: ModelContext) -> Word? {
        let t = term.lowercased()
        var fd = FetchDescriptor<Word>(predicate: #Predicate { $0.term == t })
        fd.fetchLimit = 1
        return try? ctx.fetch(fd).first
    }

    @discardableResult
    static func add(_ entry: DictEntry, meanings: [String]? = nil, to list: WordList? = nil, myWords: Bool = true, in ctx: ModelContext) -> Word {
        let entry = ExampleStore.shared.filled(entry)
        let w: Word
        if let existing = word(entry.w, in: ctx) {
            w = existing
            if let meanings, !meanings.isEmpty { w.meanings = meanings }
            if myWords { w.inMyWords = true }
        } else {
            w = Word(entry: entry, meanings: meanings)
            w.inMyWords = myWords
            ctx.insert(w)
        }
        if let list, !w.lists.contains(where: { $0.persistentModelID == list.persistentModelID }) {
            w.lists.append(list)
        }
        try? ctx.save()
        return w
    }

    static func remove(_ w: Word, in ctx: ModelContext) {
        ctx.delete(w)
        try? ctx.save()
    }
}

// MARK: - Stats

/// Everything the home and profile screens show, worked out in one pass when it's made (the old computed
/// properties re-scanned every log and word on each access, several times per frame).
struct Stats {
    let logs: [ReviewLog]
    let words: [Word]
    let activeDays: Set<Date>
    let streak: Int
    let newToday: Int
    let studiedToday: Int
    let learnedTotal: Int
    let masteredTotal: Int
    let dueCount: Int
    let distribution: [Int]
    private let perDay: [Date: Int]

    init(logs: [ReviewLog], words: [Word]) {
        self.logs = logs
        self.words = words
        let day = Self.logPart(logs)
        activeDays = day.activeDays; perDay = day.perDay; newToday = day.newToday
        studiedToday = day.studiedToday; streak = day.streak

        var learned = 0, mastered = 0, due = 0
        var dist = [Int](repeating: 0, count: 6)
        for w in words {
            if w.srsLevel > 0 { learned += 1 }
            if w.isMastered { mastered += 1 }
            if w.isDue { due += 1 }
            if (0...5).contains(w.srsLevel) { dist[w.srsLevel] += 1 }
        }
        learnedTotal = learned; masteredTotal = mastered; dueCount = due; distribution = dist
    }

    func count(on day: Date) -> Int { perDay[Calendar.current.startOfDay(for: day)] ?? 0 }

    private struct LogPart { var activeDays: Set<Date>; var perDay: [Date: Int]; var newToday: Int; var studiedToday: Int; var streak: Int }
    /// Logs only ever grow, so the day-by-day part is reused until another log is added or the day changes.
    nonisolated(unsafe) private static var logMemo: (key: String, part: LogPart)?
    private static func logPart(_ logs: [ReviewLog]) -> LogPart {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let key = "\(logs.count)|\(logs.first?.date.timeIntervalSince1970 ?? 0)|\(logs.last?.date.timeIntervalSince1970 ?? 0)|\(today.timeIntervalSince1970)"
        if Thread.isMainThread, let m = logMemo, m.key == key { return m.part }
        var termsByDay: [Date: Set<String>] = [:]
        var newTerms: Set<String> = []
        for l in logs {
            let d = cal.startOfDay(for: l.date)
            termsByDay[d, default: []].insert(l.term)
            if d == today && l.wasNew { newTerms.insert(l.term) }
        }
        let active = Set(termsByDay.keys)
        var day = today
        if !active.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while active.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        let part = LogPart(activeDays: active, perDay: termsByDay.mapValues(\.count), newToday: newTerms.count,
                           studiedToday: termsByDay[today]?.count ?? 0, streak: n)
        if Thread.isMainThread { logMemo = (key, part) }
        return part
    }
}

struct BadgeKind: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tiers: [Int]
    func next(for value: Int) -> Int { tiers.first { $0 > value } ?? tiers.last! }
    func earned(for value: Int) -> Int { tiers.filter { value >= $0 }.count }

    static let all: [BadgeKind] = [
        .init(id: "streak", title: "連續天數", symbol: "flame.fill", tiers: [3, 7, 30, 100, 365]),
        .init(id: "imported", title: "匯入單字", symbol: "square.and.arrow.down.fill", tiers: [100, 500, 1000, 3000]),
        .init(id: "learned", title: "學過單字", symbol: "book.fill", tiers: [100, 500, 1000, 3000]),
        .init(id: "mastered", title: "學會單字", symbol: "checkmark.seal.fill", tiers: [10, 50, 200, 1000]),
    ]

    static func value(_ id: String, stats: Stats) -> Int {
        switch id {
        case "streak": stats.streak
        case "imported": stats.words.count
        case "learned": stats.learnedTotal
        default: stats.masteredTotal
        }
    }
}

extension ShapeStyle where Self == Color {
    /// The current theme's accent. `Color.accentColor` only reflects the asset catalog
    /// colour inside presented screens, so views read the theme directly instead.
    static var themeAccent: Color { AppSettings.shared.theme.accent }
    /// Text on an accent fill: white on the deep light-mode accent, near-black on the pastel dark-mode one.
    static var onAccent: Color { Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white }) }
}

extension Locale {
    /// The UI is Traditional Chinese regardless of the device language, so dates follow it too.
    static let zh = Locale(identifier: "zh-Hant-TW")
}
