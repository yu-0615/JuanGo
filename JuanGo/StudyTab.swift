import SwiftUI
import SwiftData

// MARK: - Dashboard

struct StudyTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @Query private var words: [Word]
    @Query(sort: \ReviewLog.date, order: .reverse) private var logs: [ReviewLog]
    @Query(sort: \WordList.createdAt) private var lists: [WordList]

    @State private var flow: StudyRequest?
    @State private var showHistory = false
    /// Switches to the Explore tab when the daily goal needs more words than are saved.
    var onFindWords: () -> Void = {}

    /// the home screen only shows today's count and the streak, which come from the logs alone
    private var stats: Stats { Stats(logs: logs, words: []) }
    private var studyable: [Word] { words.filter { $0.inMyWords || !$0.lists.isEmpty } }

    var body: some View {
        NavigationStack {
            List { Group {
                Section {
                    todayRing
                    startButton.listRowSeparator(.hidden)
                } header: {
                    Text(Date.now.formatted(.dateTime.month().day().weekday(.wide).locale(.zh)))
                }
                Section {
                    actionRow("自由練習", "沒學會的字隨機考", icon: { LIcon("infinity", size: 22).fontWeight(.semibold).foregroundStyle(Color.themeAccent) }) {
                        flow = StudyRequest(title: "自由練習", words: studyable.filter { !$0.isMastered }.shuffled())
                    }
                    .disabled(studyable.isEmpty)
                    actionRow("學習紀錄", "每天練了哪些字", icon: { LIcon("calendar").font(.app(.title3)).foregroundStyle(.tint) }) {
                        showHistory = true
                    }
                }
                // the lists come before the chart: practising a list is what this screen is opened for most
                Section("我的清單") {
                    listRow("我的單字", icon: "character.book.closed.fill", words: words.filter(\.inMyWords))
                    listRow("喜歡", icon: "heart.fill", words: words.filter(\.favorite))
                    ForEach(lists) { l in listRow(l.name, icon: "folder.fill", words: l.words) }
                }
                Section { MasteryCard(distribution: Stats(logs: [], words: studyable).distribution, boxed: false) }
                Section {
                    deckRows
                } header: {
                    Text("大考詞彙")
                }
                Section {
                    deckRows(Deck.testDecks)
                } header: {
                    Text("國中小・檢定考試")
                } footer: {
                    Text("從內建字庫開始，會把還沒學過的字加入「我的單字」。")
                }
            }.listRowBackground(Color.cardFill) }
            .listStyle(.insetGrouped)
            .navigationTitle("主頁")
            .themedBackground()
            .fullScreenCover(item: $flow) { StudyFlow(request: $0) }
            #if DEBUG
            .task {   // simulator testing: SIMCTL_CHILD_JUANGO_STUDY=setup | q:英翻中 | summary | streak
                if ProcessInfo.processInfo.environment["JUANGO_STUDY"] != nil, flow == nil {
                    flow = StudyRequest(title: "我的單字", words: words.filter(\.inMyWords).shuffled())
                }
            }
            #endif
            .sheet(isPresented: $showHistory) { HistoryView(logs: logs) }
        }
    }

    private var due: [Word] { studyable.filter(\.isDue) }
    private var newLeft: Int { max(0, settings.dailyGoal - stats.newToday) }
    private var newWords: [Word] { Array(studyable.filter(\.isNew).sorted { $0.addedAt < $1.addedAt }.prefix(newLeft)) }
    private var nothingQueued: Bool { due.isEmpty && newWords.isEmpty }

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Today's new words as a ring beside the day's numbers.
    private var todayRing: some View {
        @Bindable var settings = settings
        let progress = Double(stats.newToday) / Double(max(1, settings.dailyGoal))
        // at accessibility text sizes the numbers go under the ring instead of wrapping beside it
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 22))
        return layout {
            ZStack {
                Circle().stroke(Color.themeAccent.opacity(0.12), lineWidth: 12)
                Circle().trim(from: 0, to: min(1, progress))
                    .stroke(Color.themeAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: progress)
                VStack(spacing: 0) {
                    Text("\(stats.newToday)").font(.app(size: 34, .bold)).contentTransition(.numericText())
                    Text("/ \(settings.dailyGoal) 新字").font(.app(.caption, .semibold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 12) {
                statLine("arrow.triangle.2.circlepath", "待複習", "\(due.count) 個")
                Menu {
                    Picker("每日新字", selection: $settings.dailyGoal) {
                        ForEach([5, 10, 15, 20, 30, 50], id: \.self) { Text("\($0) 個").tag($0) }
                    }
                } label: {
                    statLine("target", "每日目標", "\(settings.dailyGoal) 個 ▾")
                }
                .buttonStyle(.borderless)
                statLine("flame.fill", "連續", "\(stats.streak) 天")
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var startButton: some View {
        VStack(spacing: 8) {
            Button {
                if nothingQueued { onFindWords() } else { flow = StudyRequest(title: "今日學習", words: due + newWords) }
            } label: {
                Label(nothingQueued ? (newLeft > 0 ? "去探索找新字" : "今天都完成了") : "開始今日學習",
                      pulso: nothingQueued ? (newLeft > 0 ? "sparkles" : "checkmark") : "play.fill")
            }
            .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            .disabled(nothingQueued && newLeft == 0)
            if studyable.isEmpty {
                Text("先到「新增」或「探索」加入幾個單字吧。").font(.app(.caption)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private func statLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            LIcon(icon).font(.app(.subheadline, .semibold)).foregroundStyle(.tint).frame(width: 20)
            Text(label).font(.app(.subheadline)).foregroundStyle(.secondary)
            Text(value).font(.app(.subheadline, .semibold)).foregroundStyle(.primary)
        }
    }

    /// A tappable list row: icon, title over subtitle, chevron.
    private func actionRow<I: View>(_ title: String, _ sub: String, @ViewBuilder icon: () -> I, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon().frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(sub).font(.app(.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                LIcon("chevron.right").font(.app(.footnote, .semibold)).foregroundStyle(.tertiary)
            }
        }
    }

    private func listRow(_ name: String, icon: String, words: [Word]) -> some View {
        Button { flow = StudyRequest(title: name, words: words.shuffled()) } label: {
            HStack(spacing: 14) {
                LIcon(icon).foregroundStyle(.tint).frame(width: 28)
                Text(name).foregroundStyle(.primary).lineLimit(1)
                Spacer()
                Text("\(words.count) 個").foregroundStyle(.secondary)
                LIcon("play.circle.fill").font(.app(.title3)).foregroundStyle(words.isEmpty ? Color.secondary.opacity(0.4) : Color.themeAccent)
            }
        }
        .disabled(words.isEmpty)
    }

    @ViewBuilder private var deckRows: some View { deckRows(Deck.examDecks) }

    @ViewBuilder private func deckRows(_ decks: [Deck]) -> some View {
        ForEach(decks) { d in
            let entries = Dictionary_.entries(deck: d)
            Button {
                let picked = entries.filter { Library.word($0.w, in: ctx) == nil }.shuffled().prefix(settings.dailyGoal)
                let ws = picked.map { Library.add($0, in: ctx) }
                flow = StudyRequest(title: d.rawValue, words: ws)
            } label: {
                HStack(spacing: 14) {
                    Text(String(d.rawValue.prefix(1))).font(.app(.headline))
                        .foregroundStyle(.tint).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.rawValue).foregroundStyle(.primary)
                        Text("\(entries.count) 個單字・\(d.subtitle)").font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    LIcon("chevron.right").font(.app(.footnote, .semibold)).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct StudyRequest: Identifiable {
    let id = UUID()
    let title: String
    let words: [Word]
}

// MARK: - Question types

enum QType: String, CaseIterable, Identifiable {
    case flashcard = "翻卡片", enToZh = "英翻中", zhToEn = "中翻英", cloze = "克漏字", spelling = "拼單字"
    case listenZh = "聽音選中文", listenEn = "聽音選英文", listenSpell = "聽音拼字"
    var id: String { rawValue }
    var group: String {
        switch self {
        case .flashcard, .enToZh: "認得"
        case .zhToEn, .cloze: "想得起來"
        case .spelling: "寫得出來"
        default: "聽力"
        }
    }
    static let groups = ["認得", "想得起來", "寫得出來", "聽力"]

    static func smart(for w: Word, listening: Bool) -> QType {
        switch w.srsLevel {
        case 0, 1: return .flashcard
        case 2: return listening && Bool.random() ? .listenZh : .enToZh
        case 3: return listening && Bool.random() ? .listenEn : .zhToEn
        case 4: return w.clozeSentence != nil ? .cloze : .zhToEn
        default: return listening && Bool.random() ? .listenSpell : .spelling
        }
    }
}

extension Word {
    /// The example with the word blanked out, or nil when the example doesn't contain it
    /// (e.g. "machinery" in a sentence that says "machines").
    var clozeSentence: String? {
        guard let pattern = WordMatch.pattern(for: term),
              example.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return example.replacingOccurrences(of: pattern, with: WordMatch.clozeTemplate(for: term), options: [.regularExpression, .caseInsensitive])
    }
}

// MARK: - Engine

@Observable final class SessionEngine {
    struct Item: Identifiable { let id = UUID(); let word: Word; let type: QType }
    private struct Snapshot {
        let queue: [Item]; let pos: Int; let word: Word; let level: Int; let due: Date?; let last: Date?
        let count: Int; let log: ReviewLog?; let done: Set<String>; let failed: Set<String>; let results: [RoundResult]
        let answered: Int
    }

    var queue: [Item]
    var pos = 0
    var done = Set<String>()
    var newLearned = Set<String>()
    /// Words answered 不會 earlier in this session; a later 會 only relearns them.
    private var failed = Set<String>()
    /// Each word's first answer this round, in the order answered (shown on the summary).
    private(set) var results: [RoundResult] = []
    let total: Int
    /// 無盡模式: the words are reshuffled and drawn again every time the queue runs out, until the user ends the round.
    let endless: Bool
    /// Questions answered 會/不確定 this session, repeats included (the endless header counts these).
    private(set) var answered = 0
    private let pool: [Word]
    private let types: [QType]?
    private let listening: Bool
    private var undoStack: [Snapshot] = []

    init(words: [Word], types: [QType]?, listening: Bool, endless: Bool = false) {
        pool = words
        self.types = types
        self.listening = listening
        self.endless = endless
        queue = []
        total = words.count
        queue = draw(words)   // already in a random order (StudyFlow shuffles once, so prefetching matches the cards)
    }

    private func draw(_ words: [Word]) -> [Item] {
        words.map { w in
            var t = types?.randomElement() ?? QType.smart(for: w, listening: listening)
            if t == .cloze, w.clozeSentence == nil { t = .zhToEn }   // nothing to blank out in this word's example
            // the voice says "something" for sth, so a phrase with sth/sb can't be spelled from hearing it
            if t == .listenSpell, Speech.spoken(w.term) != w.term { t = .spelling }
            return Item(word: w, type: t)
        }
    }

    /// Keeps an endless round going: when the last queued question is reached, deal the whole pool again,
    /// never starting the new pass with the word just shown.
    private func refillIfNeeded() {
        guard endless, !pool.isEmpty, pos >= queue.count - 1 else { return }
        var next = pool.shuffled()
        if next.count > 1, let last = queue.last?.word, next.first?.term == last.term { next.swapAt(0, 1) }
        queue += draw(next)
    }

    var current: Item? { pos < queue.count ? queue[pos] : nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var progressText: String { endless ? "已完成 \(answered) 個" : "\(min(total, done.count + 1)) / \(total)" }

    func grade(_ g: Grade, ctx: ModelContext) {
        guard let it = current else { return }
        let w = it.word
        // In endless mode a word comes back many times; only its first answer of the session moves its SRS schedule.
        let counts = !endless || !results.contains(where: { $0.word.term == w.term }) || failed.contains(w.term)
        let log = counts ? ReviewLog(term: w.term, result: g.rawValue, wasNew: w.isNew) : nil
        undoStack.append(Snapshot(queue: queue, pos: pos, word: w, level: w.srsLevel, due: w.dueDate,
                                  last: w.lastReviewed, count: w.reviewCount, log: log, done: done, failed: failed,
                                  results: results, answered: answered))
        if counts {
            if w.isNew { newLearned.insert(w.term) }
            SRS.apply(g == .good && failed.contains(w.term) ? .unsure : g, to: w)
        }
        if g == .again { failed.insert(w.term) } else if endless { failed.remove(w.term) }
        if !results.contains(where: { $0.word.term == w.term }) { results.append(RoundResult(word: w, grade: g)) }
        if let log { ctx.insert(log) }
        try? ctx.save()
        if g == .again {
            let again = Item(word: w, type: it.type == .spelling || it.type == .listenSpell ? .flashcard : it.type)
            queue.insert(again, at: min(queue.count, pos + 4))
        } else {
            done.insert(w.term)
            answered += 1
        }
        refillIfNeeded()
        pos += 1
    }

    func undo(ctx: ModelContext) {
        guard let s = undoStack.popLast() else { return }
        queue = s.queue; pos = s.pos; done = s.done; failed = s.failed; results = s.results; answered = s.answered
        s.word.srsLevel = s.level; s.word.dueDate = s.due; s.word.lastReviewed = s.last; s.word.reviewCount = s.count
        if s.level == 0 { newLearned.remove(s.word.term) }
        if let log = s.log { ctx.delete(log) }
        try? ctx.save()
    }
}

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
                            onAgain: { order = StudyRequest(title: request.title, words: request.words.shuffled()); phase = .setup }, onDone: { dismiss() })
            }
        }
        .animation(.easeInOut, value: phase)

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
                }
            }
        }
    }
}

// MARK: - Session

struct SessionView: View {
    @Bindable var engine: SessionEngine
    let title: String
    var onClose: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @State private var showRules = false
    @State private var detail: Word?
    @State private var gradeTick = 0
    @State private var confirmExit = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            // JuanGo: ✕, a segmented progress track and a ··· menu; the question type and level pips underneath.
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Button { confirmExit = true } label: {
                        LIcon("xmark").font(.app(.headline)).frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("結束練習")
                    progressTrack
                    Menu {
                        Button("學習規則", pulso: "questionmark.circle") { showRules = true }
                        Button("單字詳情", pulso: "text.book.closed") { detail = engine.current?.word }
                        Button("設定", pulso: "slider.horizontal.3") { showSettings = true }
                    } label: {
                        LIcon("ellipsis").font(.app(.headline)).frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("更多")
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(engine.current?.type.rawValue ?? title).font(.app(.title3, .bold))
                    Spacer()
                    if let w = engine.current?.word {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Circle().fill(i <= w.srsLevel ? Color.themeAccent : Color.secondary.opacity(0.22)).frame(width: 7, height: 7)
                            }
                        }
                        Text(levelNames[max(0, min(5, w.srsLevel))]).font(.app(.caption, .bold)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            if let item = engine.current {
                Group {
                    switch item.type {
                    case .flashcard:
                        FlashcardQuestion(word: item.word, canUndo: engine.canUndo, onUndo: { engine.undo(ctx: ctx) },
                                          onDetail: { detail = item.word }, onGrade: grade)
                    case .spelling, .listenSpell:
                        SpellingQuestion(word: item.word, listen: item.type == .listenSpell, canUndo: engine.canUndo,
                                         onUndo: { engine.undo(ctx: ctx) }, onGrade: grade)
                    default:
                        ChoiceQuestion(word: item.word, type: item.type, canUndo: engine.canUndo,
                                       onUndo: { engine.undo(ctx: ctx) }, onGrade: grade)
                    }
                }
                .id(item.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .animation(.spring(duration: 0.35), value: engine.pos)
        // the card on screen first, then the next few, so their example sentences are ready when they come up
        .onChange(of: engine.pos, initial: true) { _, p in
            ExampleStore.shared.prepare(engine.queue.dropFirst(p).prefix(4).map(\.word))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gradeTick) { _, _ in settings.haptics }
        .onAppear { if !settings.studyRulesSeen { showRules = true; settings.studyRulesSeen = true } }
        .sheet(isPresented: $showRules) { RulesSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $detail) { WordDetailSheet(word: $0) }
        .alert("先休息一下？", isPresented: $confirmExit) {
            Button("繼續練", role: .cancel) {}
            Button("離開") { onClose() }
        } message: {
            Text(engine.endless ? "已完成 \(engine.answered) 題，答過的字都已記錄。" : "已完成的進度會保留，沒考到的字下次再練。")
        }
    }

    @ViewBuilder private var progressTrack: some View {
        if engine.endless {
            HStack(spacing: 8) {
                LIcon("infinity", size: 18, play: engine.answered > 0).fontWeight(.semibold).foregroundStyle(Color.themeAccent)
                Text(engine.progressText).font(.app(.subheadline, .semibold).monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            // One segment per word for a short round; a long one (a whole list of hundreds of words) gets a plain
            // bar instead, because a segment and a 3 pt gap per word pushed the track wider than the screen.
            Group {
                if engine.total <= 30 {
                    HStack(spacing: 3) {
                        ForEach(0..<max(1, engine.total), id: \.self) { i in
                            Capsule().fill(i < engine.done.count ? Color.themeAccent : Color.secondary.opacity(0.18))
                        }
                    }
                } else {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule().fill(Color.themeAccent)
                                .frame(width: g.size.width * CGFloat(engine.done.count) / CGFloat(max(1, engine.total)))
                        }
                    }
                }
            }
            .frame(height: 6)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Text(engine.progressText).font(.app(.caption2, .bold).monospacedDigit()).foregroundStyle(.secondary).offset(y: 14)
            }
            .animation(.spring(duration: 0.4), value: engine.done.count)
        }
    }

    private func grade(_ g: Grade) {
        // typed and multiple-choice questions give their own right/wrong feedback the moment they're answered
        if engine.current?.type == .flashcard { gradeTick += 1 }
        engine.grade(g, ctx: ctx)
    }
}

struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List { Group {
                Section("使用提示") {
                    rule("checkmark.circle", "右滑：會", "安排到下次到期再出現。")
                    rule("xmark.circle", "左滑：不會", "約 20 分鐘後再出現，本輪也會再考一次。")
                    rule("questionmark.circle", "不確定", "明天再複習一次。")
                    rule("hand.tap", "點一下：看解釋", "卡片會翻到解釋面。")
                    rule("heart", "愛心：加入喜歡", "喜歡的單字會進入「喜歡」清單。")
                    rule("arrow.uturn.backward", "撤銷", "復原上一個答案。")
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .navigationTitle("學習規則").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
    private func rule(_ icon: String, _ title: String, _ sub: String) -> some View {
        Label { VStack(alignment: .leading) { Text(title).font(.app(.headline)); Text(sub).font(.app(.caption)).foregroundStyle(.secondary) } }
            icon: { LIcon(icon).foregroundStyle(.tint) }
    }
}

/// 不會 / 不確定 / 會 as three square tiles with an icon over the label.
struct GradeButtons: View {
    var onGrade: (Grade) -> Void
    var body: some View {
        HStack(spacing: 10) {
            tile("不會", "xmark", .againPink, .againInk, .again)
            tile("不確定", "questionmark", .unsureYellow, .unsureInk, .unsure)
            tile("會", "checkmark", .knowGreen, .knowInk, .good)
        }
    }
    private func tile(_ t: String, _ icon: String, _ fill: Color, _ ink: Color, _ g: Grade) -> some View {
        Button { onGrade(g) } label: {
            VStack(spacing: 4) {
                LIcon(icon).font(.app(.title3, .bold))
                Text(t).font(.app(.subheadline, .bold))
            }
        }
        .buttonStyle(PillButtonStyle(fill: fill, foreground: ink, height: 66))
    }
}

struct FlashcardQuestion: View {
    let word: Word
    let canUndo: Bool
    var onUndo: () -> Void
    var onDetail: () -> Void
    var onGrade: (Grade) -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var lookup: LookupTerm?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                face(back: false).opacity(flipped ? 0 : 1)
                face(back: true).opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            }
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.4)
            .overlay(alignment: .top) { swipeHint }
            .offset(x: drag.width, y: drag.height * 0.2)
            .rotationEffect(.degrees(Double(drag.width) / 22))
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { v in
                        if v.translation.width > 120 { fling(.good, to: 600) }
                        else if v.translation.width < -120 { fling(.again, to: -600) }
                        else { withAnimation(.spring) { drag = .zero } }
                    }
            )
            .onTapGesture { withAnimation(.spring(duration: 0.5)) { flipped.toggle() } }
            .padding(.top, 20)
            HStack(spacing: 20) {
                Button(action: onUndo) { Label("復原", pulso: "arrow.uturn.backward") }.disabled(!canUndo)
                Spacer()
                Button { word.favorite.toggle(); try? ctx.save() } label: { LIcon(word.favorite ? "heart.fill" : "heart") }
                    .foregroundStyle(word.favorite ? AnyShapeStyle(Color.themeAccent) : AnyShapeStyle(.secondary))
                    .accessibilityLabel(word.favorite ? "取消喜歡" : "喜歡")
                // no speaker here: the one beside the phonetics on the card already says the word
            }
            .font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            GradeButtons(onGrade: onGrade)
        }
        .padding(.bottom, 12)
        .onAppear {
            if !settings.muted { Speech.say(word.term) }
            #if DEBUG
            if ProcessInfo.processInfo.environment["JUANGO_FLIP"] != nil { flipped = true }   // simulator: show the back
            #endif
        }
        .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
    }

    @ViewBuilder private var swipeHint: some View {
        if abs(drag.width) > 30 {
            Text(drag.width > 0 ? "會" : "不會").font(.app(.title2, .semibold))
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(Capsule().fill(drag.width > 0 ? Color.knowGreen : Color.againPink))
                .padding(.top, 20)
                .opacity(min(1, abs(drag.width) / 120))
        }
    }

    private func fling(_ g: Grade, to x: CGFloat) {
        withAnimation(.easeIn(duration: 0.2)) { drag = CGSize(width: x, height: 0) }
        Task { try? await Task.sleep(for: .seconds(0.2)); onGrade(g) }
    }

    /// Card faces are left-aligned like a dictionary entry: headword, pronunciation, then meaning and example.
    private func face(back: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !word.pos.isEmpty {
                    Text(word.pos).font(.app(.caption, .bold)).foregroundStyle(.tint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color.themeAccent.opacity(0.12)))
                }
                Spacer()
                Text(back ? "解釋" : "點一下翻面").font(.app(.caption, .semibold)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(word.term).font(.app(size: back ? 36 : 46, .bold)).minimumScaleFactor(0.5).lineLimit(1)
            Button { Speech.say(word.term) } label: {
                HStack(spacing: 6) {
                    LIcon("speaker.wave.2.fill").foregroundStyle(.tint)
                    if !word.ipa.isEmpty { Text("/\(word.ipa)/").foregroundStyle(.secondary) }
                }.font(.app(.subheadline))
            }
            .accessibilityLabel(word.ipa.isEmpty ? "念出來" : "念出來，音標 \(word.ipa)")
            .buttonStyle(.plain)
            if back {
                Divider().padding(.vertical, 4)
                Text(word.primaryMeaning).font(.app(size: 28, .bold))
                if word.meanings.count > 1 {
                    Text("也有：" + word.meanings.dropFirst().prefix(3).joined(separator: "、")).font(.app(.subheadline)).foregroundStyle(.secondary)
                }
            }
            exampleBlock(back: back)
                // room for a two-line sentence and its translation, kept even while it is being written,
                // so the headword above doesn't jump when the on-device model finishes
                .frame(minHeight: back ? 0 : 118, alignment: .topLeading)
            Spacer(minLength: 0)
            if back {
                Button { onDetail() } label: { Label("完整單字頁", pulso: "arrow.up.right") }.font(.app(.subheadline, .bold))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.cardFill))
    }

    @ViewBuilder private func exampleBlock(back: Bool) -> some View {
            if !word.example.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    TappableSentence(sentence: word.example, highlight: word.term, font: .app(.body, .medium)) { lookup = LookupTerm(term: $0) }
                    if back && settings.showTranslation { Text(word.exampleZh).font(.app(.subheadline)).foregroundStyle(.secondary) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.themeAccent.opacity(0.06)))
                .overlay(alignment: .leading) { Rectangle().fill(Color.themeAccent).frame(width: 3).padding(.vertical, 8) }
            } else if ExampleStore.shared.isGenerating(word) {
                VStack(alignment: .leading, spacing: 6) {
                    if let p = ExampleStore.shared.partial(for: word) {
                        // the sentence as the on-device model writes it; it becomes tappable once finished
                        Text(p.en).font(.app(.body, .medium))
                        if back && settings.showTranslation && !p.zh.isEmpty { Text(p.zh).font(.app(.subheadline)).foregroundStyle(.secondary) }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在寫例句…").font(.app(.subheadline)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.themeAccent.opacity(0.06)))
            } else if back && !word.definition.isEmpty {
                Text(word.definition).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(3)
            }
    }
}

/// Multiple-choice question: EN→ZH, ZH→EN, cloze, and the two listening variants.
struct ChoiceQuestion: View {
    let word: Word
    let type: QType
    var canUndo = false
    var onUndo: () -> Void = {}
    var onGrade: (Grade) -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(AppSettings.self) private var settings
    @State private var options: [String] = []
    /// each wrong option's other side (the English word of a Chinese option, and the other way round),
    /// shown under it once picked, so a wrong answer still teaches a word
    @State private var otherSide: [String: String] = [:]
    @State private var picked: String?
    @State private var lookup: LookupTerm?

    private var answersInZh: Bool { type == .enToZh || type == .listenZh }
    /// A cloze whose phrase leaves two blanks ("We need to ____ the project ____.") is answered the way exams
    /// print it, one part per blank: "keep / alive", with every other option in the same shape.
    private var splitParts: [String]? {
        guard type == .cloze else { return nil }
        let p = WordMatch.blankParts(for: word.term)
        return p.count >= 2 ? p : nil
    }
    private var correct: String { answersInZh ? word.primaryMeaning : splitParts?.joined(separator: " / ") ?? word.term }

    /// Prompt on the page, then four lettered answer rows; undo and ♡ sit in a slim bar at the bottom.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: type == .cloze ? .leading : .center, spacing: 10) { prompt }
                .frame(maxWidth: .infinity, minHeight: 170)
            ForEach(Array(options.enumerated()), id: \.element) { k, o in
                Button { choose(o) } label: {
                    HStack(spacing: 14) {
                        Text(String(UnicodeScalar(65 + k)!)).font(.app(.subheadline, .bold)).monospaced()
                            .foregroundStyle(picked == nil ? Color.themeAccent : .primary)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(picked == nil ? Color.themeAccent.opacity(0.1) : Color.primary.opacity(0.06)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(o).font(.app(.headline)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(.primary)
                            if picked == o, o != correct, let other = otherSide[o] {
                                Text(other).font(.app(.subheadline, .semibold)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        if picked != nil && o == correct { LIcon("checkmark.circle.fill").foregroundStyle(.green) }
                        else if picked == o { LIcon("xmark.circle.fill").foregroundStyle(Color.themeAccent) }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(fill(for: o)))
                }
                .buttonStyle(.plain)
                // not .disabled: that dimmed every row, the right answer included, just when it should stand out
                .allowsHitTesting(picked == nil)
            }
            Spacer(minLength: 10)
            HStack(spacing: 18) {
                Button(action: onUndo) { Label("復原", pulso: "arrow.uturn.backward") }
                    .disabled(!canUndo)
                Button { word.favorite.toggle(); try? ctx.save() } label: {
                    LIcon(word.favorite ? "heart.fill" : "heart")
                }
                .foregroundStyle(word.favorite ? AnyShapeStyle(Color.themeAccent) : AnyShapeStyle(.secondary))
                .accessibilityLabel(word.favorite ? "取消喜歡" : "喜歡")
                Spacer()
                if let picked, picked != correct {
                    Button("下一題") { onGrade(.again) }
                        .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 46, glass: true)).frame(width: 120)
                }
            }
            .font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
            .frame(minHeight: 46)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .onAppear {
            options = makeOptions()
            if type == .listenZh || type == .listenEn || (!settings.muted && type == .enToZh) { Speech.say(word.term) }
        }
        .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
        .sensoryFeedback(trigger: picked) { _, new in
            guard settings.haptics, let new else { return nil }
            return new == correct ? .success : .error
        }
    }

    @ViewBuilder private var prompt: some View {
        switch type {
        case .enToZh:
            Text(word.term).font(.app(size: 44, .bold)).lineLimit(1).minimumScaleFactor(0.5)
            HStack(spacing: 10) {
                if !word.ipa.isEmpty { Text("/\(word.ipa)/").font(.app(.footnote, .semibold)).foregroundStyle(.secondary) }
                SpeakButton(text: word.term).font(.app(.footnote))
            }
        case .zhToEn:
            Text(word.meaningLine).font(.app(size: 32, .bold)).multilineTextAlignment(.center)
            if !word.pos.isEmpty { Text(word.pos).font(.app(.footnote, .semibold)).foregroundStyle(.secondary) }
        case .cloze:
            Text("選出填入空格的字").font(.app(.caption, .semibold)).foregroundStyle(.secondary)
            TappableSentence(sentence: clozeSentence, font: .app(.title3, .semibold)) { lookup = LookupTerm(term: $0) }
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Button { Speech.say(word.term) } label: {
                LIcon("speaker.wave.3.fill").font(.app(size: 44)).frame(width: 110, height: 110)
                    .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.themeAccent.opacity(0.12)))
            }.buttonStyle(.plain).foregroundStyle(.tint)
            .accessibilityLabel("再聽一次")
            Text(type == .listenZh ? "聽發音，選出中文意思" : "聽發音，選出正確的英文").font(.app(.caption)).foregroundStyle(.secondary)
        }
    }

    private var clozeSentence: String { word.clozeSentence ?? word.example }

    private func fill(for o: String) -> Color {
        let idle = Color.cardFill
        guard let picked else { return idle }
        if o == correct { return .knowGreen }
        if o == picked { return .againPink }
        return idle
    }

    private func choose(_ o: String) {
        guard picked == nil else { return }
        picked = o
        if o == correct {
            Speech.say(word.term)
            Task { try? await Task.sleep(for: .seconds(0.7)); onGrade(.good) }
        }
    }

    /// Options for a two-blank cloze: other phrases that also split into that many parts, then made-up ones
    /// with every part swapped for a dictionary word of the same part of speech and similar length.
    private func splitOptions(_ parts: [String]) -> [String] {
        let library = (try? ctx.fetch(FetchDescriptor<Word>())) ?? []
        let phrases = Set((library.map(\.term) + Dictionary_.all.map(\.w))
            .filter { $0 != word.term && $0.contains(" ") && GlossaryParser.cleanTerm($0) == $0 })
        var picks: [String] = []
        for p in phrases.shuffled() {
            let ps = WordMatch.blankParts(for: p)
            let v = ps.joined(separator: " / ")
            if ps.count == parts.count, v != correct, !picks.contains(v) { picks.append(v) }
            if picks.count == 3 { break }
        }
        func lookalike(_ part: String) -> String {
            part.split(separator: " ").map { w in
                let w = String(w), pos = Dictionary_.lookup(w)?.pos ?? ""
                let pool = (Dictionary_.byPos[pos] ?? []).filter { !$0.w.contains(" ") && $0.w != w && abs($0.w.count - w.count) <= 2 }
                // common words (levels 1–3) look like real exam distractors; rare ones (wistful) give it away
                let common = pool.filter { ["1", "2", "3"].contains($0.lv) }
                return (common.isEmpty ? pool : common).randomElement()?.w ?? w
            }.joined(separator: " ")
        }
        var tries = 0
        while picks.count < 3 && tries < 40 {
            tries += 1
            let fake = parts.map(lookalike)
            let v = fake.joined(separator: " / ")
            // every part different, so no option is half right
            if zip(fake, parts).allSatisfy({ $0.0 != $0.1 }), v != correct, !picks.contains(v) { picks.append(v) }
        }
        return (picks + [correct]).shuffled()
    }

    private func makeOptions() -> [String] {
        if let parts = splitParts { return splitOptions(parts) }
        // Distractors come from same-part-of-speech dictionary words plus the user's own; a small random sample
        // is enough (mapping all 10k dictionary entries on every question made the card transition stutter).
        // fetched once here rather than kept live with @Query, which re-rendered the question on every save
        let library = (try? ctx.fetch(FetchDescriptor<Word>())) ?? []
        let own: [(term: String, zh: String, pos: String)] = library.map { ($0.term, $0.primaryMeaning, $0.pos) }
        let dictSame = (Dictionary_.byPos[word.pos] ?? []).shuffled().prefix(40).map { ($0.w, $0.zh.first ?? "", $0.pos) }
        let dictAny = (0..<40).compactMap { _ in Dictionary_.all.randomElement() }.map { ($0.w, $0.zh.first ?? "", $0.pos) }
        let pool: [(term: String, zh: String, pos: String)] = own + dictSame + dictAny
        let others = pool.filter { $0.term != word.term && !$0.zh.isEmpty && $0.zh != word.primaryMeaning }
        let samePos = others.filter { $0.pos == word.pos }.shuffled()
        // a phrase among single words gives itself away, so English options for a phrase are phrases first
        let phrases = !answersInZh && word.term.contains(" ")
            ? (others + Dictionary_.all.filter { $0.w.contains(" ") && !$0.zh.isEmpty }.map { ($0.w, $0.zh.first ?? "", $0.pos) })
                .filter { $0.term.contains(" ") && $0.term != word.term && GlossaryParser.cleanTerm($0.term) == $0.term }.shuffled()
            : []
        var picks: [String] = []
        for c in (phrases + samePos + others.shuffled()) {
            if !answersInZh, !word.term.contains(" "), c.term.contains(" ") { continue }   // and the other way round
            let v = answersInZh ? c.zh : c.term
            if !picks.contains(v) && v != correct { picks.append(v); otherSide[v] = answersInZh ? c.term : c.zh }
            if picks.count == 3 { break }
        }
        return (picks + [correct]).shuffled()
    }
}

