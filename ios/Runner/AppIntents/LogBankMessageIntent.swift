import AppIntents
import Foundation

@available(iOS 16.0, *)
struct LogBankMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Bank Message"
    static var description = IntentDescription("Send a banking SMS message to Zakah Wealth Smart Capture.")
    static var openAppWhenRun = false

    @Parameter(title: "Message Content", description: "The bank message text")
    var messageContent: String

    @MainActor
    func perform() async throws -> some IntentResult {
        NSLog("[Shortcut] Intent received")
        NSLog("[Shortcut] Length: \(messageContent.count)")
        NSLog(
            "[Shortcut] First 100 chars: \(String(messageContent.prefix(100)))"
        )
        NSLog("[Shortcut] perform() started")

        let trimmed = messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldProcess = !trimmed.isEmpty && messageContent.count <= 10_000
        if shouldProcess {
            if AppDelegate.enqueueShortcutMessage(messageContent) {
                NSLog("[Shortcut] Payload queued")
                NSLog("[Shortcut] Awaiting Flutter delivery")
            } else {
                NSLog("[Shortcut] Payload rejected")
            }
        } else {
            NSLog("[Shortcut] Intent ignored: empty or too large")
        }
        NSLog("[Shortcut] perform() completed")
        return .result()
    }
}
