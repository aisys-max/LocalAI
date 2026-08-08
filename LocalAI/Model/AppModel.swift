import SwiftUI
import Combine

enum Screen {
    case onboarding, chat, history, settings, modelPicker
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
}

/// Single ObservableObject driving every screen — a direct port of the design's
/// `Component` state (`this.state`) and actions in `Local AI.dc.html`.
@MainActor
final class AppModel: ObservableObject {
    @Published var screen: Screen = .onboarding
    @Published var onboardingStep: Int = 0
    @Published var returnScreen: Screen = .chat

    @Published var backend: Backend = .ollama
    @Published var model: String

    @Published var appearance: AppearanceMode = .system
    @Published var systemColorScheme: ColorScheme = .light
    @Published var language: AppLanguage = .en

    @Published var chats: [String: Chat]
    @Published var currentChatId: String?

    @Published var draft: String = ""
    @Published var generating: Bool = false
    @Published var legalOpenKey: LegalKey?
    @Published var copiedId: String?

    @Published var tick: Int = 0

    private var copyResetTask: Task<Void, Never>?
    private var tickTimer: Timer?

    init() {
        let seeded = SeedChats.make()
        self.chats = Dictionary(uniqueKeysWithValues: seeded.map { ($0.id, $0) })
        self.model = Backend.ollama.models[0]

        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick += 1 }
        }
    }

    deinit {
        tickTimer?.invalidate()
    }

    var isDark: Bool {
        switch appearance {
        case .dark: return true
        case .light: return false
        case .system: return systemColorScheme == .dark
        }
    }

    var strings: Strings { language.strings }

    // MARK: - Navigation

    func goHistory() { screen = .history }
    func goSettings() { screen = .settings }
    func goChat() { screen = .chat }
    func openModelPicker(from origin: Screen) {
        returnScreen = origin
        screen = .modelPicker
    }
    func closeModelPicker() { screen = returnScreen }

    // MARK: - Backend / model / appearance / language

    func selectBackend(_ b: Backend) {
        backend = b
        model = b.models[0]
    }
    func selectModel(_ m: String) { model = m }
    func setAppearance(_ a: AppearanceMode) { appearance = a }
    func setLanguage(_ l: AppLanguage) { language = l }

    // MARK: - Legal

    func openLegal(_ key: LegalKey) { legalOpenKey = key }
    func closeLegal() { legalOpenKey = nil }

    // MARK: - Onboarding

    func onboardingNext() { onboardingStep += 1 }
    func onboardingBack() { onboardingStep = max(0, onboardingStep - 1) }
    func finishOnboarding() {
        screen = .chat
        newChat()
    }

    // MARK: - Chats

    func newChat() {
        let id = "c\(Int(Date().timeIntervalSince1970 * 1000))"
        let greeting = strings.greeting(backendLabel: backend.label, model: model, language: language)
        let chat = Chat(
            id: id, day: .today, title: strings.newChat,
            snippet: String(greeting.prefix(60)),
            messages: [ChatMessage(id: id + "-g", role: .assistant, text: greeting, model: model)]
        )
        chats[id] = chat
        currentChatId = id
        screen = .chat
    }

    func openChat(_ id: String) {
        currentChatId = id
        screen = .chat
    }

    func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !generating, let chatId = currentChatId, var chat = chats[chatId] else { return }

        let isFirstUser = !chat.messages.contains { $0.role == .user }
        chat.messages.append(ChatMessage(id: "m\(Int(Date().timeIntervalSince1970 * 1000))", role: .user, text: text))
        if isFirstUser { chat.title = String(text.prefix(40)) }
        chat.snippet = String(text.prefix(60))
        chats[chatId] = chat

        draft = ""
        generating = true

        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            await MainActor.run { self.finishReply(chatId: chatId) }
        }
    }

    private func finishReply(chatId: String) {
        guard var chat = chats[chatId] else { generating = false; return }
        let replyText = CannedReplies.random()
        chat.messages.append(ChatMessage(id: "m\(Int(Date().timeIntervalSince1970 * 1000))", role: .assistant, text: replyText, model: model))
        chat.snippet = String(replyText.prefix(60))
        chats[chatId] = chat
        generating = false
    }

    func regenerate(chatId: String, messageId: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.removeAll { $0.id == messageId }
        chats[chatId] = chat
        generating = true

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run { self.finishReply(chatId: chatId) }
        }
    }

    func copyMessage(id: String, text: String) {
        UIPasteboard.general.string = text
        copiedId = id
        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if self.copiedId == id { self.copiedId = nil }
            }
        }
    }

    // MARK: - Derived

    var currentChat: Chat? {
        currentChatId.flatMap { chats[$0] }
    }

    /// Chats grouped by day, ordered today → yesterday → previous7, each newest-first —
    /// mirrors the design's `historyGroups`.
    var historyGroups: [(day: ChatDay, label: String, chats: [Chat])] {
        let order: [ChatDay] = [.today, .yesterday, .previous7]
        let labels: [ChatDay: String] = [.today: strings.today, .yesterday: strings.yesterday, .previous7: strings.previous7]
        return order.compactMap { day in
            let dayChats = chats.values.filter { $0.day == day }
            guard !dayChats.isEmpty else { return nil }
            return (day, labels[day]!, dayChats.sorted { $0.id > $1.id })
        }
    }
}