struct SpellingQuestion: View {
    let word: Word
    let listen: Bool
    var canUndo = false
    var onUndo: () -> Void = {}
    var onGrade: (Grade) -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(AppSettings.self) private var settings
    @State private var text = ""
    @State private var checked: Bool?
    @State private var gaveUp = false
    /// one letter off (a typo, a missed double letter): shown as 差一點 and graded 不確定 rather than 不會
    @State private var nearMiss = false
    @State private var typing = false

    /// The meaning on top, then one box per letter (first and last letter shown) that the answer is typed into.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                if listen {
                    Button { Speech.say(word.term) } label: {
                        LIcon("speaker.wave.3.fill").font(.app(size: 40)).frame(width: 100, height: 100)
                            .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.themeAccent.opacity(0.12)))
                    }.buttonStyle(.plain).foregroundStyle(.tint)
                } else {
                    Text(word.meaningLine).font(.app(size: 28, .bold)).multilineTextAlignment(.center)
                    if !word.pos.isEmpty { Text(word.pos).font(.app(.subheadline, .semibold)).foregroundStyle(.secondary) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            // The letters are typed straight into the boxes; the text field that takes the keystrokes sits hidden
            // behind them (a separate field below repeated the same letters). It's a UIKit field because SwiftUI's
            // autocorrectionDisabled() still leaves the suggestion bar up, which spells the answer out.
            letterBoxes
                .background {
                    SpellingField(placeholder: "", text: $text, focused: $typing, maxLength: word.term.count, onSubmit: check)
                        .allowsHitTesting(false)
                        .disabled(checked != nil)
                        .accessibilityLabel("拼出單字")
                }
                .contentShape(Rectangle())
                .onTapGesture { if checked == nil { typing = true } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("拼出單字，已輸入 \(text.count) 個字母，共 \(word.term.count) 個")
                .accessibilityAddTraits(.isButton)
            if let checked {
                Label(checked ? "拼對了！" : nearMiss ? "差一點！答案是 \(word.term)" : "答案是 \(word.term)",
                      pulso: checked ? "checkmark.circle.fill" : nearMiss ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(.app(.headline)).foregroundStyle(checked ? Color.knowInk : nearMiss ? Color.unsureInk : Color.themeAccent)
            } else {
                HStack(spacing: 12) {
                    Button("想不起來", pulso: "questionmark") { gaveUp = true; checked = false; Speech.say(word.term) }
                        .buttonStyle(PillButtonStyle(foreground: .themeAccent, height: 50))
                    Button("檢查", pulso: "checkmark") { check() }
                        .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 50, glass: true))
                        .disabled(text.isEmpty)
                }
            }
            Spacer()
            HStack(spacing: 18) {
                Button(action: onUndo) { Label("復原", pulso: "arrow.uturn.backward") }
                    .disabled(!canUndo)
                Button { word.favorite.toggle(); try? ctx.save() } label: {
                    LIcon(word.favorite ? "heart.fill" : "heart")
                }
                .foregroundStyle(word.favorite ? AnyShapeStyle(Color.themeAccent) : AnyShapeStyle(.secondary))
                .accessibilityLabel(word.favorite ? "取消喜歡" : "喜歡")
                Spacer()
                if checked == false {
                    Button("下一題") { onGrade(nearMiss ? .unsure : .again) }
                        .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 46, glass: true)).frame(width: 120)
                }
            }
            .font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
            .frame(minHeight: 46)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .onAppear { if listen { Speech.say(word.term) } }
        // the keyboard comes up by itself, so the answer can be typed right away
        .task { try? await Task.sleep(for: .milliseconds(350)); typing = true }
        .sensoryFeedback(trigger: checked) { _, new in
            guard settings.haptics, let new else { return nil }
            return new ? .success : gaveUp ? nil : nearMiss ? .warning : .error
        }
    }

    /// One box per letter; typed letters fill in as you go.
    /// One box per letter. A phrase wraps word by word onto more rows instead of shrinking every box to fit
    /// one line ("take sth into account" made 12-point boxes); the spaces between words aren't boxes.
    private var letterBoxes: some View {
        let t = Array(word.term)
        let matched = checked != nil ? Self.matchedLetters(of: word.term, in: text) : []
        let width = UIScreen.main.bounds.width - 40
        // index ranges of the words, split at spaces
        var words: [Range<Int>] = [], from = 0
        for k in 0...t.count where k == t.count || t[k] == " " {
            if k > from { words.append(from..<k) }
            from = k + 1
        }
        let longest = words.map(\.count).max() ?? 1
        let side = max(22, min(40, width / CGFloat(longest) - 4))
        let gap = side * 0.5
        var rows: [[Range<Int>]] = [], used: CGFloat = 0
        for w in words {
            let need = CGFloat(w.count) * (side + 4)
            if let last = rows.indices.last, used + gap + need <= width { rows[last].append(w); used += gap + need }
            else { rows.append([w]); used = need }
        }
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(rows[r], id: \.lowerBound) { w in
                        HStack(spacing: 4) { ForEach(Array(w), id: \.self) { k in box(k, t: t, side: side, wrong: checked != nil && !matched.contains(k)) } }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func box(_ k: Int, t: [Character], side: CGFloat, wrong: Bool) -> some View {
        let typed = Array(text)
        // hyphens, apostrophes and dots are shown like the first and last letter (T-shirt, o'clock, Mr.)
        let given = k == 0 || k == t.count - 1 || "-'’.".contains(t[k])
        // once checked, the boxes spell the answer, with the letters typed wrong in red
        let ch: String = checked != nil ? String(t[k]) : k < typed.count ? String(typed[k]) : (given ? String(t[k]) : "")
        return Text(ch).font(.system(size: side * 0.55, weight: .bold, design: .monospaced))
            .foregroundStyle(wrong ? Color.themeAccent : k < typed.count || checked != nil ? Color.primary : Color.secondary)
            .frame(width: side, height: side * 1.2)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.tertiarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(k == typed.count && checked == nil && typing ? Color.themeAccent : .clear, lineWidth: 2))
    }

    private func check() {
        guard checked == nil, !text.isEmpty else { return }
        let typed = text.trimmingCharacters(in: .whitespaces).lowercased(), answer = word.term.lowercased()
        let ok = typed == answer
        nearMiss = !ok && answer.count >= 4 && Self.distance(typed, answer) == 1
        checked = ok
        Speech.say(word.term)
        if ok { Task { try? await Task.sleep(for: .seconds(0.8)); onGrade(.good) } }
    }

    /// Positions in `answer` that line up with what was typed (longest common subsequence), so a missed letter
    /// marks only that letter, not everything after it: atraction → a t [t] r a c t i o n.
    static func matchedLetters(of answer: String, in typed: String) -> Set<Int> {
        let a = Array(answer.lowercased()), b = Array(typed.lowercased())
        guard !a.isEmpty, !b.isEmpty else { return [] }
        var l = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                l[i][j] = a[i] == b[j] ? l[i+1][j+1] + 1 : max(l[i+1][j], l[i][j+1])
            }
        }
        var out = Set<Int>(), i = 0, j = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { out.insert(i); i += 1; j += 1 }
            else if l[i+1][j] >= l[i][j+1] { i += 1 } else { j += 1 }
        }
        return out
    }

    /// Edit distance (insert, delete, replace one letter), counting a swap of two neighbours as one: recieve → receive.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                d[i][j] = min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + (a[i-1] == b[j-1] ? 0 : 1))
                if i > 1, j > 1, a[i-1] == b[j-2], a[i-2] == b[j-1] { d[i][j] = min(d[i][j], d[i-2][j-2] + 1) }
            }
        }
        return d[a.count][b.count]
    }
}

