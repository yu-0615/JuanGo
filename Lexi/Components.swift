import SwiftUI
import SwiftData
import Translation

// MARK: - Flow layout for tappable sentences

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW + 0.5 { y += lineH + lineSpacing; x = 0; lineH = 0 }
            x += s.width + spacing
            lineH = max(lineH, s.height)
            widest = max(widest, x - spacing)
        }
        // Take the whole offered width: returning exactly the widest line made placement (which compares
        // against these bounds) wrap a chip that measured as fitting, drawing it over the next section.
        return CGSize(width: proposal.width ?? widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX + 0.5 { y += lineH + lineSpacing; x = bounds.minX; lineH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}

/// An example sentence where every English word can be tapped to look it up.
struct TappableSentence: View {
    let sentence: String
    var highlight: String = ""
    var font: Font = .title3.weight(.semibold)
    var onTap: (String) -> Void

    private var tokens: [(id: Int, text: String, word: String)] {
        sentence.split(separator: " ").enumerated().map { i, raw in
            let text = String(raw)
            let word = text.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            return (i, text, word)
        }
    }

    // One wrapping Text with a link per word: native line breaking keeps the measured
    // height right (a custom flow layout overlapped the translation below it).
    var body: some View {
        Text(attributed)
            .font(font)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if let i = Int(url.lastPathComponent), tokens.indices.contains(i) { onTap(tokens[i].word) }
                return .handled
            })
    }

    private var attributed: AttributedString {
        var out = AttributedString()
        for (i, t) in tokens.enumerated() {
            if i > 0 { out += AttributedString(" ") }
            let isKey = !highlight.isEmpty && t.word.lowercased().hasPrefix(highlight.lowercased())
            var run = AttributedString(t.text)
            if !t.word.isEmpty { run.link = URL(string: "lexi://word/\(i)") }
            run[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = .themeAccent
            run[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] =
                Text.LineStyle(pattern: isKey ? .solid : .dot, color: .themeAccent.opacity(isKey ? 0.9 : 0.35))
            if isKey { run.inlinePresentationIntent = .stronglyEmphasized }
            out += run
        }
        return out
    }
}

