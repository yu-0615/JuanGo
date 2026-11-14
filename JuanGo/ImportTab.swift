import SwiftUI
import SwiftData
import PhotosUI
import Vision
import UniformTypeIdentifiers

struct ImportTab: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Word> { $0.inMyWords }, sort: \Word.addedAt, order: .reverse) private var recent: [Word]
    @Query(sort: \WordList.createdAt) private var lists: [WordList]

    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var lookup: LookupTerm?
    @State private var sharedFile: BackupFile?
    @State private var askCode = false
    @State private var codeInput = ""
    @State private var detail: Word?
    @State private var destination: WordList?
    @State private var toast: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var candidates: OCRCandidates?
    @State private var scan: ScanResult?
    @State private var busy = false

    private var suggestions: [DictEntry] { Dictionary_.suggestions(for: query) }

    var body: some View {
        NavigationStack {
            List { Group {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    suggestionList
                } else {
                    Section {
                        Picker(selection: $destination) {
                            Text("我的單字").tag(WordList?.none)
                            ForEach(lists) { l in Text(l.name).tag(WordList?.some(l)) }
                        } label: {
                            Label { Text("存到") } icon: { LIcon("folder").foregroundStyle(.tint) }
                        }
                    } footer: {
                        Text("在上方搜尋英文單字或中文意思，查到的字會存進這裡。")
                    }
                    Section("其他加入方式") {
                        sourceRow("拍照掃描", "camera.viewfinder") { showCamera = true }
                        sourceRow("從相簿選照片", "photo.stack") { showPhotoPicker = true }
                        sourceRow("匯入檔案（txt、csv、JuanGo 清單）", "doc.text") { showFileImporter = true }
                        sourceRow("輸入分享代碼", "square.and.arrow.down.fill") { codeInput = ""; askCode = true }
                    }
                    Section("最近新增") { recentList }
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "輸入英文單字或中文意思")
            .searchFocused($focused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(of: .search) { submit() }
            .safeAreaInset(edge: .bottom) {
                if let toast {
                    Toast(text: toast, action: nil) { withAnimation { self.toast = nil } }.padding(.horizontal, 20)
                }
            }
            .overlay { if busy { ProgressView("正在辨識文字…").padding(24).background(.regularMaterial, in: .rect(cornerRadius: Radius.lg)) } }
            .navigationTitle("新增")
            .themedBackground()
            .sheet(item: $detail) { WordDetailSheet(word: $0) }
            .sheet(item: $lookup) { item in
                WordConfirmSheet(term: item.term, destination: destination) { w in
                    query = ""; focused = false
                    withAnimation { toast = destination.map { "已加入「\($0.name)」" } ?? "已加入我的單字" }
                }
            }
            .backupImport($sharedFile, ctx: ctx) { r in withAnimation { toast = r } }
            .alert("輸入分享代碼", isPresented: $askCode) {
                TextField("例如 K7Q3-P9XM", text: $codeInput).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("取消", role: .cancel) {}
                Button("查詢") {
                    let code = codeInput
                    Task {
                        busy = true; defer { busy = false }
                        do { sharedFile = try await Cloud.shared.fetch(code: code) }
                        catch { withAnimation { toast = error.localizedDescription } }
                    }
                }
            } message: { Text("朋友分享清單時拿到的 8 碼代碼，不用登入也能加入。") }
            .task {   // simulator testing: SIMCTL_CHILD_JUANGO_LOOKUP=word opens the 確認單字 sheet
                if let t = ProcessInfo.processInfo.environment["JUANGO_LOOKUP"] { lookup = LookupTerm(term: t) }
            }
            .sheet(item: $candidates) { c in OCRPickerView(candidates: c, destination: destination) { n in
                withAnimation { toast = "已加入 \(n) 個單字" }
            } }
            .fullScreenCover(item: $scan) { r in
                ScanView(result: r, destination: destination) { n in withAnimation { toast = "已加入 \(n) 個單字" } }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in Task { await recognize(image) } }.ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            #if DEBUG
            .task {   // simulator testing: SIMCTL_CHILD_JUANGO_SCAN_IMAGE=/path/to/page.jpg
                if let p = ProcessInfo.processInfo.environment["JUANGO_SCAN_IMAGE"], let img = UIImage(contentsOfFile: p) { await recognize(img) }
            }
            #endif
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        await recognize(img)
                    }
                    photoItem = nil
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .text, .json]) { result in
                guard case .success(let url) = result else { return }
                if url.pathExtension.lowercased() == "json" {   // a JuanGo list or backup someone shared
                    do { sharedFile = try Backup.read(url) } catch { withAnimation { toast = error.localizedDescription } }
                    return
                }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) { candidates = OCRCandidates(text: text, fromFile: true) }
            }
        }
    }

    private func sourceRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title).foregroundStyle(.primary) } icon: { LIcon(icon).foregroundStyle(.tint) }
        }
    }

    @ViewBuilder private var suggestionList: some View {
        Section {
            ForEach(suggestions) { e in
                Button { lookup = LookupTerm(term: e.w) } label: {
                    HStack {
                        Text(e.w).font(.app(.headline)).foregroundStyle(.primary)
                        Text(e.zh.first ?? "").foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if Library.word(e.w, in: ctx) != nil { LIcon("checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("已收藏") }
                    }
                }
            }
            if suggestions.first?.w != query.lowercased() {
                Button(action: submit) {
                    Label { Text("查詢「\(query)」") } icon: { LIcon("magnifyingglass") }
                }
            }
        }
    }

    /// Recently added words; swipe or long-press to delete.
    @ViewBuilder private var recentList: some View {
        if recent.isEmpty {
            Text("還沒有新增任何字。在上方搜尋，或拍下課本、講義、螢幕截圖。").font(.app(.subheadline)).foregroundStyle(.secondary)
        } else {
            ForEach(recent.prefix(60)) { w in
                Button { detail = w } label: {
                    LabeledContent {
                        Text(w.primaryMeaning).lineLimit(1)
                    } label: {
                        Text(w.term).foregroundStyle(.primary)
                    }
                }
                .swipeActions {
                    Button("刪除", pulso: "trash", role: .destructive) { Library.remove(w, in: ctx) }
                }
                .contextMenu {
                    Button("念出來", pulso: "speaker.wave.2") { Speech.say(w.term) }
                    Button("刪除", pulso: "trash", role: .destructive) { Library.remove(w, in: ctx) }
                }
            }
        }
    }

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        if q.unicodeScalars.contains(where: { $0.value > 0x2E80 }), let first = suggestions.first {
            lookup = LookupTerm(term: first.w)
        } else {
            lookup = LookupTerm(term: q.lowercased())
        }
    }

    private func recognize(_ image: UIImage) async {
        busy = true
        defer { busy = false }
        guard let r = await PhotoScanner.scan(image) else { return }
        if r.tokens.isEmpty {
            candidates = OCRCandidates(text: "", fromFile: false)   // shows "沒有找到英文單字"
        } else {
            try? await Task.sleep(for: .milliseconds(350))   // let the camera / picker finish dismissing
            scan = r
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

// MARK: - OCR / file candidates

struct OCRCandidates: Identifiable {
    let id = UUID()
    var known: [DictEntry] = []
    var unknown: [(term: String, meaning: String)] = []

    static let stopwords: Set<String> = ["the", "and", "for", "are", "was", "were", "with", "that", "this", "from", "have", "has",
        "you", "your", "his", "her", "its", "our", "their", "they", "them", "she", "him", "but", "not", "all", "can", "will",
        "would", "should", "could", "into", "about", "there", "here", "what", "when", "where", "which", "who", "how", "than",
        "then", "also", "very", "just", "been", "being", "had", "did", "does", "out", "one", "two", "some", "any", "more",
        "a", "an", "is", "be", "am", "to", "of", "in", "on", "at", "by", "it", "as", "or", "if", "so", "do", "we", "my", "me", "us",
        "i", "he", "no", "up", "go", "many", "much", "every", "make"]

    init(text: String, fromFile: Bool) {
        var seen = Set<String>()
        for rawLine in text.components(separatedBy: .newlines) {
            if fromFile, rawLine.contains(",") || rawLine.contains("\t") {
                let parts = rawLine.components(separatedBy: CharacterSet(charactersIn: ",\t"))
                let term = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let meaning = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                guard !term.isEmpty, seen.insert(term).inserted else { continue }
                if let e = Dictionary_.lookup(term) { known.append(e) } else { unknown.append((term, meaning)) }
                continue
            }
            for token in rawLine.components(separatedBy: CharacterSet.letters.inverted) {
                let t = token.lowercased()
                guard t.count >= 3, t.allSatisfy({ $0.isASCII }), !Self.stopwords.contains(t), seen.insert(t).inserted else { continue }
                if let e = Dictionary_.lookup(t) {
                    if !known.contains(e) { known.append(e) }
                } else {
                    unknown.append((t, ""))
                }
            }
        }
    }
}

struct OCRPickerView: View {
    let candidates: OCRCandidates
    var destination: WordList?
    var onDone: (Int) -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<String>()

    var body: some View {
        NavigationStack {
            List { Group {
                if candidates.known.isEmpty && candidates.unknown.isEmpty {
                    EmptyState("沒有找到英文單字", icon: "text.viewfinder", message: "換一張更清楚的照片再試一次。")
                }
                if !candidates.known.isEmpty {
                    Section("字典裡有的單字") {
                        ForEach(candidates.known) { e in row(e.w, e.zh.first ?? "", level: levelLabel(e.lv)) }
                    }
                }
                if !candidates.unknown.isEmpty {
                    Section {
                        ForEach(candidates.unknown, id: \.term) { u in
                            row(u.term, u.meaning.isEmpty ? WordTranslator.shared.cached(u.term)?.meanings.joined(separator: "・") ?? "" : u.meaning, level: nil)
                        }
                    } header: { Text("其他字") } footer: {
                        if WordTranslator.shared.provider != .none { Text("沒有中文意思的字，加入後會用 AI 自動翻譯。") }
                    }
                }
            }.listRowBackground(Color.cardFill) }.themedBackground()
            .navigationTitle("選擇要加入的字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入 \(selected.count) 個") { addSelected() }.disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(selected.count == candidates.known.count ? "全不選" : "選取字典字") {
                        selected = selected.count == candidates.known.count ? [] : Set(candidates.known.map(\.w))
                    }
                }
            }
            .onAppear { selected = Set(candidates.known.map(\.w)) }
        }
    }

    private func row(_ term: String, _ meaning: String, level: String?) -> some View {
        Button {
            if selected.contains(term) { selected.remove(term) } else { selected.insert(term) }
        } label: {
            HStack {
                LIcon(selected.contains(term) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(term) ? Color.themeAccent : .secondary)
                Text(term).font(.app(.headline))
                Text(meaning).foregroundStyle(.secondary)
                Spacer()
                if let level { Text(level).font(.app(.caption, .bold)).foregroundStyle(.secondary) }
            }
        }.foregroundStyle(.primary)
    }

    private func addSelected() {
        var n = 0
        for e in candidates.known where selected.contains(e.w) { Library.add(e, to: destination, in: ctx); n += 1 }
        var untranslated: [Word] = []
        for u in candidates.unknown where selected.contains(u.term) {
            if u.meaning.isEmpty, let ai = WordTranslator.shared.cached(u.term) {
                Library.add(ai.entry(for: u.term), to: destination, in: ctx)
            } else {
                let w = Library.add(.custom(u.term, meaning: u.meaning), to: destination, in: ctx)
                if u.meaning.isEmpty { untranslated.append(w) }
            }
            n += 1
        }
        WordTranslator.shared.fill(untranslated, in: ctx)
        onDone(n)
        dismiss()
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