/// A plain text field with no autocorrection, spell checking or predictions, for typing a spelling answer.
struct SpellingField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var focused: Bool
    var maxLength = Int.max
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let f = UITextField()
        f.placeholder = placeholder
        if placeholder.isEmpty { f.textColor = .clear; f.tintColor = .clear }   // hidden behind the letter boxes
        f.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .monospacedSystemFont(ofSize: 20, weight: .semibold))
        f.adjustsFontForContentSizeCategory = true
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.spellCheckingType = .no
        f.smartQuotesType = .no
        f.smartDashesType = .no
        f.smartInsertDeleteType = .no
        f.inlinePredictionType = .no
        f.keyboardType = .asciiCapable
        f.returnKeyType = .done
        f.inputAssistantItem.leadingBarButtonGroups = []
        f.inputAssistantItem.trailingBarButtonGroups = []
        f.delegate = context.coordinator
        f.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        f.setContentHuggingPriority(.defaultLow, for: .horizontal)
        f.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return f
    }

    func updateUIView(_ f: UITextField, context: Context) {
        context.coordinator.parent = self
        if f.text != text { f.text = text }
        f.isEnabled = context.environment.isEnabled
        if focused, f.isEnabled, !f.isFirstResponder { DispatchQueue.main.async { f.becomeFirstResponder() } }
        if (!focused || !f.isEnabled), f.isFirstResponder { DispatchQueue.main.async { f.resignFirstResponder() } }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SpellingField
        init(_ p: SpellingField) { parent = p }
        @objc func changed(_ f: UITextField) {
            var t = f.text ?? ""
            if t.count > parent.maxLength { t = String(t.prefix(parent.maxLength)); f.text = t }   // one letter per box
            parent.text = t
        }
        func textFieldDidBeginEditing(_ f: UITextField) { if !parent.focused { parent.focused = true } }
        func textFieldDidEndEditing(_ f: UITextField) { if parent.focused { parent.focused = false } }
        func textFieldShouldReturn(_ f: UITextField) -> Bool { parent.onSubmit(); return false }
    }
}