struct SpeakButton: View {
    let text: String
    var body: some View {
        Button { Speech.say(text) } label: { LIcon("speaker.wave.2.fill") }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

struct Toast: View {
    let text: String
    var action: (() -> Void)?
    var onClose: () -> Void
    var body: some View {
        HStack {
            LIcon("checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            Button { action?() } label: {
                HStack(spacing: 4) { Text(text); if action != nil { LIcon("chevron.right") } }
                    .font(.subheadline.bold()).foregroundStyle(.tint)
            }.buttonStyle(.plain)
            Spacer()
            Button(action: onClose) { LIcon("xmark").font(.subheadline.bold()) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Identifiable wrapper so a looked-up term can drive `.sheet(item:)`.
struct LookupTerm: Identifiable { let term: String; var id: String { term } }

// MARK: - Confirm word sheet

/// "確認單字": shows a term with IPA and meanings; add to My Words / another list / edit details.
struct WordConfirmSheet: View {
    let term: String
    var destination: WordList? = nil
    var onAdded: ((Word) -> Void)? = nil

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var entry: DictEntry?
    @State private var chosen: [String] = []
    @State private var translating = false
    @State private var config: TranslationSession.Configuration?
    @State private var aiSource: String?
    @State private var showLists = false
    @State private var showEdit = false
    @State private var saved: Word?

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("確認單字").font(.headline)
                Spacer()
                Button { dismiss() } label: { GlassCircleIcon(systemName: "xmark") }
                    .buttonStyle(.glass).buttonBorderShape(.circle)
            }
            Text(entry?.w ?? term).font(.system(size: 40, weight: .semibold)).minimumScaleFactor(0.5).lineLimit(1)
            HStack(spacing: 10) {
                if let ipa = entry?.ipa, !ipa.isEmpty { Text("[\(ipa)]").foregroundStyle(.secondary) }
                SpeakButton(text: entry?.w ?? term)
            }
            meaningPicker
            if let aiSource, !translating {
                Text("由 \(aiSource) 翻譯，可能有誤").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if let saved, saved.inMyWords {
                Button { removeFromMyWords(saved) } label: { Text("取消加入") }
                    .buttonStyle(PillButtonStyle())
            } else {
                Button { add(myWords: true) } label: { Text(destination.map { "加入「\($0.name)」" } ?? "加入我的單字") }
                    .buttonStyle(PillButtonStyle(fill: .themeAccent, foreground: .onAccent, glass: true))
                    .disabled(entry == nil || translating)
            }
            Button { showLists = true } label: { Label("加入其他清單", pulso: "folder.badge.plus") }
                .buttonStyle(PillButtonStyle())
                .disabled(entry == nil)
            Button { showEdit = true } label: { Label("編輯詳細資料", pulso: "square.and.pencil") }
                .buttonStyle(PillButtonStyle(foreground: .secondary))
                .disabled(entry == nil)
        }
        .padding(22)
        .presentationDetents([.height(500), .large])
        .presentationBackground(.regularMaterial)
        .task { await load() }
        .translationTask(config) { session in
            defer { translating = false }
            guard let r = try? await session.translate(term) else { return }
            let m = r.targetText.trimmingCharacters(in: .whitespaces)
            entry = .custom(term, meaning: m)
            chosen = m.isEmpty ? [] : [m]
        }
        .sheet(isPresented: $showLists) {
            AddToListSheet { list in
                if let entry { saved = Library.add(entry, meanings: chosen, to: list, myWords: saved?.inMyWords ?? false, in: ctx) }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let entry {
                EditWordSheet(entry: entry, selected: chosen) { e, m in
                    self.entry = e; chosen = m
                }
            }
        }
    }

    @ViewBuilder private var meaningPicker: some View {
        if translating {
            ProgressView("正在翻譯…")
        } else if let entry, !entry.pos.isEmpty, entry.zh.count <= 1, let m = chosen.first {
            Text("\(entry.pos) \(m)").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
        } else if let entry, entry.zh.count > 1 {
            Menu {
                ForEach(entry.zh, id: \.self) { m in
                    Button { chosen = [m] + entry.zh.filter { $0 != m } } label: {
                        if chosen.first == m { Label(m, pulso: "checkmark") } else { Text(m) }
                    }
                }
                Button("選擇多個意思…") { showEdit = true }
            } label: {
                HStack(spacing: 4) { Text((aiSource != nil && !entry.pos.isEmpty ? entry.pos + " " : "") + (chosen.first ?? entry.zh[0])); LIcon("chevron.up.chevron.down").font(.caption) }
                    .font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
        } else {
            Text(chosen.first ?? "找不到解釋，可以自己編輯")
                .font(.title3.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func load() async {
        saved = Library.word(term, in: ctx)
        if let saved {
            entry = DictEntry(w: saved.term, ipa: saved.ipa, pos: saved.pos, zh: saved.meanings, def: saved.definition,
                              ex: saved.example, exZh: saved.exampleZh, lv: saved.cefr)
            chosen = saved.meanings
        } else if let e = Dictionary_.lookup(term) {
            entry = e; chosen = e.zh
        } else {
            entry = .custom(term, meaning: "")
            translating = true
            // AI (the user's API / Apple Intelligence, when turned on) gives part of speech + several meanings; Apple Translation is the fallback
            let translator = WordTranslator.shared
            let source = translator.cached(term) == nil ? translator.providerName : "AI"
            if let r = await translator.translate(term) {
                entry = r.entry(for: term); chosen = r.meanings; aiSource = source
                translating = false
            } else {
                config = .init(source: .init(identifier: "en"), target: .init(identifier: "zh-Hant"))
            }
        }
    }

    private func add(myWords: Bool) {
        guard let entry else { return }
        let w = Library.add(entry, meanings: chosen, to: destination, myWords: myWords, in: ctx)
        saved = w
        onAdded?(w)
        dismiss()
    }

    private func removeFromMyWords(_ w: Word) {
        if w.lists.isEmpty && !w.favorite { Library.remove(w, in: ctx); saved = nil } else { w.inMyWords = false; try? ctx.save() }
    }
}

// MARK: - Add to list sheet

struct AddToListSheet: View {
    var onPick: (WordList?) -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WordList.createdAt) private var lists: [WordList]
    @State private var newName = ""
    @State private var creating = false
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List { Group {
                Section {
                    Button { creating = true } label: { Label("建立新清單", pulso: "plus.circle.fill").font(.headline) }
                }
                Section {
                    Button { onPick(nil); dismiss() } label: { Label("我的單字", pulso: "folder.fill") }
                    ForEach(lists.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { l in
                        Button { onPick(l); dismiss() } label: {
                            LabeledContent { Text("\(l.words.count)") } label: { Label(l.name, pulso: "folder") }
                        }
                    }
                    .onDelete { idx in idx.map { lists[$0] }.forEach(ctx.delete); try? ctx.save() }
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .foregroundStyle(.primary)
            .searchable(text: $search, placement: .navigationBarDrawer, prompt: "搜尋清單")
            .navigationTitle("加入其他清單")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", pulso: "xmark") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .alert("建立新清單", isPresented: $creating) {
                TextField("清單名稱", text: $newName)
                Button("建立") {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { ctx.insert(WordList(name: n)); try? ctx.save() }
                    newName = ""
                }
                Button("取消", role: .cancel) { newName = "" }
            }
        }
    }
}

// MARK: - Edit word details

struct EditWordSheet: View {
    @State var entry: DictEntry
    @State var selected: [String]
    var onSave: (DictEntry, [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""

    var body: some View {
        NavigationStack {
            Form { Group {
                Section("單字") { TextField("單字", text: $entry.w).font(.title3.bold()).textInputAutocapitalization(.never) }
                Section("選擇要保留的意思") {
                    ForEach(Array(entry.zh.enumerated()), id: \.offset) { i, m in
                        Button { toggle(m) } label: {
                            HStack {
                                LIcon(selected.contains(m) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(m) ? Color.themeAccent : .secondary).font(.title3)
                                VStack(alignment: .leading) {
                                    Text(m).font(.headline)
                                    if !entry.pos.isEmpty { Text(entry.pos).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                if i == 0 { Text("最常用").font(.caption).foregroundStyle(.secondary) }
                            }
                        }.foregroundStyle(.primary)
                    }
                    HStack {
                        TextField("新增自己的意思", text: $custom)
                        Button { addCustom() } label: { LIcon("plus.circle.fill").font(.title2) }
                            .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("詞性與音標") {
                    TextField("詞性（例如 n. / v. / adj.）", text: $entry.pos)
                    TextField("音標", text: $entry.ipa)
                }
                Section("英文解釋") { TextField("Definition", text: $entry.def, axis: .vertical) }
                Section("例句") {
                    TextField("English example", text: $entry.ex, axis: .vertical)
                    TextField("中文翻譯", text: $entry.exZh, axis: .vertical)
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .navigationTitle("確認單字").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        entry.w = entry.w.lowercased().trimmingCharacters(in: .whitespaces)
                        onSave(entry, selected.isEmpty ? Array(entry.zh.prefix(1)) : selected)
                        dismiss()
                    }.disabled(entry.w.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func toggle(_ m: String) {
        if let i = selected.firstIndex(of: m) { selected.remove(at: i) } else { selected.append(m) }
    }
    private func addCustom() {
        let m = custom.trimmingCharacters(in: .whitespaces)
        guard !m.isEmpty else { return }
        entry.zh.append(m); selected.append(m); custom = ""
    }
}

// MARK: - Mastery ladder

/// Level names used across Lexi (0 = not studied yet).
let levelNames = ["未學", "初見", "認得", "熟悉", "穩固", "精通"]

/// Six steps from 未學 to 精通; each column's height shows how many words sit on that step.
struct MasteryCard: View {
    let distribution: [Int]
    /// false inside a List section (the section is the card).
    var boxed = true
    @State private var showInfo = false

    var body: some View {
        Group {
            if boxed { ladder.card() } else { ladder }
        }
        .alert("熟練階梯", isPresented: $showInfo) {
            Button("好") {}
        } message: {
            Text("答「會」往上爬一階，答「不會」退一階。\n初見 翻卡片 → 認得 英翻中 → 熟悉 中翻英 → 穩固 克漏字 → 精通 拼單字。\n爬到精通並再答對一次，就算真正學會。")
        }
    }

    private var ladder: some View {
        let top = max(1, distribution.max() ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("熟練階梯").font(.system(.headline).weight(.bold))
                Spacer()
                Button { showInfo = true } label: { LIcon("questionmark.circle") }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text("\(distribution[i])").font(.caption.weight(.bold)).monospacedDigit()
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(i == 0 ? Color.secondary.opacity(0.18) : Color.themeAccent.opacity(0.25 + Double(i) * 0.15))
                            .frame(height: 8 + 62 * CGFloat(distribution[i]) / CGFloat(top))
                        Text(levelNames[i]).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Achievement badge

/// Regular hexagon, pointy top.
struct Hexagon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Lexi's achievement: a flat hexagon in the flame colour with tier pips underneath.
struct BadgeMedal: View {
    let kind: BadgeKind
    let value: Int
    var size: CGFloat = 64
    var body: some View {
        let tier = kind.earned(for: value)
        let earned = tier > 0
        VStack(spacing: 6) {
            ZStack {
                Hexagon().fill(earned ? AnyShapeStyle(Color.themeAccent)
                                      : AnyShapeStyle(Color.secondary.opacity(0.14)))
                Hexagon().inset(size * 0.09).stroke(earned ? Color.white.opacity(0.55) : Color.secondary.opacity(0.25),
                                                     style: StrokeStyle(lineWidth: 1.5, dash: earned ? [] : [3, 3]))
                LIcon(kind.symbol).font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(earned ? Color.white : Color.secondary.opacity(0.6))
            }
            .frame(width: size, height: size)
            HStack(spacing: 3) {
                ForEach(0..<kind.tiers.count, id: \.self) { i in
                    Capsule().fill(i < tier ? Color.themeAccent : Color.secondary.opacity(0.25)).frame(width: 8, height: 3)
                }
            }
            Text(kind.title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(value) / \(kind.next(for: value))").font(.caption.bold()).monospacedDigit()
        }
    }
}

private extension Hexagon {
    func inset(_ d: CGFloat) -> some Shape { InsetHexagon(d: d) }
}
private struct InsetHexagon: Shape {
    let d: CGFloat
    func path(in r: CGRect) -> Path { Hexagon().path(in: r.insetBy(dx: d, dy: d)) }
}

/// Square label for round icon buttons (back, close, share).
struct GlassCircleIcon: View {
    let systemName: String
    var body: some View {
        LIcon(systemName).font(.system(size: 17, weight: .semibold))
            .frame(width: 29, height: 29)
    }
}

/// Score ring for the end of a round: the share of first answers that were 會.
struct ScoreRing: View {
    let good: Int, unsure: Int, again: Int
    @State private var shown = false
    var body: some View {
        let total = max(1, good + unsure + again)
        let parts: [(Double, Color)] = [(Double(good), .green.opacity(0.75)), (Double(unsure), .orange), (Double(again), .themeAccent)]
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 16)
            ForEach(0..<3, id: \.self) { k in
                let start = parts.prefix(k).map(\.0).reduce(0, +) / Double(total)
                let end = start + parts[k].0 / Double(total)
                Circle().trim(from: start, to: shown ? end : start)
                    .stroke(parts[k].1, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(Int((Double(good) / Double(total) * 100).rounded()))%").font(.system(size: 40, weight: .bold))
                Text("一次就會").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
    }
}
