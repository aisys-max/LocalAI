import Foundation
import UIKit

extension AppModel {
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
            let reply = await backendClient.generateReply(chatId: chatId, model: model, delayNanoseconds: 1_100_000_000)
            await MainActor.run { self.finishReply(chatId: chatId, text: reply) }
        }
    }

    func finishReply(chatId: String, text: String) {
        guard var chat = chats[chatId] else { generating = false; return }
        chat.messages.append(ChatMessage(id: "m\(Int(Date().timeIntervalSince1970 * 1000))", role: .assistant, text: text, model: model))
        chat.snippet = String(text.prefix(60))
        chats[chatId] = chat
        generating = false
    }

    func regenerate(chatId: String, messageId: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.removeAll { $0.id == messageId }
        chats[chatId] = chat
        generating = true

        Task {
            let reply = await backendClient.generateReply(chatId: chatId, model: model, delayNanoseconds: 900_000_000)
            await MainActor.run { self.finishReply(chatId: chatId, text: reply) }
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
