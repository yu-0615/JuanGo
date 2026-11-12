import SwiftUI
import SwiftData
import Vision
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - OCR with word boxes

struct ScanToken: Identifiable {
    let id: Int
    let text: String
    /// normalized, top-left origin
    let rect: CGRect
    let entry: DictEntry?
    /// Part of speech this occurrence has in its sentence ("v.", "n." …), from NaturalLanguage.
    var context: String? = nil
    /// occurrences of the same word share one selection key
    var key: String { entry?.w ?? text.lowercased() }

    /// The part of speech this occurrence counts as. The dictionary lists every part of speech a word
    /// can have ("pressure" is n./v.), so the word is classified by how this sentence uses it.
    /// - the sentence's use, when the dictionary allows it ("Parents pressure…" → v.)
    /// - a verb-like use of a modal (must, will) → aux.
    /// - the sentence's use contradicts the dictionary → [] (unclear, so no part-of-speech filter picks it)
    /// - no sentence information (a lone heading word) → the dictionary's list
    var usedAs: [String] {
        guard let tags = entry?.posTags, !tags.isEmpty else { return [] }
        guard let context else { return tags }
        if context == "v.", tags.contains("aux.") { return ["aux."] }
        return tags.contains(context) ? [context] : []
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let tokens: [ScanToken]
    /// Filled when the photo is a word list (單字統整): the part of speech and meanings printed on it.
    var glossary: [GlossaryEntry] = []
}

enum PhotoScanner {
    /// Redraws the photo upright (so Vision boxes map straight onto it) and caps its size.
    static func upright(_ image: UIImage, maxSide: CGFloat = 2400) -> UIImage {
        let s = image.size
        let scale = min(1, maxSide / max(s.width, s.height))
        let size = CGSize(width: (s.width * scale).rounded(), height: (s.height * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func scan(_ raw: UIImage) async -> ScanResult? {
        let image = upright(raw)
        guard let cg = image.cgImage else { return nil }
        let (words, text, lines) = await recognizeWords(cg)
        let used = partsOfSpeech(in: text, at: words.map(\.loc))
        let tokens = words.enumerated().map { i, w in
            ScanToken(id: i, text: w.text, rect: w.rect, entry: w.text.count >= 2 ? Dictionary_.lookup(w.text) : nil, context: used[i])
        }
        return ScanResult(image: image, tokens: tokens, glossary: GlossaryParser.parse(rows: GlossaryParser.rows(from: lines)))
    }

    /// Tags each word (given by its UTF-16 offset in `text`) with the part of speech it has in its sentence.
    nonisolated static func partsOfSpeech(in text: String, at locs: [Int]) -> [String?] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        let map: [NLTag: String] = [.noun: "n.", .verb: "v.", .adjective: "adj.", .adverb: "adv.",
                                    .preposition: "prep.", .conjunction: "conj.", .pronoun: "pron."]
        return locs.map { loc in
            let i = String.Index(utf16Offset: min(loc, text.utf16.count - 1), in: text)
            return tagger.tag(at: i, unit: .word, scheme: .lexicalClass).0.flatMap { map[$0] }
        }
    }

    /// Words with their boxes, plus the recognised text joined into running prose (lines joined by spaces,
    /// so a sentence that wraps stays one sentence) and each word's UTF-16 offset in it, for tagging.
    nonisolated private static func recognizeWords(_ cg: CGImage) async -> ([(text: String, rect: CGRect, loc: Int)], String, [(text: String, box: CGRect)]) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                // Chinese too: word lists print 中文意思 next to each word, and an English-only
                // recogniser turns those characters into junk "words" (FA, EA…).
                req.recognitionLanguages = ["zh-Hant", "en-US"]
                req.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
                let ink = InkMap(cg)
                var out: [(text: String, rect: CGRect, loc: Int)] = []
                var full = ""
                var lines: [(text: String, box: CGRect)] = []
                var hyphenated: Int?          // index of a word broken across lines ("trans-")
                for obs in req.results ?? [] {
                    guard let cand = obs.topCandidates(1).first else { continue }
                    let s = cand.string
                    lines.append((s, obs.boundingBox))
                    let base = full.utf16.count
                    full += s + " "
                    let matches = s.matches(of: /[A-Za-z]+(?:['’][A-Za-z]+)*/)
                    for (n, m) in matches.enumerated() {
                        guard let box = (try? cand.boundingBox(for: m.range))?.boundingBox else { continue }
                        var rect = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
                        rect = ink?.trim(rect) ?? rect
                        var word = String(s[m.range])
                        if n == 0, let h = hyphenated {        // second half of "trans- / portation"
                            word = out[h].text + word
                            out[h].text = word
                            hyphenated = nil
                        }
                        out.append((word, rect, base + NSRange(m.range, in: s).location))
                        if n == matches.count - 1 {
                            let rest = s[m.range.upperBound...].trimmingCharacters(in: .whitespaces)
                            hyphenated = (rest == "-" || rest == "‐") ? out.count - 1 : nil
                        }
                    }
                }
                cont.resume(returning: (out.filter { $0.text.count >= 2 }, full, lines))
            }
        }
    }
}

/// Grayscale copy of the photo, used to shrink Vision's word boxes (which include the
/// surrounding spaces) down to the actual ink so neighbouring boxes no longer overlap.
nonisolated struct InkMap {
    let w: Int, h: Int
    let px: [UInt8]

    init?(_ cg: CGImage) {
        let W = cg.width, H = cg.height
        var buf = [UInt8](repeating: 0, count: W * H)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
            return true
        }
        guard ok else { return nil }
        w = W; h = H; px = buf
    }

    /// `r` is normalized with a top-left origin.
    func trim(_ r: CGRect) -> CGRect {
        let x0 = max(0, Int(r.minX * CGFloat(w))), x1 = min(w - 1, Int(r.maxX * CGFloat(w)))
        let y0 = max(0, Int(r.minY * CGFloat(h))), y1 = min(h - 1, Int(r.maxY * CGFloat(h)))
        guard x1 - x0 > 4, y1 - y0 > 4 else { return r }
        var hist = [Int](repeating: 0, count: 256)
        for y in stride(from: y0, through: y1, by: 2) { for x in stride(from: x0, through: x1, by: 2) { hist[Int(px[y * w + x])] += 1 } }
        let total = hist.reduce(0, +)
        func percentile(_ p: Double) -> Int {
            var acc = 0
            for (v, c) in hist.enumerated() { acc += c; if Double(acc) >= Double(total) * p { return v } }
            return 255
        }
        let dark = percentile(0.05), paper = percentile(0.7)
        guard paper - dark > 45 else { return r }        // too little contrast to judge
        let thr = UInt8(dark + (paper - dark) / 2)
        // ignore the outer rows so letters from the lines above/below don't count
        let iy0 = y0 + (y1 - y0) / 6, iy1 = y1 - (y1 - y0) / 6
        func hasInk(_ x: Int) -> Bool {
            var n = 0
            for y in iy0...iy1 where px[y * w + x] < thr { n += 1; if n >= 2 { return true } }
            return false
        }
        var l = x0, rr = x1
        while l < rr, !hasInk(l) { l += 1 }
        while rr > l, !hasInk(rr) { rr -= 1 }
        guard rr - l > 2 else { return r }
        let pad = max(1, (y1 - y0) / 12)
        l = max(x0, l - pad); rr = min(x1, rr + pad)
        return CGRect(x: CGFloat(l) / CGFloat(w), y: r.minY, width: CGFloat(rr - l) / CGFloat(w), height: r.height)
    }
}

// MARK: - Filter + instructions

struct ScanFilter: Equatable {
    var minLevel = 1
    var maxLevel = 6
    var pos: Set<String> = []
    var onlyNew = true
    var includeOffList = false