// MARK: - Celebration screens

struct StreakView: View {
    let stats: Stats
    var onContinue: () -> Void
    @State private var appear = false
    @State private var showShare = false

    var body: some View {
        let streak = stats.streak
        let next = BadgeKind.all[0].next(for: streak)
        VStack(spacing: 22) {
            HStack { Spacer(); ShareLink(item: "我在 JuanGo 已經連續學習 \(streak) 天了！") { GlassCircleIcon(systemName: "square.and.arrow.up") }
                .buttonStyle(.glass).buttonBorderShape(.circle) }
            Spacer()
            ZStack {
                LIcon("drop.fill").font(.app(size: 220)).foregroundStyle(Color(white: 0.72))
                LIcon("flame.fill").font(.app(size: 92))
                    .foregroundStyle(Color.orange)
                    .offset(y: 30)
            }
            .scaleEffect(appear ? 1 : 0.5)
            Text("\(streak)").font(.app(size: 80, .semibold)).contentTransition(.numericText())
            Text("天連續學習").font(.app(.title3, .bold))
            weekDots
            Text(streak >= next ? "已解鎖所有連續勳章" : "再 \(next - streak) 天解鎖下一枚連續勳章").font(.app(.subheadline)).opacity(0.7)
            Spacer()
            Button("繼續", action: onContinue)
                .buttonStyle(PillButtonStyle(fill: .white, foreground: .black)).frame(width: 160)
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(Color.black.ignoresSafeArea())
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.4)) { appear = true } }
    }

    private var weekDots: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
        let fmt = Date.FormatStyle().weekday(.narrow).locale(.zh)
        return HStack(spacing: 12) {
            ForEach(days, id: \.self) { d in
                VStack(spacing: 6) {
                    if stats.activeDays.contains(d) {
                        LIcon("flame.fill").font(.app(.title2)).foregroundStyle(.orange).frame(width: 30, height: 30)
                    } else {
                        Circle().fill(.white.opacity(0.12)).frame(width: 30, height: 30)
                    }
                    Text(d.formatted(fmt)).font(.app(.caption2, .bold)).opacity(0.6)
                }
            }
        }
    }
}

