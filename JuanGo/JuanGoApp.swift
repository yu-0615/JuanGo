import SwiftUI
import SwiftData

@main
struct JuanGoApp: App {
    @State private var settings = AppSettings.shared

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["JUANGO_BACKUP_SELFTEST"] != nil { Backup.selfTest() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .tint(settings.theme.accent)
                .fontDesign(settings.fontDesign)
                .font(.app(.body))
                .task { AppFont.shared.prepare(); AppFont.shared.applyAppearance() }
                .onChange(of: settings.fontStyle) { AppFont.shared.styleChanged() }
                .preferredColorScheme(settings.colorScheme)
                .environment(\.locale, .zh)
        }
        .modelContainer(for: [Word.self, WordList.self, ReviewLog.self])
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    private var cloud: Cloud { .shared }
    /// Debug hook: `SIMCTL_CHILD_JUANGO_ONBOARD=1` shows the onboarding again without resetting settings.
    static var forceOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["JUANGO_ONBOARD"] != nil
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            settings.theme.background.ignoresSafeArea()
            if settings.onboarded && !Self.forceOnboarding {
                MainTabs().transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: settings.onboarded)
        // the emailed sign-in link comes back as juango://login-callback#access_token=…
        .onOpenURL { url in
            if cloud.handle(url), cloud.signedIn {
                Task { if let r = try? await cloud.sync(ctx) { cloud.notice = "已登入 \(cloud.session?.email ?? "")，\(r)" } }
            }
        }
        .onChange(of: phase) { _, p in
            if p == .background {
                cloud.backgroundPush(ctx)
                // skip today's reminder when today's practice is already done
                let start = Calendar.current.startOfDay(for: .now)
                let n = (try? ctx.fetchCount(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.date >= start }))) ?? 0
                Reminders.sync(settings, studiedToday: n > 0)
            }
            if p == .active, cloud.signedIn { Task { try? await cloud.sync(ctx) } }
        }
        .alert(cloud.notice ?? "", isPresented: Binding(get: { cloud.notice != nil }, set: { if !$0 { cloud.notice = nil } })) {
            Button("好") { cloud.notice = nil }
        }
    }
}

enum AppTab: Hashable { case importing, explore, study, words, profile }

struct MainTabs: View {
    @Environment(AppSettings.self) private var settings
    @State private var tab: AppTab = MainTabs.debugTab ?? .study

    /// Debug hook: `SIMCTL_CHILD_JUANGO_TAB=study xcrun simctl launch …` opens that tab.
    static var debugTab: AppTab? {
        switch ProcessInfo.processInfo.environment["JUANGO_TAB"] {
        case "explore": .explore
        case "study": .study
        case "words": .words
        case "profile": .profile
        case "import": .importing
        default: nil
        }
    }

    private func tabIcon(_ title: String, _ symbol: String) -> some View {
        Image(systemName: symbol).accessibilityLabel(title)
    }

