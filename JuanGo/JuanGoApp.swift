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
            if p == .background { cloud.backgroundPush(ctx) }
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
            stripMeaningMarks()
            ExampleStore.shared.container = ctx.container
            ExampleStore.shared.backfill((try? ctx.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.example == "" }))) ?? [])
        }
    }

    @Environment(\.modelContext) private var ctx
    /// Word-list scans used to keep textbook level marks in the meanings ("藝術形式 *5"); clean those up once.
    private func stripMeaningMarks() {
        guard let words = try? ctx.fetch(FetchDescriptor<Word>()) else { return }
        var changed = false
        for w in words where w.meanings.contains(where: { $0.range(of: "[*＊★☆※]", options: .regularExpression) != nil }) {
            w.meanings = w.meanings.map(GlossaryParser.stripMarks).filter { !$0.isEmpty }
            changed = true
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
