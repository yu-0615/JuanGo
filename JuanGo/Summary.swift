import SwiftUI
import SwiftData

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
    /// Starts another round with only the given words (the ones missed this round).
    var onRetry: ([Word]) -> Void = { _ in }
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
            // practising just the missed words again is the usual next step; 再練一輪 redoes the whole list
            let missed = results.filter { $0.grade == .again }.map(\.word)
            if !missed.isEmpty {
                Button { onRetry(missed) } label: { Label("只練答錯的 \(missed.count) 個字", pulso: "arrow.counterclockwise") }
                    .buttonStyle(PillButtonStyle(height: 44))
                    .padding(.top, 4)
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
    /// Readable text colour for the grade (the same inks as the grade buttons).
    var ink: Color { switch self { case .good: .knowInk; case .unsure: .unsureInk; case .again: .againInk } }
}

struct HistoryView: View {
    let logs: [ReviewLog]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    var body: some View {
        // one fetch for every row, not one per row (up to 500)
        let byTerm = Swift.Dictionary(((try? ctx.fetch(FetchDescriptor<Word>())) ?? []).map { ($0.term, $0) }, uniquingKeysWith: { a, _ in a })
        NavigationStack {
            List { Group {
                if logs.isEmpty { EmptyState("還沒有學習紀錄", icon: "clock") }
                let groups = Swift.Dictionary(grouping: logs.prefix(500)) { Calendar.current.startOfDay(for: $0.date) }
                ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                    Section(day.formatted(.dateTime.month().day().weekday().locale(.zh))) {
                        ForEach(groups[day]!) { l in
                            // a row opens the word's page (a word deleted since then just shows the row)
                            let w = byTerm[l.term]
                            NavigationLink(value: w) {
                            HStack {
                                Text(l.term).font(.app(.headline))
                                if l.wasNew { Text("新字").font(.app(.caption2, .bold)).foregroundStyle(.tint) }
                                Spacer()
                                // a result out of range (synced from a newer version, say) shows nothing rather than crashing
                                if let g = Grade(rawValue: l.result) {
                                    Text(g.label).font(.app(.subheadline, .semibold)).foregroundStyle(g.ink)
                                }
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
