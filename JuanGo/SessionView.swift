import SwiftUI
import SwiftData

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
                    rule("arrow.uturn.backward", "復原", "收回上一個答案。")
                }
                Section("選擇題與拼字") {
                    rule("questionmark.circle", "不知道", "直接看答案，算作不會；比用猜的更準。")
                    rule("lightbulb", "提示", "拼字時補上下一個字母。用了提示答對算不確定。")
                    rule("tortoise", "慢速再聽", "聽力題用較慢的速度再念一次。")
                    rule("exclamationmark.circle", "差一點", "拼錯一個字母算不確定，不算不會。")
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