    var body: some View {
        TabView(selection: $tab) {
            // icons only, no titles under them; the name is still read out by VoiceOver
            Tab(value: AppTab.study) { StudyTab(onFindWords: { tab = .explore }) } label: { tabIcon("主頁", "house.fill") }
            Tab(value: AppTab.explore) { ExploreTab() } label: { tabIcon("探索", "sparkles.rectangle.stack.fill") }
            Tab(value: AppTab.importing) { ImportTab() } label: { tabIcon("新增", "plus.circle.fill") }
            Tab(value: AppTab.words) { WordsTab() } label: { tabIcon("字庫", "character.book.closed.fill") }
            Tab(value: AppTab.profile) { ProfileTab() } label: { tabIcon("我的", "person.crop.circle.fill") }
        }
        .tabBarMinimizeBehavior(.never)   // the tab bar always stays full size
        .task {
            migrateLevels()
            tidyScannedWords()
            redoExamplesWithoutTheWord()
            ExampleStore.shared.container = ctx.container
            ExampleStore.shared.warmUp()   // load the model now, not when the first card asks for a sentence
            // saved words are filled in a moment later, so a card opened right away isn't queued behind them
            try? await Task.sleep(for: .seconds(3))
            ExampleStore.shared.backfill((try? ctx.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.example == "" }))) ?? [])
        }
    }

    @Environment(\.modelContext) private var ctx
    /// Word-list scans used to save OCR leftovers: level marks and legends in the meanings ("藝術形式 *5"),
    /// half-width 、, cut-off brackets, and phonetics glued onto the word ("accuracy takjoresi"). Clean those up.
    private func tidyScannedWords() {
        guard let words = try? ctx.fetch(FetchDescriptor<Word>()) else { return }
        let terms = Set(words.map(\.term))
        var changed = false
        for w in words {
            let meanings = w.meanings   // a colon between two meanings ("重要性:意義") is a separator, like ；
                .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ":：")) }
                .map { GlossaryParser.tidy($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let deduped = meanings.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            if deduped != w.meanings { w.meanings = deduped; changed = true }
            // the dictionary's phonetics were cleaned up (^ɔd → ɡɔd, ' → ˈ, Cyrillic ә → ə): copies saved
            // in the old notation take the new one
            if w.ipa.contains(where: { "'ә^\\є".contains($0) }), let e = Dictionary_.lookup(w.term),
               e.w.lowercased() == w.term.lowercased(), !e.ipa.isEmpty, e.ipa != w.ipa {
                w.ipa = e.ipa; changed = true
            }
            let fixed = GlossaryParser.cleanTerm(w.term)
            guard fixed != w.term, !terms.contains(fixed) else { continue }
            let old = w.term
            w.term = fixed
            for log in (try? ctx.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.term == old }))) ?? [] { log.term = fixed }
            if let e = Dictionary_.lookup(fixed) {
                if w.meanings.isEmpty { w.meanings = e.zh }
                if w.ipa.isEmpty { w.ipa = e.ipa }
                if w.pos.isEmpty { w.pos = e.pos }
            }
            changed = true
        }
        if changed { try? ctx.save() }
    }

    /// Examples written under the old, looser check may not use the word at all ("famed": "She gained fame…"),
    /// which also leaves cloze questions without a blank. Clear those so the backfill below writes new ones
    /// (only where this device can write them), and trim the run-on junk some translations ended with.
    private func redoExamplesWithoutTheWord() {
        guard let words = try? ctx.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.example != "" })) else { return }
        var changed = false
        for w in words {
            let zh = ExampleStore.cleanZh(w.exampleZh)
            if zh != w.exampleZh { w.exampleZh = zh; changed = true }
            if (ExampleStore.isAvailable && !WordMatch.found(w.term, in: w.example)) || GlossaryParser.cleanTerm(w.term) != w.term {
                w.example = ""; w.exampleZh = ""; changed = true
            }
        }
        if changed { try? ctx.save() }
    }

    /// Words saved before v1.1 carry CEFR levels; move them onto the 大考 1–6 scale.
    private func migrateLevels() {
        guard let words = try? ctx.fetch(FetchDescriptor<Word>()) else { return }
        var changed = false
        for w in words where cefrToExam[w.cefr] != nil || w.cefr == "—" {
            if let e = Dictionary_.lookup(w.term) { w.cefr = e.lv } else if let lv = cefrToExam[w.cefr] { w.cefr = lv } else { continue }
            changed = true
        }
        if changed { try? ctx.save() }
    }
}

/// Screen background with the theme tint; used by each tab's NavigationStack.
struct ThemedBackground: ViewModifier {
    @Environment(AppSettings.self) private var settings
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
            .background(settings.theme.background.ignoresSafeArea())
    }
}
extension View { func themedBackground() -> some View { modifier(ThemedBackground()) } }
