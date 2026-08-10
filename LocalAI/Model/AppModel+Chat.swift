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

        streamReply(chatId: chatId, delayNanoseconds: 1_100_000_000)
    }

    func regenerate(chatId: String, messageId: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.removeAll { $0.id == messageId }
        chats[chatId] = chat
        generating = true

        streamReply(chatId: chatId, delayNanoseconds: 900_000_000)
    }

    /// Streams an assistant reply into a new `ChatMessage`, appending it on the
    /// first chunk and growing its text as further chunks arrive.
    private func streamReply(chatId: String, delayNanoseconds: UInt64) {
        let assistantId = UUID().uuidString
        Task {
            var started = false
            do {
                for try await chunk in backendClient.generateReply(chatId: chatId, model: model, delayNanoseconds: delayNanoseconds) {
                    await MainActor.run {
                        if started {
                            self.appendReplyChunk(chatId: chatId, messageId: assistantId, chunk: chunk)
                        } else {
                            self.beginReply(chatId: chatId, messageId: assistantId, chunk: chunk)
                            started = true
                        }
                    }
                }
            } catch {
                // Surfacing generation failures to the user is handled separately.
            }
            await MainActor.run { self.generating = false }
        }
    }

    private func beginReply(chatId: String, messageId: String, chunk: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.append(ChatMessage(id: messageId, role: .assistant, text: chunk, model: model))
        chat.snippet = String(chunk.prefix(60))
        chats[chatId] = chat
    }

    private func appendReplyChunk(chatId: String, messageId: String, chunk: String) {
        guard var chat = chats[chatId], let index = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        chat.messages[index].text += chunk
        chat.snippet = String(chat.messages[index].text.prefix(60))
        chats[chatId] = chat
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
