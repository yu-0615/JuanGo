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
    @State private var detail: Word?
    @State private var destination: WordList?
    @State private var toast: String?
    @State private var showSettings = false
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
            VStack(alignment: .leading, spacing: 14) {
                searchBar
                if focused || !query.isEmpty {
                    suggestionList
                } else {
                    sourceTiles
                    Text("最近新增").font(.system(.title3).weight(.bold)).padding(.top, 6)
                    recentList
                }
                if let toast {
                    Toast(text: toast, action: nil) { withAnimation { self.toast = nil } }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .overlay { if busy { ProgressView("正在辨識文字…").padding(24).background(.regularMaterial, in: .rect(cornerRadius: Radius.lg)) } }
            .navigationTitle("新增")
            .toolbar { ToolbarItem { Button("設定", pulso: "slider.horizontal.3") { showSettings = true } } }
            .themedBackground()
            .sheet(item: $detail) { w in NavigationStack { WordDetailView(word: w) } }
            .sheet(item: $lookup) { item in
                WordConfirmSheet(term: item.term, destination: destination) { w in
                    query = ""; focused = false
                    withAnimation { toast = destination.map { "已加入「\($0.name)」" } ?? "已加入我的單字" }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
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
            .task {   // simulator testing: SIMCTL_CHILD_LEXI_SCAN_IMAGE=/path/to/page.jpg
                if let p = ProcessInfo.processInfo.environment["LEXI_SCAN_IMAGE"], let img = UIImage(contentsOfFile: p) { await recognize(img) }
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
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .text]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) { candidates = OCRCandidates(text: text, fromFile: true) }
            }
        }
    }

    /// A boxed field with the destination picker written out underneath.
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LIcon("text.cursor").font(.headline).foregroundStyle(.tint)
                TextField("輸入英文單字或中文意思", text: $query)
                    .font(.system(size: 18, weight: .medium))
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { submit() }
                if !query.isEmpty {
                    Button { query = "" } label: { LIcon("xmark.circle.fill") }.foregroundStyle(.secondary)
                }
                Button(action: submit) {
                    LIcon("arrow.right").font(.headline).foregroundStyle(Color.onAccent)
                        .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.themeAccent))
                }
                .disabled(query.isEmpty).opacity(query.isEmpty ? 0.4 : 1)
            }
            .padding(.leading, 14).padding(.trailing, 8).frame(height: 54)
            .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.cardFill))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(focused ? Color.themeAccent : Color.hairline, lineWidth: focused ? 2 : 1))
            Menu {
                Button { destination = nil } label: { Label("我的單字", pulso: destination == nil ? "checkmark" : "character.book.closed") }
                ForEach(lists) { l in
                    Button { destination = l } label: { Label(l.name, pulso: destination == l ? "checkmark" : "folder") }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("存到").foregroundStyle(.secondary)
                    Text(destination?.name ?? "我的單字").fontWeight(.bold)
                    LIcon("chevron.up.chevron.down").font(.caption2)
                }
                .font(.footnote)
            }
            .padding(.leading, 4)
        }
    }

    /// Three ways to bring words in, as equal tiles.
    private var sourceTiles: some View {
        HStack(spacing: 10) {
            sourceTile("拍照掃描", "camera.viewfinder") { showCamera = true }
            sourceTile("從相簿", "photo.stack") { showPhotoPicker = true }
            sourceTile("匯入檔案", "doc.text") { showFileImporter = true }
        }
    }

    private func sourceTile(_ t: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                LIcon(icon).font(.title2.weight(.semibold)).foregroundStyle(.tint)
                    .frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.themeAccent.opacity(0.1)))
                Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var suggestionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("輸入英文單字或中文意思").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
                }
                ForEach(suggestions) { e in
                    Button { lookup = LookupTerm(term: e.w) } label: {
                        HStack {
                            Text(e.w).font(.headline)
                            Text(e.zh.first ?? "").foregroundStyle(.secondary)
                            Spacer()
                            if Library.word(e.w, in: ctx) != nil { LIcon("checkmark.circle.fill").foregroundStyle(.green) }
                            LIcon("chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
                if !query.trimmingCharacters(in: .whitespaces).isEmpty && suggestions.first?.w != query.lowercased() {
                    Button(action: submit) {
                        Label("查詢 \(query)", pulso: "magnifyingglass").font(.headline).foregroundStyle(.tint)
                            .padding(.vertical, 12)
                    }.buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Color.hairline))
    }

    /// Recently added words as a wrap of small chips; long-press to delete.
    private var recentList: some View {
        ScrollView {
            if recent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("還沒有新增任何字").font(.headline)
                    Text("在上方輸入，或拍下課本、講義、螢幕截圖。").font(.subheadline).foregroundStyle(.secondary)
                }
                .card()
            } else {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(recent.prefix(60)) { w in
                        Button { detail = w } label: {
                            HStack(spacing: 6) {
                                Text(w.term).font(.subheadline.weight(.bold))
                                Text(w.primaryMeaning).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Color.hairline))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("念出來", pulso: "speaker.wave.2") { Speech.say(w.term) }
                            Button("刪除", pulso: "trash", role: .destructive) { Library.remove(w, in: ctx) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
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
            List {
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
                        ForEach(candidates.unknown, id: \.term) { u in row(u.term, u.meaning, level: nil) }
                    } header: { Text("其他字（加入後可再編輯意思）") }
                }
            }
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
                Text(term).font(.headline)
                Text(meaning).foregroundStyle(.secondary)
                Spacer()
                if let level { Text(level).font(.caption.bold()).foregroundStyle(.secondary) }
            }
        }.foregroundStyle(.primary)
    }

    private func addSelected() {
        var n = 0
        for e in candidates.known where selected.contains(e.w) { Library.add(e, to: destination, in: ctx); n += 1 }
        for u in candidates.unknown where selected.contains(u.term) {
            Library.add(.custom(u.term, meaning: u.meaning), to: destination, in: ctx); n += 1
        }
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
