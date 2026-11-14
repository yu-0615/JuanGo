import AppIntents
import SwiftUI

/// Hands a request from outside the app (a Siri / Spotlight / Shortcuts action) to the screens.
@MainActor @Observable
final class AppRouter {
    static let shared = AppRouter()
    /// Set by 開始今日學習: the home tab opens today's round and clears it.
    var startToday = false
    #if DEBUG
    /// `SIMCTL_CHILD_JUANGO_INTENT=1`: behave as if 開始今日學習 had just been run.
    private init() { startToday = ProcessInfo.processInfo.environment["JUANGO_INTENT"] != nil }
    #endif
}

/// 「開始今日學習」 from Siri, Spotlight, the Shortcuts app or the Action button.
struct StartTodayIntent: AppIntent {
    static var title: LocalizedStringResource { "開始今日學習" }
    static var description: IntentDescription { IntentDescription("打開 JuanGo，開始今天要複習的字和新字。") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.startToday = true
        return .result()
    }
}

struct JuanGoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTodayIntent(),
                    phrases: ["用 \(.applicationName) 開始今日學習", "在 \(.applicationName) 背單字", "Start studying in \(.applicationName)"],
                    shortTitle: "今日學習", systemImageName: "play.fill")
    }
}
