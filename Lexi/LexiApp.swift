import SwiftUI
import SwiftData

@main
struct LexiApp: App {
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .tint(settings.theme.accent)
                .fontDesign(settings.fontDesign)
                .preferredColorScheme(settings.colorScheme)
                .environment(\.locale, .zh)
        }
        .modelContainer(for: [Word.self, WordList.self, ReviewLog.self])
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    /// Debug hook: `SIMCTL_CHILD_LEXI_ONBOARD=1` shows the onboarding again without resetting settings.
    static var forceOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["LEXI_ONBOARD"] != nil
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
    }
}

enum AppTab: Hashable { case importing, explore, study, words, profile }

struct MainTabs: View {
    @Environment(AppSettings.self) private var settings
    @State private var tab: AppTab = MainTabs.debugTab ?? .study

    /// Debug hook: `SIMCTL_CHILD_LEXI_TAB=study xcrun simctl launch …` opens that tab.
    static var debugTab: AppTab? {
        switch ProcessInfo.processInfo.environment["LEXI_TAB"] {
        case "explore": .explore
        case "study": .study
        case "words": .words
        case "profile": .profile
        case "import": .importing
        default: nil
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            // Lexi opens on 學習 (home) and labels every tab.
            Tab(value: AppTab.study) { StudyTab(onFindWords: { tab = .explore }) } label: { Label("今天", pulso: "sun.horizon.fill", size: 24) }
            Tab(value: AppTab.explore) { ExploreTab() } label: { Label("探索", pulso: "sparkles.rectangle.stack.fill", size: 24) }
            Tab(value: AppTab.importing) { ImportTab() } label: { Label("新增", pulso: "plus.circle.fill", size: 24) }
            Tab(value: AppTab.words) { WordsTab() } label: { Label("字庫", pulso: "character.book.closed.fill", size: 24) }
            Tab(value: AppTab.profile) { ProfileTab() } label: { Label("我的", pulso: "person.crop.circle.fill", size: 24) }
        }
        .tabBarMinimizeBehavior(.onScrollDown)   // iOS 26: the tab bar shrinks while reading, comes back on scroll up
        .task {
            migrateLevels()
            ExampleStore.shared.container = ctx.container
            ExampleStore.shared.backfill((try? ctx.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.example == "" }))) ?? [])
        }
    }

    @Environment(\.modelContext) private var ctx
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
