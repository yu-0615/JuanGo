import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0
    @State private var test = LevelTest(words: LevelTest.basic)
    @State private var unsupportedLanguage = false
    @State private var customGoal = false

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            Hero(page: page, word: page == 1 ? test.current?.w : nil)
                .scaleEffect(page == 4 ? 0.7 : 1)
                .frame(height: page == 4 ? 200 : 300)
                .padding(.top, 8)
            Group {
                switch page {
                case 0: languagePage
                case 1: testPage
                case 2: resultPage
                case 3: goalPage
                default: themePage
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            bottomBar.padding(.horizontal, 20)
            PageDots(count: 5, index: page).padding(.vertical, 14)
        }
        .animation(.spring(duration: 0.45), value: page)
        #if DEBUG
        // Debug hook: `SIMCTL_CHILD_JUANGO_ONBOARD=3` opens onboarding on that page.
        .task { if let p = Int(ProcessInfo.processInfo.environment["JUANGO_ONBOARD"] ?? ""), (0...4).contains(p) { page = p } }
        #endif
        .alert("目前只支援繁體中文解釋", isPresented: $unsupportedLanguage) { Button("好") {} } message: {
            Text("其他語言的解釋會在之後的版本加入。")
        }
        .sheet(isPresented: $customGoal) {
            VStack(spacing: 20) {
                Text("自訂每日新字").font(.app(.title2, .bold))
                Text("\(settings.dailyGoal) 個 / 天").font(.app(size: 44, .semibold)).contentTransition(.numericText())
                Stepper("", value: $settings.dailyGoal, in: 1...100).labelsHidden()
                Button("完成") { customGoal = false }.buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            }
            .padding(28).presentationDetents([.height(320)])
        }
    }

    // MARK: pages

    private var languagePage: some View {
        VStack(spacing: 22) {
            Text("選擇解釋語言").font(.app(.title, .bold))
            StackGrid(items: [("zh-Hant", "繁體中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어")], columns: 2, spacing: 14) { item in
                    let (code, name) = item
                    let on = settings.language == code
                    Button {
                        if code == "zh-Hant" { settings.language = code } else { unsupportedLanguage = true }
                    } label: {
                        HStack { Text(name); if on { LIcon("checkmark") } }
                    }
                    .buttonStyle(PillButtonStyle(fill: on ? .themeAccent : nil, foreground: on ? .onAccent : nil))
            }
            .padding(.horizontal, 20)
        }
    }

    private var testPage: some View {
        VStack(spacing: 18) {
            if let w = test.current {
                Text("\(test.index + 1) / \(test.words.count)").font(.app(.subheadline).monospacedDigit()).foregroundStyle(.secondary)
                Text(w.w).font(.app(size: 40, .semibold)).id(w.w)
                    .transition(.push(from: .trailing))
                Text(test.revealed ? w.zh.prefix(2).joined(separator: " · ") : " ")
                    .font(.app(.title3, .semibold)).foregroundStyle(.secondary)
                Text(test.revealed ? "原本知道這個意思嗎？" : " ").font(.app(.caption)).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(test.revealed ? "確認" : "會") { answer(test.revealed ? 1 : nil) }
                        .buttonStyle(PillButtonStyle(fill: .knowGreen))
                    Button("不確定") { answer(0.5) }.buttonStyle(PillButtonStyle(fill: .unsureYellow))
                    Button("不會") { answer(0) }.buttonStyle(PillButtonStyle(fill: .againPink))
                }
                .padding(.horizontal, 20)
            }
        }
        .animation(.snappy, value: test.index)
        .animation(.snappy, value: test.revealed)
    }

    private var resultPage: some View {
        VStack(spacing: 14) {
            Text("你的推定程度").font(.app(.title2, .bold))
            Text(levelLabel(test.estimate)).font(.app(size: 72, .semibold))
            Text(LevelTest.blurb(test.estimate)).font(.app(.headline))
            Text("會從接近你程度的單字開始。").font(.app(.subheadline)).foregroundStyle(.secondary)
            if !test.didAdvanced {
                Button("再答 10 題進階測試") {
                    test.startAdvanced()
                    page = 1
                }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 20).padding(.top, 8)
            }
        }
    }

    private var goalPage: some View {
        @Bindable var settings = settings
        return VStack(spacing: 18) {
            Text("設定學習目標").font(.app(.title, .bold))
            HStack(spacing: 10) {
                ForEach([(5, "輕鬆", ""), (10, "標準", "約 10 分鐘"), (20, "衝刺", "")], id: \.0) { n, name, sub in
                    let on = settings.dailyGoal == n
                    Button { settings.dailyGoal = n } label: {
                        VStack(spacing: 4) {
                            Text(name).font(.app(.headline))
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(n)").font(.app(size: 30, .semibold))
                                Text("個 / 天").font(.app(.caption))
                            }
                            Text(sub).font(.app(.caption2))
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                    }
                    .buttonStyle(ChoiceTileStyle(selected: on))
                }
            }
            .padding(.horizontal, 20)
            Button(![5, 10, 20].contains(settings.dailyGoal) ? "自訂數量：\(settings.dailyGoal) 個 / 天" : "自訂數量") { customGoal = true }
                .font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                Toggle(isOn: $settings.reminderOn) { Label("學習與複習提醒", pulso: "bell.fill").font(.app(.headline)) }
                if settings.reminderOn {
                    DatePicker("提醒時間", selection: $settings.reminderDate, displayedComponents: .hourAndMinute)
                }
            }
            .card(padding: 16)
            .padding(.horizontal, 20)
        }
    }

    private var themePage: some View {
        @Bindable var settings = settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("選擇主題").font(.app(.title, .bold)).frame(maxWidth: .infinity)
                Picker("外觀", selection: $settings.appearance) {
                    Text("跟隨系統").tag(0); Text("淺色").tag(1); Text("深色").tag(2)
                }.pickerStyle(.segmented)
                Text("字體").font(.app(.headline))
                HStack(spacing: 8) {
                    ForEach(Array(AppFont.options.enumerated()), id: \.offset) { i, o in
                        let on = settings.fontStyle == i
                        Button { settings.fontStyle = i } label: {
                            VStack(spacing: 2) {
                                Text("Aa").font(.system(.title3, design: o.swiftDesign, weight: .bold))
                                Text(o.name).font(AppFont.preview(i, size: 12))
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(ChoiceTileStyle(selected: on))
                    }
                }
                HStack { Text("主題色").font(.app(.headline)); Spacer(); Text(settings.theme.name).foregroundStyle(.secondary) }
                ThemeGrid(selection: $settings.themeID)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: bottom bar

    @ViewBuilder private var bottomBar: some View {
        HStack(spacing: 10) {
            if page > 0 {
                Button { back() } label: { LIcon("chevron.left").font(.app(.headline)) }.accessibilityLabel("上一步")
                    .buttonStyle(PillButtonStyle()).frame(width: 64)
            }
            switch page {
            case 0:
                Button("跳過") { page = 3 }.buttonStyle(PillButtonStyle()).frame(width: 88)
                Button("15 題單字程度測試") { test = LevelTest(words: LevelTest.basic); page = 1 }
                    .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            case 1:
                Button("撤銷") { test.undo() }.buttonStyle(PillButtonStyle(foreground: .secondary)).disabled(test.answers.isEmpty)
                Button("略過") { finishTest() }.buttonStyle(PillButtonStyle()).frame(width: 88)
            case 2:
                Button("設定學習目標") { page = 3 }.buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            case 3:
                Button("繼續") { page = 4 }.buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            default:
                Button("完成並開始使用") { settings.onboarded = true }
                    .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            }
        }
    }

    private func back() {
        if page == 1, !test.answers.isEmpty { test.undo(); return }
        page = page == 3 && test.answers.isEmpty ? 0 : page - 1
    }

    private func answer(_ score: Double?) {
        guard let score else { test.revealed = true; return }
        test.record(score)
        if test.current == nil { finishTest() }
    }

    private func finishTest() {
        if !test.answers.isEmpty { settings.level = test.estimate; page = 2 } else { page = 3 }
    }
}

struct ThemeGrid: View {
    @Binding var selection: String
    /// Swatches: a paper square with the theme colour as a band along the bottom.
    var body: some View {
        StackGrid(items: AppTheme.all, columns: 3, spacing: 10) { t in
                Button { selection = t.id } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Aa").font(.app(.title3, .bold)).foregroundStyle(t.accent)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        Spacer(minLength: 0)
                        HStack {
                            Text(t.name).font(.app(.caption, .bold)).foregroundStyle(.white)
                            Spacer()
                            if selection == t.id { LIcon("checkmark").font(.app(.caption, .bold)).foregroundStyle(.white) }
                        }
                        .padding(.horizontal, 10).frame(height: 28).background(t.accent)
                    }
                    .frame(height: 76)
                    .background(t.swatch)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(selection == t.id ? Color.primary : .clear, lineWidth: 2))
                }.buttonStyle(.plain)
        }
    }
}

struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(i <= index ? Color.themeAccent : Color.secondary.opacity(0.3))
                    .frame(maxWidth: .infinity).frame(height: 4)
            }
        }
        .animation(.snappy, value: index)
    }
}

/// Floating stack of word cards that previews the app at the top of each onboarding page.
struct Hero: View {
    let page: Int
    let word: String?
    @State private var tick = 0
    private let samples = ["situate", "resilient", "perspective", "maintain", "pivotal"]

    /// A single dictionary page with a ribbon bookmark: headword, pronunciation, ruled lines.
    var body: some View {
        let current = word ?? samples[tick % samples.count]
        VStack(alignment: .leading, spacing: 10) {
            Text(current).font(.app(size: 32, .bold)).contentTransition(.opacity)
            if let e = Dictionary_.lookup(current) {
                Text("\(e.pos)  /\(e.ipa)/").font(.app(.caption)).foregroundStyle(.secondary)
                // During the level test the hero must not reveal the answer.
                Text(word == nil ? (e.zh.first ?? "") : "？").font(.app(.title3, .bold)).foregroundStyle(.tint)
            }
            ForEach(0..<3, id: \.self) { k in
                Capsule().fill(Color.secondary.opacity(0.15)).frame(width: [180, 150, 110][k], height: 6)
            }
        }
        .padding(22)
        .frame(width: 250, height: 210, alignment: .topLeading)
        .background(Color.cardFill, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        // DESIGN.md: the one shadow in the system, for an object resting on a surface.
        .shadow(color: .black.opacity(0.22), radius: 15, x: 3, y: 5)
        .overlay(alignment: .topTrailing) {
            LIcon("bookmark.fill").font(.app(size: 34)).foregroundStyle(Color.themeAccent)
                .offset(y: -4).padding(.trailing, 22)
        }
        .rotationEffect(.degrees(Double(page % 2 == 0 ? -2 : 2)))
        .animation(.spring(duration: 0.6), value: current)
        .task(id: word == nil) {
            guard word == nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                tick += 1
            }
        }
    }
}

