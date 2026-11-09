import SwiftUI
import SwiftData

struct ProfileTab: View {
    @Query private var words: [Word]
    @Query(sort: \ReviewLog.date) private var logs: [ReviewLog]
    @State private var selectedDay: Date?
    @State private var showSettings = false

    private var stats: Stats { Stats(logs: logs, words: words) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    streakCard
                    statGrid
                    calendarCard
                    badgesCard
                    MasteryCard(distribution: stats.distribution)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .navigationTitle("我的")
            .themedBackground()
            .toolbar { ToolbarItem { Button("設定", pulso: "slider.horizontal.3") { showSettings = true } } }
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            .task { if ProcessInfo.processInfo.environment["LEXI_SETTINGS"] != nil { showSettings = true } }   // simulator testing
            #endif
        }
    }

    /// Streak up front, drawn in the flame colour.
    private var streakCard: some View {
        HStack(spacing: 16) {
            LIcon("flame.fill").font(.system(size: 40))
                .foregroundStyle(Color.themeAccent)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.themeAccent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(stats.streak)").font(.system(size: 40, weight: .bold))
                    Text("天連續學習").font(.headline)
                }
                Text(stats.studiedToday > 0 ? "今天已經練過了，明天見！" : "今天還沒練習，別讓火熄掉。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile("今天練習", stats.studiedToday, "checklist")
                statTile("學過的字", stats.learnedTotal, "book.pages")
            }
            HStack(spacing: 12) {
                statTile("精通", stats.masteredTotal, "crown")
                statTile("待複習", stats.dueCount, "arrow.triangle.2.circlepath")
            }
        }
    }

    private func statTile(_ title: String, _ n: Int, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LIcon(icon).font(.headline).foregroundStyle(.tint)
            Text("\(n)").font(.system(.title).weight(.bold)).contentTransition(.numericText())
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    /// The last five weeks as a calendar grid; darker squares mean more words that day.
    private var calendarCard: some View {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: .now)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let first = cal.date(byAdding: .day, value: -28, to: weekStart)!
        let days = (0..<35).map { cal.date(byAdding: .day, value: $0, to: first)! }
        let counts = days.map { stats.count(on: $0) }
        let top = max(1, counts.max() ?? 1)
        let chosen = selectedDay ?? today
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("學習日曆").font(.system(.headline).weight(.bold))
                Spacer()
                Text("近 5 週・\(counts.filter { $0 > 0 }.count) 天有練習").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                        Text($0).font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<5, id: \.self) { week in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { wd in
                            let k = week * 7 + wd, d = days[k], n = counts[k], future = d > today
                            Button { selectedDay = d } label: {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(future ? Color.clear : n == 0 ? Color.secondary.opacity(0.10) : Color.themeAccent.opacity(0.25 + 0.75 * Double(n) / Double(top)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                        .strokeBorder(cal.isDate(d, inSameDayAs: chosen) ? Color.primary : (future ? Color.hairline : .clear), lineWidth: 1.5))
                                    .overlay {
                                        Text(d.formatted(.dateTime.day())).font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(n > 0 && Double(n) / Double(top) > 0.4 ? Color.onAccent : Color.secondary)
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(future)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            HStack {
                Text(chosen.formatted(.dateTime.month().day().weekday().locale(.zh)))
                Spacer()
                Text("練了 \(stats.count(on: chosen)) 個字").fontWeight(.bold)
            }
            .font(.subheadline)
        }
        .card()
    }

    private var badgesCard: some View {
        let earned = BadgeKind.all.map { $0.earned(for: BadgeKind.value($0.id, stats: stats)) }.reduce(0, +)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("成就").font(.system(.headline).weight(.bold))
                Spacer()
                Text("已解鎖 \(earned) 枚").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top) {
                ForEach(BadgeKind.all) { k in
                    BadgeMedal(kind: k, value: BadgeKind.value(k.id, stats: stats), size: 56).frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmWipe = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("學習") {
                    NavigationLink {
                        Form {
                            Section("每日新字") {
                                Stepper("\(settings.dailyGoal) 個 / 天", value: $settings.dailyGoal, in: 1...100)
                            }
                            Section("單字程度") {
                                Picker("程度", selection: $settings.level) {
                                    ForEach(examLevels, id: \.self) { Text("\(levelLabel($0))・\(LevelTest.blurb($0))").tag($0) }
                                }.pickerStyle(.inline).labelsHidden()
                            }
                        }.navigationTitle("學習目標")
                    } label: { row("smallcircle.filled.circle", "學習目標", "每日新字與單字程度") }
                    NavigationLink {
                        Form {
                            Toggle("顯示例句翻譯", isOn: $settings.showTranslation)
                            Toggle("自動發音", isOn: Binding(get: { !settings.muted }, set: { settings.muted = !$0 }))
                            Toggle("震動回饋", isOn: $settings.haptics)
                            VStack(alignment: .leading) {
                                Text("發音速度")
                                Slider(value: $settings.speechRate, in: 0.3...0.6) { Text("速度") } minimumValueLabel: { LIcon("tortoise") } maximumValueLabel: { LIcon("hare") }
                            }
                            Button("試聽") { Speech.say("resilient") }
                            Button("重新顯示學習規則與探索教學") { settings.studyRulesSeen = false; settings.exploreTipsDone = false }
                        }.navigationTitle("練習")
                    } label: { row("graduationcap.fill", "練習", "例句翻譯、發音與震動") }
                    NavigationLink {
                        Form {
                            Toggle("每日提醒", isOn: $settings.reminderOn)
                            if settings.reminderOn {
                                DatePicker("提醒時間", selection: $settings.reminderDate, displayedComponents: .hourAndMinute)
                            }
                        }.navigationTitle("提醒與通知")
                    } label: { row("bell.fill", "提醒與通知", settings.reminderOn ? "每天 \(settings.reminderText)" : "關閉") }
                }
                Section("單字與探索") {
                    NavigationLink {
                        Form { Toggle("在列表顯示中文意思", isOn: $settings.listShowMeaning) }.navigationTitle("單字列表")
                    } label: { row("list.bullet.rectangle.fill", "單字列表", "單字清單的中文意思") }
                    NavigationLink {
                        Form { Toggle("打開單字頁時自動發音", isOn: $settings.detailAutoSpeak) }.navigationTitle("單字詳情")
                    } label: { row("book.closed.fill", "單字詳情", "完整單字頁的自動發音") }
                    NavigationLink {
                        Form {
                            Toggle("顯示音標", isOn: $settings.exploreShowIPA)
                            Toggle("顯示例句翻譯", isOn: $settings.showTranslation)
                        }.navigationTitle("探索")
                    } label: { row("safari.fill", "探索", "探索卡片的音標與例句翻譯") }
                }
                Section("外觀") {
                    Picker("外觀", selection: $settings.appearance) { Text("跟隨系統").tag(0); Text("淺色").tag(1); Text("深色").tag(2) }
                    Picker("字體", selection: $settings.fontStyle) {
                        Text("系統").tag(0); Text("圓體").tag(1); Text("襯線").tag(2); Text("等寬").tag(3)
                    }
                    ThemeGrid(selection: $settings.themeID).padding(.vertical, 6)
                }
                Section("資料") {
                    Button("重設所有學習進度") { confirmReset = true }
                    Button("清除所有單字與紀錄", role: .destructive) { confirmWipe = true }
                    Button("重新進行新手導覽") { settings.onboarded = false; dismiss() }
                }
                Section {
                    LabeledContent("字典", value: "\(Dictionary_.all.count) 個內建單字")
                    LabeledContent("版本", value: "1.3")
                } footer: {
                    Text("詞彙與分級：大學入學考試中心《高中英文參考詞彙表》（111 學年度起適用），僅供非營利學習使用。中文解釋與音標整理自 ECDICT（MIT 授權），內容可能有誤，可在單字頁自行編輯。所有學習資料只存在這台裝置上。")
                }
            }
            .navigationTitle("設定")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { dismiss() } } }
            .confirmationDialog("重設所有學習進度？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("重設", role: .destructive) { resetProgress() }
            } message: { Text("單字會保留，但熟練度和學習紀錄會歸零。") }
            .confirmationDialog("清除所有單字與紀錄？", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("全部清除", role: .destructive) { wipe() }
            } message: { Text("這個動作無法復原。") }
        }
    }

    private func row(_ icon: String, _ title: String, _ sub: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(sub).font(.footnote.weight(.semibold)).foregroundStyle(.secondary) }
        } icon: {
            LIcon(icon).font(.subheadline.weight(.semibold)).foregroundStyle(Color.onAccent)
                .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(Color.themeAccent))
        }
        .padding(.vertical, 4)
    }

    private func resetProgress() {
        for w in (try? ctx.fetch(FetchDescriptor<Word>())) ?? [] { w.srsLevel = 0; w.dueDate = nil; w.lastReviewed = nil; w.reviewCount = 0 }
        try? ctx.delete(model: ReviewLog.self)
        try? ctx.save()
    }

    private func wipe() {
        try? ctx.delete(model: ReviewLog.self)
        try? ctx.delete(model: Word.self)
        try? ctx.delete(model: WordList.self)
        try? ctx.save()
    }
}
