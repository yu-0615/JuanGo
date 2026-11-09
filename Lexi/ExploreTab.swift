import SwiftUI
import SwiftData

struct ExploreTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @Query private var saved: [Word]

    @State private var deck: Deck = .recommended
    @State private var levels: Set<String> = []
    @State private var posFilter: String?
    @State private var feed: [DictEntry] = []
    @State private var current: String?
    @State private var lookup: LookupTerm?
    @State private var listTarget: DictEntry?
    @State private var showSettings = false
    @State private var tipStep = 0

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            // Lexi deals the words as a horizontal deck: swipe sideways, with the neighbours peeking in.
            VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(feed) { e in
                        ExploreCard(entry: e, isSaved: isSaved(e),
                                    onToggle: { toggle(e) },
                                    onList: { listTarget = e },
                                    onLookup: { lookup = LookupTerm(term: $0) })
                            .containerRelativeFrame(.horizontal)
                            .id(e.w)
                    }
                    if feed.isEmpty {
                        EmptyState("沒有符合的單字", icon: "line.3.horizontal.decrease.circle", message: "調整篩選條件或換一個字庫。")
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 28, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            if let i = feed.firstIndex(where: { $0.w == current }) {
                Text("\(i + 1) / \(feed.count)").font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(.secondary)
            }
            }
            .padding(.top, 6).padding(.bottom, 14)
            .navigationTitle(deck.rawValue).navigationBarTitleDisplayMode(.inline)
            .themedBackground()
            .overlay(alignment: .top) { if !settings.exploreTipsDone && !feed.isEmpty { tipBanner } }
            .toolbar {
                ToolbarItem(placement: .principal) { deckMenu }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(settings.muted ? "取消靜音" : "靜音", pulso: settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                        settings.muted.toggle()
                    }
                    filterMenu
                    Button("設定", pulso: "slider.horizontal.3") { showSettings = true }
                }
            }
            .onAppear { if feed.isEmpty { rebuild() } }
            .onChange(of: deck) { rebuild() }
            .onChange(of: levels) { rebuild() }
            .onChange(of: posFilter) { rebuild() }
            .onChange(of: current) { old, new in
                if let new, !settings.muted { Speech.say(new) }
                if old != nil, tipStep == 0 { tipStep = 1 }
                if let i = feed.firstIndex(where: { $0.w == new }) {
                    for e in feed.dropFirst(i + 1).prefix(2) { ExampleStore.shared.request(e) }
                }
            }
            .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
            .sheet(item: $listTarget) { e in AddToListSheet { list in Library.add(e, to: list, myWords: list == nil || isSaved(e), in: ctx) } }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var deckMenu: some View {
        Menu {
            ForEach(Deck.allCases) { d in
                Button { deck = d } label: {
                    if deck == d { Label(d.rawValue, pulso: "checkmark") } else { Text(d.rawValue) }
                    Text("\(Dictionary_.all.filter(d.contains).count) 個單字・\(d.subtitle)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(deck.rawValue).font(.system(.headline, design: .serif).weight(.bold))
                LIcon("chevron.up.chevron.down").font(.caption.bold()).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .tint(.primary)
    }

    private var filterMenu: some View {
        Menu {
            Menu("等級") {
                ForEach(examLevels, id: \.self) { lv in
                    Button { if levels.contains(lv) { levels.remove(lv) } else { levels.insert(lv) } } label: {
                        if levels.contains(lv) { Label(levelLabel(lv), pulso: "checkmark") } else { Text(levelLabel(lv)) }
                    }
                }
            }
            Menu("詞性") {
                ForEach([("n.", "名詞"), ("v.", "動詞"), ("adj.", "形容詞"), ("adv.", "副詞")], id: \.0) { p, name in
                    Button { posFilter = posFilter == p ? nil : p } label: {
                        if posFilter == p { Label(name, pulso: "checkmark") } else { Text(name) }
                    }
                }
            }
            if !levels.isEmpty || posFilter != nil { Button("清除篩選", role: .destructive) { levels = []; posFilter = nil } }
        } label: {
            LIcon(levels.isEmpty && posFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private var tipBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tipStep == 0 ? "往左滑，看下一張" : "點兩下卡片，收進我的單字").font(.subheadline.bold())
                Text("\(tipStep + 1) / 2・自己試一次就到下一步").font(.caption).opacity(0.7)
            }
            Spacer()
            Button(tipStep == 0 ? "略過" : "完成") { withAnimation { settings.exploreTipsDone = true } }
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14))
        }
        .foregroundStyle(Color.onAccent)
        .tint(Color.onAccent.opacity(0.25))
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.themeAccent))
        .padding(.horizontal, 18).padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func isSaved(_ e: DictEntry) -> Bool { saved.contains { $0.term == e.w && $0.inMyWords } }

    private func toggle(_ e: DictEntry) {
        if let w = Library.word(e.w, in: ctx), w.inMyWords {
            if w.lists.isEmpty && !w.favorite { Library.remove(w, in: ctx) } else { w.inMyWords = false; try? ctx.save() }
        } else {
            Library.add(e, in: ctx)
            if tipStep == 1 { withAnimation { settings.exploreTipsDone = true } }
        }
    }

    private func rebuild() {
        var pool = Dictionary_.all.filter(deck.contains)
        if !levels.isEmpty { pool = pool.filter { levels.contains($0.lv) } }
        if let posFilter { pool = pool.filter { $0.posTags.contains(posFilter) } }
        if deck == .recommended && levels.isEmpty {
            let i = examLevels.firstIndex(of: settings.level) ?? 2
            let near = Set(examLevels[max(0, i - 1)...min(examLevels.count - 1, i + 1)])
            let savedTerms = Set(saved.map(\.term))
            pool = pool.filter { near.contains($0.lv) && !savedTerms.contains($0.w) }.shuffled()
                + pool.filter { !near.contains($0.lv) }.shuffled()
        } else {
            pool.shuffle()
        }
        feed = pool
        current = pool.first?.w
    }
}

