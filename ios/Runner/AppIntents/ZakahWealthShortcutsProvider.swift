import AppIntents

@available(iOS 16.0, *)
struct ZakahWealthShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogBankMessageIntent(),
            phrases: [
                "Log Bank Message in \(.applicationName)",
                "Send Bank Message to \(.applicationName)"
            ],
            shortTitle: "Log Bank Message",
            systemImageName: "message"
        )
    }
}
