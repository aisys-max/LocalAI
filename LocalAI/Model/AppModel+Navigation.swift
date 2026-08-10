import Foundation

extension AppModel {
    func goHistory() { screen = .history }
    func goSettings() { screen = .settings }
    func goChat() { screen = .chat }
    func openModelPicker(from origin: Screen) {
        returnScreen = origin
        screen = .modelPicker
    }
    func closeModelPicker() { screen = returnScreen }

    func openLegal(_ key: LegalKey) { legalOpenKey = key }
    func closeLegal() { legalOpenKey = nil }
}