struct SummaryView: View {
    let stats: Stats
    let roundCount: Int
    let results: [RoundResult]
    var onAgain: () -> Void
    var onDone: () -> Void
    @Environment(AppSettings.self) private var settings
    @State fileprivate var detail: Word?

    var body: some View {
        let left = max(0, settings.dailyGoal - stats.newToday)
        let count = { (g: Grade) in results.filter { $0.grade == g }.count }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("這一輪完成了").font(.app(.largeTitle, .bold)).padding(.top, 30)
                Text("共 \(roundCount) 個字・今天新學 \(stats.newToday) 個・連續 \(stats.streak) 天")
                    .font(.app(.subheadline, .semibold)).foregroundStyle(.secondary)
                HStack(spacing: 22) {
                    ScoreRing(good: count(.good), unsure: count(.unsure), again: count(.again)).frame(width: 140, height: 140)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach([Grade.good, .unsure, .again], id: \.self) { g in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(g.ring).frame(width: 12, height: 12)
                                Text(g.label).font(.app(.subheadline)).foregroundStyle(.secondary)
                                Text("\(count(g))").font(.app(.subheadline, .bold)).monospacedDigit()
                            }
                        }
                    }
                }
                .card(padding: 20)
                if !settings.reminderAsked && !settings.reminderOn {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("每天提醒你回來練習？", pulso: "bell.badge.fill").font(.app(.headline))
                        Text("每天 \(settings.reminderText) 通知你，複習才不會中斷。").font(.app(.subheadline)).foregroundStyle(.secondary)
                        HStack {
                            Button("先不要") { settings.reminderAsked = true }.buttonStyle(PillButtonStyle(height: 44))
                            Button("開啟提醒") { settings.reminderAsked = true; settings.reminderOn = true }
                                .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 44, glass: true))
                        }
                    }.card()
                }
                // the words come before the badges: which ones were missed is what's worth a second look
                if !results.isEmpty { resultsCard }
                Text("成就").font(.app(.title3, .bold))
                HStack(alignment: .top) {
                    ForEach(BadgeKind.all) { k in BadgeMedal(kind: k, value: BadgeKind.value(k.id, stats: stats), size: 52).frame(maxWidth: .infinity) }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $detail) { WordDetailSheet(word: $0) }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("結束", action: onDone).buttonStyle(PillButtonStyle(height: 54)).frame(width: 110)
                Button(action: onAgain) {
                    // the goal part goes when it doesn't fit (large text), rather than cutting the words off
                    ViewThatFits { Text(left > 0 ? "再練一輪・目標還差 \(left) 字" : "再練一輪"); Text("再練一輪") }
                }
                    .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, height: 54, glass: true))
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(.bar)
        }
    }
}

