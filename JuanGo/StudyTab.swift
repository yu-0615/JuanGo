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

    /// What the home screen shows, worked out once per redraw: these used to be computed properties that each
    /// filtered every word again (six passes over the whole library on every redraw).
    struct Home {
        let studyable: [Word], due: [Word], newWords: [Word]
        var nothingQueued: Bool { due.isEmpty && newWords.isEmpty }
        init(words: [Word], newLeft: Int) {
            studyable = words.filter { $0.inMyWords || !$0.lists.isEmpty }
            due = studyable.filter(\.isDue)
            newWords = Array(studyable.filter(\.isNew).sorted { $0.addedAt < $1.addedAt }.prefix(newLeft))
        }
    }

    var body: some View {
        let h = Home(words: words, newLeft: newLeft)
        NavigationStack {
            List { Group {
                Section {
                    todayRing(h)
                    startButton(h).listRowSeparator(.hidden)
                } header: {
                    Text(Date.now.formatted(.dateTime.month().day().weekday(.wide).locale(.zh)))
                }
                Section {
                    actionRow("自由練習", "沒學會的字隨機考", icon: { LIcon("infinity", size: 22).fontWeight(.semibold).foregroundStyle(Color.themeAccent) }) {
                        flow = StudyRequest(title: "自由練習", words: h.studyable.filter { !$0.isMastered }.shuffled())
                    }
                    .disabled(h.studyable.isEmpty)
                    actionRow("學習紀錄", "每天練了哪些字", icon: { LIcon("calendar").font(.app(.title3)).foregroundStyle(.tint) }) {
                        showHistory = true
                    }
                }
                // the lists come before the chart: practising a list is what this screen is opened for most
                Section("我的清單") {
                    listRow("我的單字", icon: "character.book.closed.fill", words: words.filter(\.inMyWords))
                    listRow("喜歡", icon: "heart.fill", words: words.filter(\.favorite))
                    ForEach(lists) { l in listRow(l.name, icon: "folder.fill", words: l.words) }
                    // made from the log: the words to go over again, without building a list by hand
                    let missed = recentlyMissed()
                    if !missed.isEmpty { listRow("最近答錯", icon: "exclamationmark.circle.fill", words: missed) }
                }
                Section { MasteryCard(distribution: Stats(logs: [], words: h.studyable).distribution, boxed: false) }
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
            .onChange(of: AppRouter.shared.startToday, initial: true) { _, go in
                guard go else { return }
                // cleared a moment later, so the tab bar sees it too and switches here
                Task { @MainActor in AppRouter.shared.startToday = false }
                let h = Home(words: words, newLeft: newLeft)
                if flow == nil, !h.nothingQueued { flow = StudyRequest(title: "今日學習", words: h.due + h.newWords) }
            }
        }
    }

    private var newLeft: Int { max(0, settings.dailyGoal - stats.newToday) }

    /// Words whose latest answer in the past two weeks was 不會 (the logs come newest first).
    private func recentlyMissed() -> [Word] {
        let since = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        var latest: [String: Int] = [:]
        for l in logs {
            if l.date < since { break }
            if latest[l.term] == nil { latest[l.term] = l.result }
        }
        let missed = Set(latest.filter { $0.value == Grade.again.rawValue }.keys)
        return missed.isEmpty ? [] : words.filter { missed.contains($0.term) }
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Today's new words as a ring beside the day's numbers.
    private func todayRing(_ h: Home) -> some View {
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("今天新字 \(stats.newToday) 個，目標 \(settings.dailyGoal) 個")
            VStack(alignment: .leading, spacing: 12) {
                statLine("arrow.triangle.2.circlepath", "待複習", "\(h.due.count) 個")
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

    private func startButton(_ h: Home) -> some View {
        VStack(spacing: 8) {
            Button {
                if h.nothingQueued { onFindWords() } else { flow = StudyRequest(title: "今日學習", words: h.due + h.newWords) }
            } label: {
                Label(h.nothingQueued ? (newLeft > 0 ? "去探索找新字" : "今天都完成了") : "開始今日學習",
                      pulso: h.nothingQueued ? (newLeft > 0 ? "sparkles" : "checkmark") : "play.fill")
            }
            .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
            .disabled(h.nothingQueued && newLeft == 0)
            if h.studyable.isEmpty {
                Text("先到「新增」或「探索」加入幾個單字吧。").font(.app(.caption)).foregroundStyle(.secondary)
            } else if h.nothingQueued {
                // with today done, say what tomorrow holds
                let cal = Calendar.current
                let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: .now)) ?? .distantFuture
                let tomorrow = h.studyable.count { !$0.isNew && ($0.dueDate ?? .distantPast) < end }
                if tomorrow > 0 { Text("明天有 \(tomorrow) 個字要複習").font(.app(.caption)).foregroundStyle(.secondary) }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(.primary).lineLimit(1)
                    // which list needs practising today, without opening it
                    let due = words.count(where: \.isDue)
                    if due > 0 { Text("\(due) 個待複習").font(.app(.caption)).foregroundStyle(.secondary) }
                }
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
                // one set of saved terms instead of a database lookup for each of the deck's (up to 6,000) words
                let have = Set(words.map(\.term))
                let picked = entries.filter { !have.contains($0.w.lowercased()) }.shuffled().prefix(settings.dailyGoal)
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

    /// The type a word is actually asked as (the round and the setup screen's breakdown both use this).
    static func fitted(_ t: QType, for w: Word) -> QType {
        var t = t
        // a phrase with sth / sb / … in it isn't spelled out letter by letter (nobody types "sth" in a test):
        // it's asked as the exam asks it, a cloze with its blanks, or 中翻英 when the example can't be used
        if t == .spelling || t == .listenSpell, WordMatch.blankParts(for: w.term).joined(separator: " ") != w.term { t = .cloze }
        if t == .cloze, w.clozeSentence == nil { t = .zhToEn }   // nothing to blank out in this word's example
        return t
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
