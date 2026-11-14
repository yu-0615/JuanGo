import SwiftUI
import SwiftData

// MARK: - Questions (flashcard, choice, spelling)

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
    /// 減少動態效果: the card cross-fades instead of turning over
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                face(back: false).opacity(flipped ? 0 : 1)
                face(back: true).opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (0, 1, 0))
            }
            .rotation3DEffect(.degrees(flipped && !reduceMotion ? 180 : 0), axis: (0, 1, 0), perspective: 0.4)
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
            .accessibilityAction(named: "翻面") { flipped.toggle() }
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
                    if back {
                        HStack(alignment: .firstTextBaseline) {
                            if settings.showTranslation { Text(word.exampleZh).font(.app(.subheadline)).foregroundStyle(.secondary) }
                            Spacer(minLength: 0)
                            Button { Speech.say(word.example) } label: { LIcon("speaker.wave.2.fill").font(.app(.subheadline)) }
                                .buttonStyle(.borderless).foregroundStyle(.tint)
                                .accessibilityLabel("念例句")
                        }
                    }
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
                            // two lines before shrinking: a long Chinese meaning was cut off with …
                            Text(o).font(.app(.headline)).lineLimit(2).minimumScaleFactor(0.8).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if picked == o, o != correct, let other = otherSide[o] {
                                Text(other).font(.app(.subheadline, .semibold)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        if picked != nil && o == correct { LIcon("checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("正確答案") }
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
                if picked == nil {
                    // rather than guessing: a lucky guess would count as 會 and push the word days away
                    Button("不知道") { picked = ""; Speech.say(word.term) }
                        .buttonStyle(PillButtonStyle(height: 46)).frame(width: 110)
                } else if let picked, picked != correct {
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
            guard settings.haptics, let new, !new.isEmpty else { return nil }
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
            SlowReplay(term: word.term)
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
        let phrases = Set((library.map(\.term) + Dictionary_.phrases.map(\.w))
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
        // only saved words the dictionary knows: a misread scan ("anfegetaball") makes a give-away option
        let own: [(term: String, zh: String, pos: String)] = library.filter { Dictionary_.lookup($0.term) != nil }
            .map { ($0.term, $0.primaryMeaning, $0.pos) }
        let dictSame = (Dictionary_.byPos[word.pos] ?? []).shuffled().prefix(40).map { ($0.w, $0.zh.first ?? "", $0.pos) }
        let dictAny = (0..<40).compactMap { _ in Dictionary_.all.randomElement() }.map { ($0.w, $0.zh.first ?? "", $0.pos) }
        let pool: [(term: String, zh: String, pos: String)] = own + dictSame + dictAny
        // nothing that would also be right: one of this word's other meanings, or its British / American twin
        let mine = Set(word.meanings)
        let others = pool.filter {
            $0.term != word.term && !$0.zh.isEmpty && $0.zh != word.primaryMeaning && !mine.contains($0.zh)
                && !SpellingQuestion.variants($0.term.lowercased(), word.term.lowercased())
        }
        let samePos = others.filter { $0.pos == word.pos }.shuffled()
        // a phrase among single words gives itself away, so English options for a phrase are phrases first
        let phrases = !answersInZh && word.term.contains(" ")
            ? (others + Dictionary_.phrases.map { ($0.w, $0.zh.first ?? "", $0.pos) })
                .filter { $0.term.contains(" ") && $0.term != word.term && GlossaryParser.cleanTerm($0.term) == $0.term }.shuffled()
            : []
        var picks: [String] = []
        for c in (phrases + samePos + others.shuffled()) {
            if !answersInZh, !word.term.contains(" "), c.term.contains(" ") { continue }   // and the other way round
            // an English option that also means one of the asked meanings (glad for 快樂的、高興的) is a second answer
            if !answersInZh, let z = Dictionary_.lookup(c.term)?.zh, !mine.isDisjoint(with: z) { continue }
            let v = answersInZh ? c.zh : c.term
            if !picks.contains(v) && v != correct { picks.append(v); otherSide[v] = answersInZh ? c.term : c.zh }
            if picks.count == 3 { break }
        }
        return (picks + [correct]).shuffled()
    }
}

/// Plays the word again at a slow rate, for when the normal speed is hard to catch.
struct SlowReplay: View {
    let term: String
    var body: some View {
        Button { Speech.say(term, rate: 0.28) } label: { Label("慢速再聽", pulso: "tortoise") }
            .font(.app(.subheadline, .semibold)).foregroundStyle(.tint)
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
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
    /// letters filled in with 提示; any hint makes a right answer 不確定, more than half of the word 不會
    @State private var hints = 0
    /// the width the letter boxes wrap in, measured (UIScreen.main is deprecated, and wrong in split view)
    @State private var areaWidth: CGFloat = 360

    /// The meaning on top, then one box per letter (first and last letter shown) that the answer is typed into.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                if listen {
                    Button { Speech.say(word.term) } label: {
                        LIcon("speaker.wave.3.fill").font(.app(size: 40)).frame(width: 100, height: 100)
                            .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.themeAccent.opacity(0.12)))
                    }.buttonStyle(.plain).foregroundStyle(.tint)
                    .accessibilityLabel("再聽一次")
                    SlowReplay(term: word.term)
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
                Label(checked ? (hints > 0 ? "拼對了（用了 \(hints) 次提示）" : Self.sameWord(text.lowercased(), word.term.lowercased()) ? "拼對了！另一種拼法是 \(word.term)" : "拼對了！") : nearMiss ? "差一點！答案是 \(word.term)" : "答案是 \(word.term)",
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
                if checked == nil {
                    Button(action: hint) { Label("提示", pulso: "lightbulb") }
                        .accessibilityHint("填入下一個字母")
                }
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { areaWidth = $0 }
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
        let width = areaWidth
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
                        HStack(spacing: 4) { ForEach(Array(w), id: \.self) { k in box(k, t: t, side: side, wrong: checked == false && !matched.contains(k)) } }
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
        // the field types a straight ' but some terms carry a curly ’ (o’clock); extra spaces don't count either
        func plain(_ s: String) -> String {
            s.lowercased().replacingOccurrences(of: "’", with: "'").split(separator: " ").joined(separator: " ")
        }
        let typed = plain(text), answer = plain(word.term)
        let ok = typed == answer || Self.sameWord(typed, answer)
        nearMiss = !ok && answer.count >= 4 && Self.distance(typed, answer) == 1
        checked = ok
        Speech.say(word.term)
        let letters = word.term.filter(\.isLetter).count
        let grade: Grade = hints == 0 ? .good : hints * 2 > letters ? .again : .unsure
        if ok { Task { try? await Task.sleep(for: .seconds(0.8)); onGrade(grade) } }
    }

    /// British spellings in the dictionary (from its UK sources) and their American forms: either is right.
    static let britishToAmerican: [String: String] = [
        "favour": "favor", "behaviour": "behavior", "harbour": "harbor", "rumour": "rumor", "flavour": "flavor",
        "endeavour": "endeavor", "armour": "armor", "glamour": "glamor", "odour": "odor", "tumour": "tumor",
        "clamour": "clamor", "centre": "center", "theatre": "theater", "fibre": "fiber", "meagre": "meager",
        "calibre": "caliber", "catalogue": "catalog", "dialogue": "dialog", "monologue": "monolog", "prologue": "prolog",
        "paralyse": "paralyze", "memorise": "memorize", "defence": "defense", "offence": "offense", "licence": "license",
        "tyre": "tire", "mould": "mold", "plough": "plow", "aluminium": "aluminum", "moustache": "mustache",
        "storey": "story", "draught": "draft", "sceptical": "skeptical", "manoeuvre": "maneuver",
        "acknowledgement": "acknowledgment", "fulfil": "fulfill", "axe": "ax", "gaol": "jail", "doughnut": "donut",
    ]
    /// American words that mean something else too (tire 疲倦, story 故事, draft 草稿): the British form isn't
    /// accepted for them, only the other way round.
    private static let oneWay: Set<String> = ["tire", "story", "draft", "jail"]
    static func variants(_ a: String, _ b: String) -> Bool { britishToAmerican[a] == b || britishToAmerican[b] == a }
    static func sameWord(_ typed: String, _ answer: String) -> Bool {
        if britishToAmerican[answer] == typed { return true }
        if let us = britishToAmerican[typed], us == answer, !oneWay.contains(answer) { return true }
        return false
    }

    /// Keeps what's typed right so far and adds the next letter (with any hyphen or space after it).
    private func hint() {
        let t = Array(word.term), typed = Array(text)
        var k = 0
        while k < typed.count, k < t.count, String(typed[k]).lowercased() == String(t[k]).lowercased() { k += 1 }
        guard k < t.count else { return }
        k += 1
        while k < t.count, !t[k].isLetter { k += 1 }   // the boxes show these anyway
        text = String(t[..<k]); hints += 1; typing = true
        if k == t.count { check() }
    }

    /// Positions in `answer` that line up with what was typed (longest common subsequence), so a missed letter
    /// marks only that letter, not everything after it: atraction → a t [t] r a c t i o n.
    static func matchedLetters(of answer: String, in typed: String) -> Set<Int> {
        let a = Array(answer.lowercased().replacingOccurrences(of: "’", with: "'")), b = Array(typed.lowercased())
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