// MARK: - Level test model

struct LevelTest {
    /// 3 random words from each of levels 1–5 (15 questions), then 5 each from levels 5–6.
    static var basic: [String] { pick(["1", "2", "3", "4", "5"], 3) }
    static var advanced: [String] { pick(["5", "6"], 5) }
    private static func pick(_ levels: [String], _ n: Int) -> [String] {
        levels.flatMap { lv in Dictionary_.entries(level: lv).filter { !$0.zh.isEmpty && $0.w.count > 3 }.shuffled().prefix(n).map(\.w) }
    }

    var words: [DictEntry]
    var index = 0
    var revealed = false
    var answers: [Double] = []
    var previous: [(DictEntry, Double)] = []
    var didAdvanced = false

    init(words: [String]) { self.words = words.compactMap(Dictionary_.lookup) }

    var current: DictEntry? { index < words.count ? words[index] : nil }

    mutating func record(_ score: Double) { answers.append(score); index += 1; revealed = false }
    mutating func undo() {
        guard !answers.isEmpty else { return }
        answers.removeLast(); index -= 1; revealed = false
    }
    mutating func startAdvanced() {
        previous = Array(zip(words, answers))
        words = LevelTest.advanced.compactMap(Dictionary_.lookup)
        index = 0; answers = []; revealed = false; didAdvanced = true
    }

    var estimate: String {
        let all = previous + Array(zip(words, answers))
        guard !all.isEmpty else { return "1" }
        var result = "1"
        for lv in examLevels.dropFirst() {
            let scores = all.filter { $0.0.lv == lv }.map(\.1)
            if scores.isEmpty { continue }
            if scores.reduce(0, +) / Double(scores.count) >= 0.5 { result = lv } else { break }
        }
        return result
    }

    static func blurb(_ lv: String) -> String {
        switch lv {
        case "1": "國中基礎字，從最常用的開始"
        case "2": "累積日常生活情境的單字"
        case "3": "高一程度・校園與生活常用字"
        case "4": "高二程度・挑戰抽象詞彙"
        case "5": "高三程度・學測進階字"
        default: "學測頂標・最難的第六級"
        }
    }
}
