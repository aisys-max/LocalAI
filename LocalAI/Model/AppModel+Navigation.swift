import Foundation

extension AppModel {
    func goSettings() {
        screen = .settings
        resumeModelRetryLoopIfNeeded()
    }

    /// Leaving to Chat is the one "stop" signal for the Model-list auto-retry
    /// loop (see `AppModel+Models.swift`) — this is the single choke point
    /// every path back to Chat should go through, rather than duplicating
    /// `stopModelRetryLoop()` at each call site. It's also where a
    /// Backend/Model switch made in Settings/the Model Picker actually lands
    /// on the current Chat, via `reconcileGreetingForCurrentChat()` —
    /// deliberately not at the moment of the switch itself, so flipping
    /// back and forth before returning to Chat doesn't matter.
    func goChat() {
        stopModelRetryLoop()
        reconcileGreetingForCurrentChat()
        screen = .chat
    }

    func openModelPicker(from origin: Screen) {
        returnScreen = origin
        screen = .modelPicker
        resumeModelRetryLoopIfNeeded()
    }

    func closeModelPicker() {
        if returnScreen == .chat {
            goChat()
        } else {
            screen = returnScreen
        }
    }

    func openLegal(_ key: LegalKey) { legalOpenKey = key }
    func closeLegal() { legalOpenKey = nil }
}