    func accepts(_ t: ScanToken, saved: Set<String>) -> Bool {
        if OCRCandidates.stopwords.contains(t.key) { return false }
        guard let e = t.entry else { return includeOffList && t.text.count >= 3 && !OCRCandidates.stopwords.contains(t.key) && !(onlyNew && saved.contains(t.key)) }
        // words from the 國中小 / test-prep lists carry no 大考 level: they count as "課外字"
        if let lv = Int(e.lv) {
            guard (minLevel...maxLevel).contains(lv) else { return false }
        } else if !includeOffList { return false }
        if !pos.isEmpty && pos.isDisjoint(with: t.usedAs) { return false }
        if onlyNew && saved.contains(e.w) { return false }
        return true
    }

    var summary: String {
        var parts = [minLevel == maxLevel ? "第\(minLevel)級" : "第\(minLevel)–\(maxLevel)級"]
        if !pos.isEmpty { parts.append(pos.sorted().compactMap { ScanFilter.posNames[$0] }.joined(separator: "/")) }
        if onlyNew { parts.append("未加入") }
        if includeOffList { parts.append("含課外字") }
        return parts.joined(separator: "・")
    }

    static let posNames = ["n.": "名詞", "v.": "動詞", "adj.": "形容詞", "adv.": "副詞", "prep.": "介系詞", "conj.": "連接詞", "pron.": "代名詞", "aux.": "助動詞"]
}

/// What an instruction asks for: a new filter, and whether to select / clear.
struct ScanCommand {
    enum Action { case selectMatches, clear, selectAll, keepSelection }
    var filter: ScanFilter
    var action: Action
    var words: [String] = []
}

enum InstructionParser {
    private static let digits: [Character: Int] = ["1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6,
                                                   "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6]

    /// Rule-based understanding of short Chinese / English instructions. Returns nil when nothing was understood.
    static func parse(_ raw: String, current: ScanFilter, tokens: [ScanToken]) -> ScanCommand? {
        let s = raw.lowercased().replacingOccurrences(of: " ", with: "")
        var f = current
        var understood = false
        var action = ScanCommand.Action.selectMatches

        if ["清除", "全不選", "取消全部", "取消選取", "clear", "none"].contains(where: s.contains) { return ScanCommand(filter: f, action: .clear) }

        // levels: 3-5級 / 3到5級 / 4級以上 / 第5級 / 3級以下
        let chars = Array(s)
        var nums: [(Int, Int)] = []   // (value, index)
        for (i, c) in chars.enumerated() { if let n = digits[c] { nums.append((n, i)) } }
        if s.contains("級") || s.contains("level") || s.contains("lv") {
            if nums.count >= 2 {
                f.minLevel = min(nums[0].0, nums[1].0); f.maxLevel = max(nums[0].0, nums[1].0); understood = true
            } else if let n = nums.first?.0 {
                let tail = String(chars[min(chars.count, nums[0].1 + 1)...])
                if tail.contains("以上") || tail.contains("+") || tail.contains("up") { f.minLevel = n; f.maxLevel = 6 }
                else if tail.contains("以下") || tail.contains("以內") { f.minLevel = 1; f.maxLevel = n }
                else { f.minLevel = n; f.maxLevel = n }
                understood = true
            }
        }
        if ["難", "進階", "高級", "hard", "difficult"].contains(where: s.contains) { f.minLevel = 5; f.maxLevel = 6; understood = true }
        if ["簡單", "基礎", "國中", "easy", "basic"].contains(where: s.contains) { f.minLevel = 1; f.maxLevel = 2; understood = true }
        if ["中等", "中級", "高中"].contains(where: s.contains) && !understood { f.minLevel = 3; f.maxLevel = 4; understood = true }
        if ["所有等級", "不限等級", "全部等級", "7000", "6000", "學測"].contains(where: s.contains) { f.minLevel = 1; f.maxLevel = 6; understood = true }

        // parts of speech
        let posWords: [(String, String)] = [("名詞", "n."), ("noun", "n."), ("動詞", "v."), ("verb", "v."), ("形容詞", "adj."), ("adjective", "adj."),
                                             ("副詞", "adv."), ("adverb", "adv."), ("介系詞", "prep."), ("介詞", "prep."), ("連接詞", "conj."), ("代名詞", "pron.")]
        let pos = Set(posWords.filter { s.contains($0.0) && !(($0.0 == "名詞") && s.contains("代名詞")) }.map(\.1))
        if !pos.isEmpty { f.pos = pos; understood = true }
        if ["所有詞性", "不限詞性"].contains(where: s.contains) { f.pos = []; understood = true }

        // saved / new
        if ["包含已加入", "包括已加入", "含已加入", "已經加入的也", "不管有沒有加入"].contains(where: s.contains) { f.onlyNew = false; understood = true }
        else if ["沒學過", "還沒加入", "未加入", "沒加入", "新的", "不會", "生字", "new"].contains(where: s.contains) { f.onlyNew = true; understood = true }

        // words outside the 7000 list
        if ["課外", "不在字典", "字典外", "其他字", "所有字", "全部的字", "everyword"].contains(where: s.contains) { f.includeOffList = true; understood = true }
        if ["只要字典", "只要7000", "只要學測", "字典裡"].contains(where: s.contains) { f.includeOffList = false; understood = true }

        if ["全部", "全選", "都選", "所有", "all"].contains(where: s.contains) && !understood { action = .selectAll; understood = true }

        // explicit words from the photo: "選 abandon 和 rescue"
        let present = Set(tokens.map { $0.text.lowercased() })
        let named = raw.lowercased().split { !$0.isLetter || !$0.isASCII }.map(String.init)
            .filter { $0.count >= 2 && present.contains($0) && !["all", "new", "verb", "noun", "level", "lv", "easy", "hard", "basic"].contains($0) }
        if !named.isEmpty && !understood {
            return ScanCommand(filter: current, action: .keepSelection, words: named)
        }
        return understood ? ScanCommand(filter: f, action: action) : nil
    }
}

#if canImport(FoundationModels)
@Generable
struct LLMScanInstruction {
    @Guide(description: "Lowest 大考 vocabulary level (1 = easiest, 6 = hardest) the user wants")
    var minLevel: Int
    @Guide(description: "Highest level (1-6) the user wants; 6 if no upper limit")
    var maxLevel: Int
    @Guide(description: "Parts of speech wanted, using only n. v. adj. adv. prep. conj. pron.; empty for any")
    var partsOfSpeech: [String]
    @Guide(description: "true unless the user also wants words already in their word book")
    var onlyNotSaved: Bool
    @Guide(description: "true if the user wants words that are not in the 7000-word list too")
    var includeOffList: Bool
    @Guide(description: "Specific English words from the photo the user named, lowercase; usually empty")
    var words: [String]
}

enum LLMInstruction {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static func interpret(_ text: String, words: [String]) async -> ScanCommand? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You turn a Taiwanese high-school student's instruction (usually Traditional Chinese) into filters for picking \
            English vocabulary words from a scanned page. Levels come from Taiwan's 7000-word list: 1-2 basic, 3-4 intermediate, 5-6 advanced.
            """)
        let prompt = "Instruction: \(text)\nWords on the page: \(words.prefix(150).joined(separator: ", "))"
        guard let r = try? await session.respond(to: prompt, generating: LLMScanInstruction.self).content else { return nil }
        var f = ScanFilter()
        f.minLevel = max(1, min(6, r.minLevel)); f.maxLevel = max(f.minLevel, min(6, r.maxLevel))
        f.pos = Set(r.partsOfSpeech.filter { ScanFilter.posNames[$0] != nil })
        f.onlyNew = r.onlyNotSaved
        f.includeOffList = r.includeOffList
        let named = r.words.map { $0.lowercased() }.filter { w in words.contains(w) }
        return ScanCommand(filter: f, action: named.isEmpty ? .selectMatches : .keepSelection, words: named)
    }
}
#endif

// MARK: - Scan screen

struct ScanView: View {
    let result: ScanResult
    var destination: WordList?
    var onDone: (Int) -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query private var library: [Word]

    @State private var filter = ScanFilter()
    @State private var selected: [String] = []          // keys, in the order picked
    @State private var lasso: [CGPoint] = []
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var basePan: CGSize = .zero
    @State private var moveMode = false
    @State private var pinching = false
    @State private var instruction = ""
    @State private var thinking = false
    @State private var feedback: String?
    @State private var showList = false
    @FocusState private var typing: Bool

    private var saved: Set<String> { Set(library.filter(\.inMyWords).map(\.term)) }
    private var matches: [ScanToken] { result.tokens.filter { filter.accepts($0, saved: saved) } }
    private var matchKeys: [String] { unique(matches.map(\.key)) }
    /// Word-list photos: what the page itself says about each word, keyed by the word exactly as printed
    /// (so "approximately" stays approximately instead of becoming the dictionary's "approximate").
    private var pageEntries: [String: GlossaryEntry] {
        Dictionary(result.glossary.map { ($0.term, repaired($0)) }, uniquingKeysWith: { a, _ in a })
    }
    private var pageKeys: [String] { result.glossary.map(\.term) }
    /// The dictionary entry spelled exactly like `term`, if any.
    private func exactEntry(_ term: String) -> DictEntry? { Dictionary_.lookup(term).flatMap { $0.w == term ? $0 : nil } }
    /// OCR tends to drop a line-final 的 ("有能力的" → "有能力"); put it back when the dictionary has that meaning.
    private func repaired(_ g: GlossaryEntry) -> GlossaryEntry {
        guard let e = exactEntry(g.term) else { return g }
        var g = g
        g.meanings = g.meanings.map { m in e.zh.contains(m + "的") ? m + "的" : m }
        return g
    }
    private func unique(_ a: [String]) -> [String] { var s = Set<String>(); return a.filter { s.insert($0).inserted } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                photo
                controls
            }
            .background(Color.black.opacity(0.92).ignoresSafeArea())
            .navigationTitle("圈選單字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入 \(selected.count) 個") { addSelected() }.disabled(selected.isEmpty).bold()
                }
            }
            .sheet(isPresented: $showList) { selectionList }
            .onAppear {
                // level-1 words (have, are, change…) are known by everyone in 高中; start from 2 or the user's level
                filter.minLevel = max(2, Int(settings.level) ?? 2)
                #if DEBUG   // simulator testing: SIMCTL_CHILD_LEXI_SCAN_POS=v. (and LEXI_SCAN_LIST=1 to open the list)
                let env = ProcessInfo.processInfo.environment
                if let p = env["LEXI_SCAN_POS"] { filter.minLevel = 1; filter.pos = [p]; selected = matchKeys; showList = env["LEXI_SCAN_LIST"] != nil; return }
                #endif
                // A word list: take every word on it, with the page's own part of speech and meaning.
                if !result.glossary.isEmpty {
                    selected = pageKeys
                    flash("單字統整頁：帶入 \(pageKeys.count) 個字的詞性和中文")
                    Task { try? await Task.sleep(for: .milliseconds(900)); showList = true }
                }
            }
        }
    }

    // MARK: photo with word boxes

    private var photo: some View {
        GeometryReader { geo in
            let fit = fitted(result.image.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: result.image).resizable().frame(width: fit.width, height: fit.height)
                Canvas { g, _ in
                    let sel = Set(selected), cand = Set(matches.map(\.id))
                    for t in result.tokens {
                        let r = rect(t, fit).insetBy(dx: -1, dy: -1)
                        let shape = Path(roundedRect: r, cornerRadius: 3 / zoom)
                        // With a part-of-speech filter on, only the occurrences used that way are filled;
                        // the same word used another way ("booked" while picking nouns) just gets an outline.
                        let usedThatWay = filter.pos.isEmpty || !filter.pos.isDisjoint(with: t.usedAs)
                        let picked = sel.contains(t.key) || sel.contains(t.text.lowercased())
                        if picked && usedThatWay {
                            g.fill(shape, with: .color(settings.theme.accent.opacity(0.45)))
                            g.stroke(shape, with: .color(settings.theme.accent), lineWidth: 2 / zoom)
                        } else if picked {
                            g.stroke(shape, with: .color(settings.theme.accent.opacity(0.6)), lineWidth: 1.2 / zoom)
                        } else if cand.contains(t.id) {
                            g.stroke(shape, with: .color(.orange.opacity(0.95)),
                                     style: StrokeStyle(lineWidth: 1.5 / zoom, dash: [4 / zoom, 3 / zoom]))
                        }
                    }
                    if lasso.count > 1 {
                        var p = Path(); p.addLines(lasso)
                        g.stroke(p, with: .color(settings.theme.accent), style: StrokeStyle(lineWidth: 3 / zoom, lineCap: .round, lineJoin: .round))
                        p.closeSubpath()
                        g.fill(p, with: .color(settings.theme.accent.opacity(0.12)))
                    }
                }
                .frame(width: fit.width, height: fit.height)
            }
            .frame(width: fit.width, height: fit.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    typing = false
                    guard !pinching else { lasso = []; return }
                    if lasso.isEmpty || hypot(v.location.x - (lasso.last?.x ?? 0), v.location.y - (lasso.last?.y ?? 0)) > 3 { lasso.append(v.location) }
                }
                .onEnded { v in
                    guard !pinching else { lasso = []; return }
                    // a closed loop ends where it started, so measure the path, not the translation
                    let travelled = zip(lasso, lasso.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
                    if travelled < 12 { tap(at: v.location, fit) } else { circle(fit) }
                    lasso = []
                }, isEnabled: !moveMode)
            .scaleEffect(zoom)
            .offset(pan)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear { viewport = geo.size; fitSize = fit }
            .onChange(of: geo.size) { _, s in viewport = s; fitSize = fitted(result.image.size, in: s) }
        }
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(MagnifyGesture()
            .onChanged { v in
                pinching = true; lasso = []
                zoom = min(5, max(1, baseZoom * v.magnification))
                // keep the spot between the fingers under the fingers
                let a = CGSize(width: v.startLocation.x - viewport.width / 2, height: v.startLocation.y - viewport.height / 2)
                let k = zoom / baseZoom
                pan = clampPan(CGSize(width: a.width - (a.width - basePan.width) * k, height: a.height - (a.height - basePan.height) * k))
            }
            .onEnded { _ in
                baseZoom = zoom
                if zoom < 1.05 { withAnimation(.snappy) { zoom = 1; baseZoom = 1; pan = .zero; basePan = .zero } }
                basePan = clampPan(pan); pan = basePan
                Task { try? await Task.sleep(for: .milliseconds(150)); pinching = false }
            })
        .gesture(DragGesture()
            .onChanged { v in pan = clampPan(CGSize(width: basePan.width + v.translation.width, height: basePan.height + v.translation.height)) }
            .onEnded { _ in basePan = pan }, isEnabled: moveMode)
        .overlay(alignment: .bottomTrailing) { zoomControls }
        .overlay(alignment: .top) {
            if let feedback {
                Text(feedback).font(.app(.subheadline, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(.black.opacity(0.7)))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @State private var viewport: CGSize = .zero
    @State private var fitSize: CGSize = .zero

    /// keep the zoomed photo covering the viewport
    private func clampPan(_ p: CGSize) -> CGSize {
        let mx = max(0, (fitSize.width * zoom - viewport.width) / 2), my = max(0, (fitSize.height * zoom - viewport.height) / 2)
        return CGSize(width: min(mx, max(-mx, p.width)), height: min(my, max(-my, p.height)))
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button { moveMode = false } label: {
                Label("圈選", pulso: "lasso").padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(moveMode ? Color.clear : Color.themeAccent))
            }
            Button { moveMode = true } label: {
                Label("移動", pulso: "hand.draw").padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(moveMode ? Color.themeAccent : Color.clear))
            }
            if zoom > 1 {
                Button {
                    withAnimation(.snappy) { zoom = 1; baseZoom = 1; pan = .zero; basePan = .zero }; moveMode = false
                } label: { LIcon("arrow.down.right.and.arrow.up.left").padding(8) }
            }
        }
        .font(.app(.caption, .bold))
        .foregroundStyle(.white)
        .padding(3)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(.black.opacity(0.65)))
        .padding(10)
    }

    private func fitted(_ img: CGSize, in box: CGSize) -> CGSize {
        let s = min(box.width / img.width, box.height / img.height)
        return CGSize(width: img.width * s, height: img.height * s)
    }
    private func rect(_ t: ScanToken, _ fit: CGSize) -> CGRect {
        CGRect(x: t.rect.minX * fit.width, y: t.rect.minY * fit.height, width: t.rect.width * fit.width, height: t.rect.height * fit.height)
    }

    private func tap(at p: CGPoint, _ fit: CGSize) {
        let hit = result.tokens.min { a, b in dist(p, rect(a, fit)) < dist(p, rect(b, fit)) }
        guard let hit, dist(p, rect(hit, fit)) < 14 else { return }
        toggle(hit.key)
    }
    private func dist(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return hypot(dx, dy)
    }
    private func circle(_ fit: CGSize) {
        guard lasso.count > 2 else { return }
        var path = Path(); path.addLines(lasso); path.closeSubpath()
        let inside = result.tokens.filter { t in
            let r = rect(t, fit); return path.contains(CGPoint(x: r.midX, y: r.midY))
        }
        // Prefer dictionary words when the circle catches whole sentences.
        let keys = unique(inside.filter { $0.entry != nil && !OCRCandidates.stopwords.contains($0.key) || inside.count <= 2 }.map(\.key))
        let new = keys.filter { !selected.contains($0) }
        if new.isEmpty {
            selected.removeAll { keys.contains($0) }
            flash("取消選取 \(keys.count) 個字")
        } else {
            selected += new
            flash("圈到 \(new.count) 個字")
        }
        if settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
    private func toggle(_ key: String) {
        if let i = selected.firstIndex(of: key) { selected.remove(at: i) } else { selected.append(key) }
        if settings.haptics { UISelectionFeedbackGenerator().selectionChanged() }
    }
    private func flash(_ text: String) {
        withAnimation { feedback = text }
        Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { if feedback == text { feedback = nil } } }
    }

    // MARK: instruction + filter controls

    private let examples = ["第4級以上", "只要動詞", "難的字", "包含已加入", "全部選取", "清除"]

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LIcon("wand.and.stars").foregroundStyle(.tint)
                TextField("告訴我要找哪些字，例如「第5級以上的動詞」", text: $instruction)
                    .focused($typing)
                    .submitLabel(.go)
                    .onSubmit(run)
                if thinking { ProgressView() } else if !instruction.isEmpty {
                    Button("執行", action: run).bold()
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.cardFill))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    filterMenu
                    ForEach(examples, id: \.self) { ex in
                        Button(ex) { instruction = ex; run() }
                            .font(.app(.footnote, .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.primary.opacity(0.07)))
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                Button { showList = true } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.isEmpty ? "點一下字或畫圈圈選" : "已選 \(selected.count) 個").font(.app(.headline))
                        Text(selected.isEmpty ? "黃色虛線框：符合「\(filter.summary)」的 \(matchKeys.count) 個字"
                             : selected.prefix(6).joined(separator: ", ") + (selected.count > 6 ? "…" : ""))
                            .font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.buttonStyle(.plain)
                Spacer()
                Button(selected.isEmpty ? "選取黃框" : "看清單") {
                    if selected.isEmpty { selected = matchKeys; flash("已選取 \(matchKeys.count) 個字") } else { showList = true }
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                .disabled(selected.isEmpty && matchKeys.isEmpty)
            }
        }
        .padding(16)
        .background(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26).fill(settings.theme.background).ignoresSafeArea())
    }

    private var filterMenu: some View {
        Menu {
            Section("等級") {
                Picker("最低", selection: $filter.minLevel) { ForEach(1...6, id: \.self) { Text("從第\($0)級").tag($0) } }
                Picker("最高", selection: $filter.maxLevel) { ForEach(1...6, id: \.self) { Text("到第\($0)級").tag($0) } }
            }
            Section("詞性") {
                ForEach(["n.", "v.", "adj.", "adv."], id: \.self) { p in
                    Button { if filter.pos.contains(p) { filter.pos.remove(p) } else { filter.pos.insert(p) } } label: {
                        if filter.pos.contains(p) { Label(ScanFilter.posNames[p]!, pulso: "checkmark") } else { Text(ScanFilter.posNames[p]!) }
                    }
                }
            }
            Toggle("只找還沒加入的", isOn: $filter.onlyNew)
            Toggle("包含 7000 單以外的字", isOn: $filter.includeOffList)
        } label: {
            Label(filter.summary, pulso: "line.3.horizontal.decrease.circle.fill")
                .font(.app(.footnote, .semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.themeAccent.opacity(0.18)))
        }
        .onChange(of: filter.minLevel) { _, v in if filter.maxLevel < v { filter.maxLevel = v } }
        .onChange(of: filter.maxLevel) { _, v in if filter.minLevel > v { filter.minLevel = v } }
    }

    private func run() {
        let text = instruction.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        typing = false
        if let cmd = InstructionParser.parse(text, current: filter, tokens: result.tokens) {
            apply(cmd); instruction = ""; return
        }
        #if canImport(FoundationModels)
        if LLMInstruction.isAvailable {
            thinking = true
            Task {
                let cmd = await LLMInstruction.interpret(text, words: unique(result.tokens.map { $0.text.lowercased() }))
                thinking = false
                if let cmd { apply(cmd); instruction = "" } else { flash("看不懂這個指令，換個說法試試") }
            }
            return
        }
        #endif
        flash("看不懂，可以試試「第4級以上」「名詞」「還沒加入的」")
    }

    private func apply(_ cmd: ScanCommand) {
        withAnimation {
            switch cmd.action {
            case .clear:
                selected = []; flash("已清除選取")
            case .selectAll:
                filter.includeOffList = true
                selected = unique(result.tokens.filter { filter.accepts($0, saved: saved) }.map(\.key)); flash("已選取 \(selected.count) 個字")
            case .keepSelection:
                let keys = unique(result.tokens.filter { cmd.words.contains($0.text.lowercased()) }.map(\.key))
                selected = unique(selected + keys); flash("已選取 \(keys.joined(separator: ", "))")
            case .selectMatches:
                filter = cmd.filter
                selected = matchKeys
                flash(selected.isEmpty ? "沒有符合「\(filter.summary)」的字" : "找到 \(selected.count) 個：\(filter.summary)")
            }
        }
    }

    // MARK: list + save

    /// How the photo's text uses a word, e.g. "課文中當動詞"; several uses are listed, unknown ones left out.
    private func usage(of key: String) -> String {
        let uses = unique(result.tokens.filter { $0.key == key && $0.usedAs.count == 1 }.compactMap { ScanFilter.posNames[$0.usedAs[0]] })
        return uses.isEmpty ? "" : "課文中當" + uses.joined(separator: "、")
    }

    private var selectionList: some View {
        NavigationStack {
            List { Group {
                if selected.isEmpty { Text("還沒有選取任何字").foregroundStyle(.secondary) }
                ForEach(selected, id: \.self) { key in
                    let e = pageEntries[key] != nil ? exactEntry(key) : Dictionary_.lookup(key)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(key).font(.app(.headline))
                                if let g = pageEntries[key] {
                                    if !g.pos.isEmpty { Text(g.pos).font(.app(.caption, .semibold)).foregroundStyle(.tint) }
                                } else {
                                    let used = usage(of: key)
                                    if !used.isEmpty {
                                        Text(used).font(.app(.caption, .semibold)).foregroundStyle(.tint)
                                    }
                                }
                            }
                            if let g = pageEntries[key] {
                                Text(g.meanings.joined(separator: "・")).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                            } else {
                                if let e {
                                    Text(e.zh.joined(separator: "・")).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                                } else if let ai = translator.cached(key) {
                                    Text((ai.pos.isEmpty ? "" : ai.pos + " ") + ai.meanings.joined(separator: "・") + "（AI）")
                                        .font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                                } else if translator.working.contains(key) {
                                    Text("AI 翻譯中…").font(.app(.subheadline)).foregroundStyle(.secondary)
                                } else {
                                    Text(translator.provider == .none ? "不在字典裡，加入後可以自己填意思" : "不在字典裡，加入時用 AI 翻譯")
                                        .font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        if let e { Text(levelLabel(e.lv)).font(.app(.caption, .bold)).foregroundStyle(.secondary) }
                        if saved.contains(key) { LIcon("checkmark.circle.fill").foregroundStyle(.green) }
                    }
                }
                .onDelete { selected.remove(atOffsets: $0) }
                if !result.glossary.isEmpty {
                    Text("偵測到單字統整頁，詞性和中文意思照頁面上的寫法加入。").font(.app(.footnote)).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .task(id: unknownKeys) { if !unknownKeys.isEmpty { _ = await translator.translate(unknownKeys) } }
            .navigationTitle("已選 \(selected.count) 個")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { showList = false } }
                ToolbarItem(placement: .confirmationAction) { Button("加入") { showList = false; addSelected() }.disabled(selected.isEmpty) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var translator: WordTranslator { .shared }
    /// picked words that neither the page nor the dictionary explains
    private var unknownKeys: [String] { selected.filter { pageEntries[$0] == nil && Dictionary_.lookup($0) == nil } }

    private func addSelected() {
        var untranslated: [Word] = []
        for key in selected {
            if let g = pageEntries[key] {
                // the page's own part of speech and meanings win over the dictionary's
                var e = exactEntry(key) ?? .custom(g.term, meaning: "")
                if !g.pos.isEmpty { e.pos = g.pos }
                // The dictionary's English definition and example describe the dictionary's sense; when the
                // page teaches another one (book v. 預訂, not 書), drop them so they don't contradict it.
                // (the definition and example belong to the dictionary's first sense)
                let first = e.zh.first ?? ""
                let sameSense = first.isEmpty || g.meanings.contains { first.contains($0) || $0.contains(first) }
                if !sameSense { e.def = ""; e.ex = ""; e.exZh = "" }
                e.zh = g.meanings
                let w = Library.add(e, meanings: g.meanings, to: destination, in: ctx)
                if !g.pos.isEmpty { w.pos = g.pos }
                if !sameSense { w.definition = ""; w.example = ""; w.exampleZh = ""; ExampleStore.shared.backfill([w]) }
            } else if let e = Dictionary_.lookup(key) { Library.add(e, to: destination, in: ctx) }
            else if let ai = translator.cached(key) { Library.add(ai.entry(for: key), to: destination, in: ctx) }
            else { untranslated.append(Library.add(.custom(key, meaning: ""), to: destination, in: ctx)) }
        }
        try? ctx.save()
        translator.fill(untranslated, in: ctx)
        onDone(selected.count)
        dismiss()
    }
}
