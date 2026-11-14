import SwiftUI
import SwiftData

// MARK: - Flow (setup → session → streak → summary)

struct StudyFlow: View {
    let request: StudyRequest
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    enum Phase { case setup, running, streak, summary }
    @State private var phase = Phase.setup
    @State private var engine: SessionEngine?
    @State private var studiedBefore = false
    @State private var lastRound = 0
    @State private var lastResults: [RoundResult] = []
    /// The request's words shuffled once: the setup's random draw, the card order and the example prefetch all use it.
    @State private var order: StudyRequest

    init(request: StudyRequest) {
        self.request = request
        _order = State(initialValue: StudyRequest(title: request.title, words: request.words.shuffled()))
    }

    var body: some View {
        ZStack {
            settings.theme.background.ignoresSafeArea()
            switch phase {
            case .setup:
                SessionSetupView(request: order, onClose: { dismiss() }) { words, types, listening, endless in
                    studiedBefore = Stats(logs: fetchLogs(), words: []).studiedToday > 0
                    engine = SessionEngine(words: words, types: types, listening: listening, endless: endless)
                    phase = .running
                }
            case .running:
                if let engine {
                    SessionView(engine: engine, title: request.title, onClose: { finish(engine) })
                        .onChange(of: engine.current == nil) { _, ended in if ended { finish(engine) } }
                }
            case .streak:
                StreakView(stats: endStats ?? currentStats()) { phase = .summary }
            case .summary:
                SummaryView(stats: endStats ?? currentStats(), roundCount: lastRound, results: lastResults,
                            onAgain: { order = StudyRequest(title: request.title, words: request.words.shuffled()); phase = .setup }, onDone: { dismiss() },
                            onRetry: { order = StudyRequest(title: "答錯的字", words: $0.shuffled()); phase = .setup })
            }
        }
        .animation(.easeInOut, value: phase)
        // background example sentences wait until the round closes, so the screens behind it don't redraw
        .onAppear { ExampleStore.shared.holdBackground = true }
        .onDisappear { ExampleStore.shared.holdBackground = false }

        #if DEBUG
        .task {
            guard let m = ProcessInfo.processInfo.environment["JUANGO_STUDY"] else { return }
            if m.hasPrefix("q:") {
                // JUANGO_FIRST=<term> puts that word first, to look at one word's question
                var words = request.words
                if let f = ProcessInfo.processInfo.environment["JUANGO_FIRST"], let w = Library.word(f, in: ctx) {
                    words = [w] + words.filter { $0.term != w.term }
                }
                engine = SessionEngine(words: words, types: QType(rawValue: String(m.dropFirst(2))).map { [$0] }, listening: false)
                phase = .running
            } else if m == "summary" {
                // a few of the round's words with mixed grades, to look at the results list
                lastResults = zip(request.words.prefix(4), [Grade.good, .again, .unsure, .good]).map { RoundResult(word: $0, grade: $1) }
                lastRound = lastResults.count; phase = .summary
            }
            else if m == "streak" { phase = .streak }
        }
        #endif
    }

    /// Fetched when a round ends instead of kept live with @Query: a live query re-fetched every word and log
    /// on each answer (and each example sentence saved) and re-rendered the whole round.
    @State private var endStats: Stats?
    private func fetchLogs() -> [ReviewLog] { (try? ctx.fetch(FetchDescriptor<ReviewLog>())) ?? [] }
    private func currentStats() -> Stats { Stats(logs: fetchLogs(), words: (try? ctx.fetch(FetchDescriptor<Word>())) ?? []) }

    private func finish(_ engine: SessionEngine) {
        endStats = currentStats()
        lastRound = engine.done.count
        lastResults = engine.results
        guard lastRound > 0 else { dismiss(); return }
        phase = studiedBefore ? .summary : .streak
    }
}

struct SessionSetupView: View {
    let request: StudyRequest
    var onClose: () -> Void
    var onStart: ([Word], [QType]?, Bool, Bool) -> Void
    @State private var smart = true
    @State private var types: Set<QType> = [.flashcard]
    @State private var listening = false
    /// 題數: 0 = all words, -1 = 無盡模式, otherwise draw this many (words due for review first).
    @State private var limit = 0
    /// The count picked last time, so a big list doesn't default to an 80-minute round every time.
    @AppStorage("practiceLimit") private var savedLimit = 20
    /// The random draw for the current count, kept so the preview and the round use the same words.
    @State private var drawn: [Word] = []