extension SummaryView {
    fileprivate var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("這輪的字").font(.app(.headline, .bold))
                Spacer()
                ForEach([Grade.good, .unsure, .again], id: \.self) { g in
                    let n = results.filter { $0.grade == g }.count
                    if n > 0 { Text("\(g.label) \(n)").font(.app(.caption, .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(g.tint)) }
                }
            }
            // missed words first, then unsure, then known; a row opens the word's page
            let order: [Grade: Int] = [.again: 0, .unsure: 1, .good: 2]
            let sorted = results.enumerated().sorted { (order[$0.element.grade] ?? 3, $0.offset) < (order[$1.element.grade] ?? 3, $1.offset) }.map(\.element)
            ForEach(sorted) { r in
                Button { detail = r.word } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.word.term).font(.app(.headline)).foregroundStyle(.primary)
                            Text(r.word.primaryMeaning).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(levelNames[max(0, min(5, r.word.srsLevel))]).font(.app(.caption, .bold)).foregroundStyle(.tint)
                        RoundedRectangle(cornerRadius: 3).fill(r.grade.ring).frame(width: 12, height: 12)
                            .accessibilityLabel(r.grade.label)
                        LIcon("chevron.right").font(.app(.footnote, .semibold)).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if r.id != sorted.last?.id { Divider() }
            }
        }
        .card()
    }
}