struct ExploreCard: View {
    let entry: DictEntry
    let isSaved: Bool
    var onToggle: () -> Void
    var onList: () -> Void
    var onLookup: (String) -> Void
    @Environment(AppSettings.self) private var settings
    @State private var pop = false
    private var examples: ExampleStore { .shared }

    /// A dictionary-entry card: level and part of speech on top, a serif headword, meanings, then the example in a quote block.
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                tag(levelLabel(entry.lv), filled: true)
                if !entry.pos.isEmpty { tag(entry.pos, filled: false) }
                Spacer()
                if isSaved { Label("已收藏", pulso: "bookmark.fill").font(.caption.weight(.bold)).foregroundStyle(.tint) }
            }
            Spacer(minLength: 0)
            Text(entry.w).font(.system(size: 44, weight: .bold, design: .serif)).minimumScaleFactor(0.5).lineLimit(1)
            HStack(spacing: 8) {
                SpeakButton(text: entry.w)
                if settings.exploreShowIPA && !entry.ipa.isEmpty { Text("/\(entry.ipa)/").foregroundStyle(.secondary) }
            }
            .font(.subheadline)
            Text(entry.zh.prefix(3).joined(separator: "；")).font(.title2.weight(.bold)).lineLimit(2)
            VStack(alignment: .leading, spacing: 6) {
                if let ex = examples.example(for: entry) {
                    TappableSentence(sentence: ex.en, highlight: entry.w, font: .body.weight(.medium), onTap: onLookup)
                    if settings.showTranslation { Text(ex.zh).font(.subheadline).foregroundStyle(.secondary) }
                } else if examples.isGenerating(entry) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The teacher discussed the issue of recycling with the whole class.")
                        Text("老師與全班同學討論了回收的問題。").font(.subheadline)
                    }
                    .redacted(reason: .placeholder)
                    .phaseAnimator([0.35, 0.8]) { v, p in v.opacity(p) } animation: { _ in .easeInOut(duration: 0.8) }
                } else if !entry.def.isEmpty {
                    TappableSentence(sentence: entry.def, highlight: "", font: .subheadline, onTap: onLookup)
                        .foregroundStyle(.secondary)
                }
                if let alt = entry.alt, !alt.isEmpty {
                    Text("也寫作：\(alt.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeAccent.opacity(0.06)))
            .overlay(alignment: .leading) { Rectangle().fill(Color.themeAccent).frame(width: 3).padding(.vertical, 8) }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button(action: onList) { LIcon("folder.badge.plus").font(.title3) }
                    .buttonStyle(PillButtonStyle(fill: .themeAccent.opacity(0.1), foreground: .themeAccent, height: 52))
                    .frame(width: 64)
                Button(action: onToggle) {
                    Label(isSaved ? "從我的單字移除" : "收進我的單字", pulso: isSaved ? "bookmark.slash" : "bookmark.fill")
                }
                .buttonStyle(PillButtonStyle(fill: isSaved ? .secondary.opacity(0.15) : .themeAccent, foreground: isSaved ? .primary : .onAccent, height: 52))
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.hairline))
        .overlay {
            LIcon("bookmark.fill").font(.system(size: 80)).foregroundStyle(Color.themeAccent)
                .scaleEffect(pop ? 1.1 : 0.4).opacity(pop ? 0.9 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !isSaved { onToggle() }
            withAnimation(.spring(duration: 0.3)) { pop = true }
            Task { try? await Task.sleep(for: .seconds(0.6)); withAnimation { pop = false } }
        }
        .sensoryFeedback(.success, trigger: isSaved) { _, new in new && settings.haptics }
        .task(id: entry.w) { examples.request(entry, urgent: true) }
    }

    private func tag(_ t: String, filled: Bool) -> some View {
        Text(t).font(.caption.weight(.bold))
            .foregroundStyle(filled ? Color.onAccent : Color.themeAccent)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(filled ? Color.themeAccent : Color.themeAccent.opacity(0.1)))
    }
}