    private var endless: Bool { limit == -1 }
    private var words: [Word] { limit > 0 ? drawn : request.words }
    private var drawOptions: [Int] { [5, 10, 20, 30, 50].filter { $0 < request.words.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.title).font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
                    Text("本輪設定").font(.app(.largeTitle, .bold))
                }
                Spacer()
                Button(action: onClose) {
                    LIcon("xmark").font(.app(.headline)).frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel("關閉")
            }
            .padding(.top, 8)
            Picker("", selection: $smart) { Text("自動安排").tag(true); Text("手動挑選").tag(false) }.pickerStyle(.segmented)
            ScrollView {
                if smart { smartPanel } else { customPanel }
            }
            VStack(spacing: 10) {
                Menu {
                    Picker("題數", selection: Binding(get: { limit }, set: { limit = $0; savedLimit = $0 })) {
                        Text("全部 \(request.words.count) 個").tag(0)
                        ForEach(drawOptions, id: \.self) { Text("\($0) 個").tag($0) }
                        Text("無盡模式").tag(-1)
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 10) {
                        LIcon(endless ? "infinity" : "list.number", size: 20, play: endless).fontWeight(.semibold).foregroundStyle(Color.themeAccent)
                        Text("題數").foregroundStyle(.secondary)
                        Spacer()
                        Text(drawLabel).fontWeight(.bold)
                        LIcon("chevron.up.chevron.down").font(.app(.caption)).foregroundStyle(.secondary)
                    }
                    .font(.app(.subheadline)).foregroundStyle(.primary)
                    .card(padding: 14)
                }
                .menuOrder(.fixed).tint(.primary)
                Button { onStart(endless ? request.words : words, smart ? nil : Array(types), listening, endless) } label: {
                    Label("開始練習", pulso: "play.fill")
                }
                .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 54, glass: true))
                .disabled(request.words.isEmpty || (!smart && types.isEmpty))
            }
        }
        .padding(.horizontal, 18)
        .onAppear {
            // last time's count, if this list is big enough for it; otherwise the closest smaller one
            if savedLimit == -1 { limit = -1 }
            else if savedLimit > 0 { limit = drawOptions.last { $0 <= savedLimit } ?? 0 }
        }
        // start writing example sentences while the round is being set up, so the first cards already have them —
        // in the order the round will actually ask them (due words first), and only once the cover has finished
        // sliding up: prepare() saves cached sentences into the words, which mid-animation made the cover stutter
        .task(id: limit) {
            try? await Task.sleep(for: .milliseconds(500))
            ExampleStore.shared.prepare(Array(words.prefix(6)))
        }
        .onChange(of: limit, initial: true) { _, n in
            // the words are already shuffled; keep that order within each group
            let w = request.words
            let ordered = w.filter(\.isDue) + w.filter { !$0.isDue && !$0.isMastered } + w.filter { !$0.isDue && $0.isMastered }
            drawn = n > 0 ? Array(ordered.prefix(n)) : []
        }
        #if DEBUG
        .task {   // device testing: JUANGO_AUTOSTART=1 presses 開始練習 after a moment, like a tap
            guard ProcessInfo.processInfo.environment["JUANGO_AUTOSTART"] != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            onStart(endless ? request.words : words, smart ? nil : Array(types), listening, endless)
        }
        #endif
    }

    private var drawLabel: String {
        switch limit {
        case 0: "全部 \(request.words.count) 個"
        case -1: "無盡模式"
        default: "\(limit) 個"
        }
    }

    /// The setup card while 無盡模式 is picked.
    private var endlessCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LIcon("infinity", size: 34, play: true).fontWeight(.semibold).foregroundStyle(Color.themeAccent)
                Text("無盡模式").font(.app(size: 34, .semibold))
            }
            Text("從 \(request.words.count) 個字裡隨機抽考，一輪考完會重新洗牌再抽，隨時按左上角結束。")
                .font(.app(.subheadline)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var smartPanel: some View {
        let review = words.filter { !$0.isNew }.count
        let fresh = words.count - review
        let breakdown = Swift.Dictionary(grouping: words) { QType.smart(for: $0, listening: false) }
        return VStack(spacing: 12) {
            if endless { endlessCard } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(words.count) 個字").font(.app(size: 34, .semibold))
                Text("複習 \(review)・新字 \(fresh)・約 \(max(1, words.count / 2)) 分鐘").foregroundStyle(.secondary)
                Divider().padding(.vertical, 6)
                ForEach(QType.allCases.filter { breakdown[$0] != nil }) { t in
                    let n = breakdown[t]!.count
                    HStack {
                        Text(t.rawValue).font(.app(.subheadline, .bold)).lineLimit(1).fixedSize().frame(minWidth: 64, alignment: .leading)
                        GeometryReader { g in
                            Capsule().fill(Color.themeAccent).frame(width: g.size.width * CGFloat(n) / CGFloat(max(1, words.count)))
                        }.frame(height: 6)
                        Text("\(n)").font(.app(.subheadline, .bold))
                    }
                }
            }.card()
            }
            Toggle(isOn: $listening) { Label("包含聽力題", pulso: "headphones").font(.app(.headline)) }.card()
            Text("自動安排會依熟練階梯出題：初見的字翻卡片，越往上越考中翻英、克漏字和拼字。只練一部分時，該複習的字會先排進來。")
                .font(.app(.caption)).foregroundStyle(.secondary)
        }
    }

    private var customPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if endless { endlessCard }
            ForEach(QType.groups, id: \.self) { g in
                Text(g).font(.app(.caption, .bold)).foregroundStyle(.secondary)
                StackGrid(items: QType.allCases.filter { $0.group == g }, columns: 2, spacing: 10) { t in
                        let on = types.contains(t)
                        Button { if on { types.remove(t) } else { types.insert(t) } } label: {
                            HStack {
                                Text(t.rawValue).font(.app(.headline))
                                Spacer(minLength: 0)
                                if on { LIcon("checkmark.circle.fill") }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(ChoiceTileStyle(selected: on))
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}