struct RoundResult: Identifiable {
    let word: Word
    let grade: Grade
    var id: String { word.term }
}

extension Grade {
    var label: String { switch self { case .good: "會"; case .unsure: "不確定"; case .again: "不會" } }
    var tint: Color { switch self { case .good: .knowGreen; case .unsure: .unsureYellow; case .again: .againPink } }
    /// Strong version used in the score ring and legends.
    var ring: Color { switch self { case .good: .green.opacity(0.75); case .unsure: .orange; case .again: .themeAccent } }
}

struct HistoryView: View {
    let logs: [ReviewLog]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    var body: some View {
        NavigationStack {
            List { Group {
                if logs.isEmpty { EmptyState("還沒有學習紀錄", icon: "clock") }
                let groups = Swift.Dictionary(grouping: logs.prefix(500)) { Calendar.current.startOfDay(for: $0.date) }
                ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                    Section(day.formatted(.dateTime.month().day().weekday().locale(.zh))) {
                        ForEach(groups[day]!) { l in
                            // a row opens the word's page (a word deleted since then just shows the row)
                            let w = Library.word(l.term, in: ctx)
                            NavigationLink(value: w) {
                            HStack {
                                Text(l.term).font(.app(.headline))
                                if l.wasNew { Text("新字").font(.app(.caption2, .bold)).foregroundStyle(.tint) }
                                Spacer()
                                Text(["不會", "不確定", "會"][l.result]).font(.app(.subheadline))
                                    .foregroundStyle([Color.red, .orange, .green][l.result])
                                Text(l.date.formatted(.dateTime.hour().minute().locale(.zh))).font(.app(.caption)).foregroundStyle(.secondary)
                            }
                            }
                            .disabled(w == nil)
                        }
                    }
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .navigationTitle("學習紀錄")
            .navigationDestination(for: Word.self) { WordDetailView(word: $0) }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { dismiss() } } }
        }
    }
}
