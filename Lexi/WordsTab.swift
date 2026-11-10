import SwiftUI
import SwiftData

enum WordSort: String, CaseIterable { case newest = "最新加入", oldest = "最早加入", alpha = "A → Z", level = "熟練度" }

struct WordsTab: View {
    @Environment(\.modelContext) private var ctx
    @Query private var words: [Word]
    @Query(sort: \WordList.createdAt) private var lists: [WordList]
    @State private var segment = 0
    @State private var search = ""
    @State private var sort = WordSort.newest
    @State private var addTerm = ""
    @State private var showAdd = false
    @State private var lookup: LookupTerm?
    @State private var selecting = false
    @State private var selection = Set<PersistentIdentifier>()
    @State private var newList = false
    @State private var newListName = ""
    @State private var showSettings = false
    @State private var moveSheet = false
    @State private var debugWord: Word?

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case 0: allWords
                case 1: myLists
                default: decks
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("顯示", selection: $segment.animation(.snappy)) {
                    Text("全部 \(words.count)").tag(0)
                    Text("清單").tag(1)
                    Text("內建字庫").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
            .navigationTitle("字庫")
            .themedBackground()
            .toolbar {
                ToolbarItemGroup {
                    if segment == 0 {
                        Menu {
                            Picker("排序", selection: $sort) { ForEach(WordSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        } label: { Label("排序", pulso: "arrow.up.arrow.down") }
                    }
                    Button("新增單字", pulso: "plus") { showAdd = true }
                    if segment == 0 {
                        Button(selecting ? "完成" : "選取", pulso: selecting ? "checkmark" : "checklist") {
                            selecting.toggle(); selection = []
                        }
                    }
                    Button("設定", pulso: "slider.horizontal.3") { showSettings = true }
                }
                if selecting && !selection.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("加入清單", pulso: "folder.badge.plus") { moveSheet = true }
                        Spacer()
                        Button("刪除 \(selection.count) 個", pulso: "trash", role: .destructive) { deleteSelected() }
                    }
                }
            }
            .navigationDestination(for: Word.self) { WordDetailView(word: $0) }
            .navigationDestination(item: $debugWord) { WordDetailView(word: $0) }
            .task {   // simulator testing: SIMCTL_CHILD_LEXI_WORD=reduce opens that word's page
                if let t = ProcessInfo.processInfo.environment["LEXI_WORD"] { debugWord = words.first { $0.term == t } }
            }
            .navigationDestination(for: ListRoute.self) { ListWordsView(route: $0) }
            .alert("新增單字", isPresented: $showAdd) {
                TextField("輸入英文單字", text: $addTerm).textInputAutocapitalization(.never)
                Button("查詢") { if !addTerm.isEmpty { lookup = LookupTerm(term: addTerm.lowercased()) }; addTerm = "" }
                Button("取消", role: .cancel) { addTerm = "" }
            }
            .alert("建立新清單", isPresented: $newList) {
                TextField("清單名稱", text: $newListName)
                Button("建立") {
                    let n = newListName.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { ctx.insert(WordList(name: n)); try? ctx.save() }
                    newListName = ""
                }
                Button("取消", role: .cancel) { newListName = "" }
            }
            .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $moveSheet) {
                AddToListSheet { list in
                    for w in words where selection.contains(w.persistentModelID) {
                        if let list { if !w.lists.contains(list) { w.lists.append(list) } } else { w.inMyWords = true }
                    }
                    try? ctx.save(); selecting = false; selection = []
                }
            }
        }
    }

    // MARK: segments

    private var filtered: [Word] {
        var ws = words
        if !search.isEmpty {
            ws = ws.filter { $0.term.localizedCaseInsensitiveContains(search) || $0.meanings.contains { $0.contains(search) } }
        }
        switch sort {
        case .newest: ws.sort { $0.addedAt > $1.addedAt }
        case .oldest: ws.sort { $0.addedAt < $1.addedAt }
        case .alpha: ws.sort { $0.term < $1.term }
        case .level: ws.sort { ($0.srsLevel, $0.term) < ($1.srsLevel, $1.term) }
        }
        return ws
    }

    private var allWords: some View {
        Group {
            if words.isEmpty {
                EmptyState("還沒有單字", icon: "character.book.closed", message: "到「新增」或「探索」收集第一個單字吧。")
                    .frame(maxHeight: .infinity)
            } else {
                List { Group {
                    if sort == .newest || sort == .oldest {
                        let groups = Swift.Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.addedAt) }
                        ForEach(groups.keys.sorted(by: sort == .newest ? (>) : (<)), id: \.self) { day in
                            Section {
                                ForEach(groups[day]!.sorted { sort == .newest ? $0.addedAt > $1.addedAt : $0.addedAt < $1.addedAt }) { row($0) }
                            } header: {
                                Text(dayLabel(day))
                            }
                        }
                    } else {
                        ForEach(filtered) { row($0) }
                    }
                }.listRowBackground(Color.cardFill) }.themedBackground()
                .listStyle(.insetGrouped)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋英文或中文")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        }
    }

    private func row(_ w: Word) -> some View {
        HStack {
            if selecting {
                LIcon(selection.contains(w.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(w.persistentModelID) ? Color.themeAccent : .secondary)
                    .onTapGesture { toggleSel(w) }
            }
            // Five-step level bar on the left edge.
            VStack(spacing: 2) {
                ForEach((1...5).reversed(), id: \.self) { k in
                    RoundedRectangle(cornerRadius: 1).fill(k <= w.srsLevel ? Color.themeAccent : Color.secondary.opacity(0.18)).frame(width: 4, height: 5)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(w.term).font(.system(.headline).weight(.bold))
                if AppSettings.shared.listShowMeaning {
                    Text(w.meaningLine).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { NavigationLink(value: w) { EmptyView() }.opacity(0).disabled(selecting) }
            if w.favorite { LIcon("heart.fill").font(.caption).foregroundStyle(Color.themeAccent) }
            Text(levelNames[max(0, min(5, w.srsLevel))]).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded { toggleSel(w) }, isEnabled: selecting)
        .swipeActions {
            Button("刪除", pulso: "trash", role: .destructive) { Library.remove(w, in: ctx) }
            Button(w.favorite ? "取消喜歡" : "喜歡", pulso: "heart") { w.favorite.toggle(); try? ctx.save() }.tint(.pink)
        }
    }

    private var myLists: some View {
        List { Group {
            Section {
                Button { newList = true } label: { Label("建立新清單", pulso: "plus.circle.fill").font(.headline) }
            }
            Section {
                NavigationLink(value: ListRoute.myWords) { listLabel("我的單字", "folder.fill", words.filter(\.inMyWords).count) }
                NavigationLink(value: ListRoute.favorites) { listLabel("喜歡", "heart.fill", words.filter(\.favorite).count) }
                ForEach(lists) { l in
                    NavigationLink(value: ListRoute.custom(l.persistentModelID)) { listLabel(l.name, "folder", l.words.count) }
                }
                .onDelete { idx in idx.map { lists[$0] }.forEach(ctx.delete); try? ctx.save() }
            }
        }.listRowBackground(Color.cardFill) }.themedBackground()
        .listStyle(.insetGrouped)
    }

    private var decks: some View {
        List { Group {
            Section("大考詞彙") { deckLinks(Deck.examDecks) }
            Section("國中小・檢定考試") { deckLinks(Deck.testDecks) }
            Section("依等級") {
                ForEach(examLevels, id: \.self) { lv in
                    NavigationLink(value: ListRoute.level(lv)) { listLabel(levelLabel(lv), "chart.bar.fill", Dictionary_.entries(level: lv).count) }
                }
            }
        }.listRowBackground(Color.cardFill) }.themedBackground()
        .listStyle(.insetGrouped)
    }

    private func deckLinks(_ decks: [Deck]) -> some View {
        ForEach(decks) { d in
            NavigationLink(value: ListRoute.deck(d.rawValue)) {
                VStack(alignment: .leading) {
                    Text(d.rawValue).font(.headline)
                    Text("\(Dictionary_.all.filter(d.contains).count) 個單字・\(d.subtitle)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func listLabel(_ name: String, _ icon: String, _ n: Int) -> some View {
        LabeledContent { Text("\(n)") } label: { Label(name, pulso: icon) }
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "今天" }
        if cal.isDateInYesterday(d) { return "昨天" }
        return d.formatted(.dateTime.month().day().locale(.zh))
    }

    private func toggleSel(_ w: Word) {
        if selection.contains(w.persistentModelID) { selection.remove(w.persistentModelID) } else { selection.insert(w.persistentModelID) }
    }

    private func deleteSelected() {
        for w in words where selection.contains(w.persistentModelID) { ctx.delete(w) }
        try? ctx.save(); selection = []; selecting = false
    }
}

enum ListRoute: Hashable {
    case myWords, favorites, custom(PersistentIdentifier), deck(String), level(String)
}

struct ListWordsView: View {
    let route: ListRoute
    @Environment(\.modelContext) private var ctx
    @Query private var words: [Word]
    @State private var lookup: LookupTerm?

    var body: some View {
        List { Group {
            switch route {
            case .deck, .level:
                ForEach(entries) { e in
                    let saved = words.contains { $0.term == e.w }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(e.w).font(.headline)
                            Text("\(e.pos) \(e.zh.joined(separator: "・"))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(levelLabel(e.lv)).font(.caption.bold()).foregroundStyle(.secondary)
                        Button { if !saved { Library.add(e, in: ctx) } } label: {
                            LIcon(saved ? "checkmark.circle.fill" : "plus.circle.fill").font(.title2)
                        }.buttonStyle(.plain).foregroundStyle(saved ? Color.green : .themeAccent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { lookup = LookupTerm(term: e.w) }
                }
            default:
                if routeWords.isEmpty { EmptyState("清單是空的", icon: "tray") }
                ForEach(routeWords) { w in
                    NavigationLink(value: w) {
                        VStack(alignment: .leading) {
                            Text(w.term).font(.headline)
                            Text(w.meaningLine).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions { Button("移出清單", role: .destructive) { removeFromRoute(w) } }
                }
            }
        }.listRowBackground(Color.cardFill) }
        .navigationTitle(title)
        .themedBackground()
        .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
    }

    private var title: String {
        switch route {
        case .myWords: "我的單字"
        case .favorites: "喜歡"
        case .custom(let id): (ctx.model(for: id) as? WordList)?.name ?? "清單"
        case .deck(let d): d
        case .level(let lv): "大考詞彙\(levelLabel(lv))"
        }
    }
    private var entries: [DictEntry] {
        switch route {
        case .deck(let d): Dictionary_.all.filter((Deck(rawValue: d) ?? .basic).contains)
        case .level(let lv): Dictionary_.entries(level: lv)
        default: []
        }
    }
    private var routeWords: [Word] {
        switch route {
        case .myWords: words.filter(\.inMyWords).sorted { $0.addedAt > $1.addedAt }
        case .favorites: words.filter(\.favorite)
        case .custom(let id): (ctx.model(for: id) as? WordList)?.words.sorted { $0.term < $1.term } ?? []
        default: []
        }
    }
    private func removeFromRoute(_ w: Word) {
        switch route {
        case .myWords: w.inMyWords = false
        case .favorites: w.favorite = false
        case .custom(let id): w.lists.removeAll { $0.persistentModelID == id }
        default: break
        }
        try? ctx.save()
    }
}

// MARK: - Word detail

struct WordDetailView: View {
    @Bindable var word: Word
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var library: [Word]
    @State private var showTranslation = true
    @State private var lookup: LookupTerm?
    @State private var showLists = false
    @State private var editing = false
    @State private var confirmDelete = false

    private var related: [DictEntry] {
        let saved = Set(library.map(\.term))
        return Array(Dictionary_.entries(level: word.cefr).filter { $0.w != word.term && !saved.contains($0.w) }.shuffled().prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Dictionary-style header: headword, pronunciation, tags, then numbered meanings.
                VStack(alignment: .leading, spacing: 10) {
                    Text(word.term).font(.system(size: 42, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    HStack(spacing: 8) {
                        SpeakButton(text: word.term)
                        if !word.ipa.isEmpty { Text("/\(word.ipa)/").foregroundStyle(.secondary) }
                    }.font(.subheadline)
                    HStack(spacing: 6) {
                        if !word.pos.isEmpty { detailTag(word.pos) }
                        detailTag(levelLabel(cefrToExam[word.cefr] ?? word.cefr))
                        detailTag(levelNames[max(0, min(5, word.srsLevel))])
                    }
                    Divider().padding(.vertical, 4)
                    ForEach(Array(word.meanings.enumerated()), id: \.offset) { k, m in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(k + 1)").font(.caption.weight(.bold)).foregroundStyle(.tint).frame(width: 14)
                            Text(m).font(k == 0 ? .title3.weight(.bold) : .body)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                if !word.example.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("例句").font(.system(.subheadline).weight(.bold))
                            Spacer()
                            Button { withAnimation { showTranslation.toggle() } } label: {
                                Label("翻譯", pulso: showTranslation ? "chevron.up" : "chevron.down").font(.caption.bold())
                            }.foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            TappableSentence(sentence: word.example, highlight: word.term, font: .callout.weight(.semibold)) { lookup = LookupTerm(term: $0) }
                            if showTranslation { Text(word.exampleZh).font(.footnote.weight(.semibold)).foregroundStyle(.secondary) }
                        }.card()
                    }
                }
                if !synonyms.isEmpty { wordGrid("同義字", synonyms) }
                if !related.isEmpty { wordGrid("相同程度", related) }
                if !word.definition.isEmpty {
                    section("英文解釋") { Text(word.definition).font(.body) }
                }
                section("學習狀態") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("加入日期", value: word.addedAt.formatted(.dateTime.year().month().day().locale(.zh)))
                        LabeledContent("複習次數", value: "\(word.reviewCount)")
                        if let due = word.dueDate { LabeledContent("下次複習", value: due <= .now ? "已到期" : due.formatted(.relative(presentation: .named).locale(.zh))) }
                        if !word.lists.isEmpty { LabeledContent("清單", value: word.lists.map(\.name).joined(separator: "、")) }
                    }.font(.subheadline)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 30)
        }
        .themedBackground()
        .onAppear { if AppSettings.shared.detailAutoSpeak { Speech.say(word.term) } }
        .toolbar {
            ToolbarItemGroup {
                Button("加入清單", pulso: "folder") { showLists = true }
                Button("喜歡", pulso: word.favorite ? "heart.fill" : "heart") { word.favorite.toggle(); try? ctx.save() }
                    .tint(word.favorite ? .pink : nil)
                Menu {
                    Button("編輯詳細資料", pulso: "square.and.pencil") { editing = true }
                    Button("重設學習進度", pulso: "arrow.counterclockwise") {
                        word.srsLevel = 0; word.dueDate = nil; word.reviewCount = 0; try? ctx.save()
                    }
                    Button("刪除單字", pulso: "trash", role: .destructive) { confirmDelete = true }
                } label: { LIcon("ellipsis") }
            }
        }
        .sheet(item: $lookup) { WordConfirmSheet(term: $0.term) }
        .sheet(isPresented: $showLists) {
            AddToListSheet { list in
                if let list { if !word.lists.contains(list) { word.lists.append(list) } } else { word.inMyWords = true }
                try? ctx.save()
            }
        }
        .sheet(isPresented: $editing) {
            EditWordSheet(entry: DictEntry(w: word.term, ipa: word.ipa, pos: word.pos,
                                           zh: Array(Set(word.meanings + (Dictionary_.lookup(word.term)?.zh ?? []))).sorted { a, b in
                                               (word.meanings.firstIndex(of: a) ?? 99) < (word.meanings.firstIndex(of: b) ?? 99) },
                                           def: word.definition, ex: word.example, exZh: word.exampleZh, lv: word.cefr),
                          selected: word.meanings) { e, m in
                word.ipa = e.ipa; word.pos = e.pos; word.meanings = m; word.definition = e.def
                word.example = e.ex; word.exampleZh = e.exZh
                try? ctx.save()
            }
        }
        .confirmationDialog("刪除「\(word.term)」？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("刪除", role: .destructive) { dismiss(); Library.remove(word, in: ctx) }
        } message: { Text("學習紀錄也會一併移除。") }
    }

    private var synonyms: [DictEntry] {
        Dictionary_.synonyms(of: word.term, meanings: Dictionary_.lookup(word.term)?.zh ?? word.meanings, pos: word.pos, limit: 3)
    }

    /// Related words as a wrap of tappable chips; the + adds one straight to 我的單字.
    private func wordGrid(_ title: String, _ entries: [DictEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.subheadline).weight(.bold))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(entries) { e in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.w).font(.subheadline.weight(.bold))
                            Text(e.zh.first ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Button { Library.add(e, in: ctx) } label: { LIcon("plus").font(.caption.bold()) }
                            .buttonStyle(.plain).foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.cardFill))
                    .onTapGesture { lookup = LookupTerm(term: e.w) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.subheadline).weight(.bold))
            content().card()
        }
    }

    private func detailTag(_ t: String) -> some View {
        Text(t).font(.caption.weight(.bold)).foregroundStyle(.tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color.themeAccent.opacity(0.1)))
    }
}
