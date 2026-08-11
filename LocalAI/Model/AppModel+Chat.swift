import Foundation
import UIKit

extension AppModel {
    func newChat() {
        let id = "c\(Int(Date().timeIntervalSince1970 * 1000))"
        let greeting = strings.greeting(backendLabel: backend.label, model: model, language: language)
        let chat = Chat(
            id: id, day: .today, title: strings.newChat,
            snippet: String(greeting.prefix(60)),
            messages: [ChatMessage(id: id + "-g", role: .assistant, text: greeting, model: model, isGreeting: true)]
        )
        chats[id] = chat
        currentChatId = id
        screen = .chat
    }

    func openChat(_ id: String) {
        currentChatId = id
        screen = .chat
    }

    func deleteChat(_ id: String) {
        chats.removeValue(forKey: id)
        if currentChatId == id { currentChatId = nil }
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

        // No Model selected yet (still loading, or the fetch failed) — the
        // user's message stays posted, but there's nothing to send it to.
        guard let model else { return }
        generating = true

        streamReply(chatId: chatId, model: model, messages: chat.messages, delayNanoseconds: 1_100_000_000)
    }

    func regenerate(chatId: String, messageId: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.removeAll { $0.id == messageId }
        chats[chatId] = chat

        // See sendMessage() — no Model selected yet, nothing to regenerate with.
        guard let model else { return }
        generating = true

        streamReply(chatId: chatId, model: model, messages: chat.messages, delayNanoseconds: 900_000_000)
    }

    /// Streams an assistant reply into a new `ChatMessage`, appending it on the
    /// first chunk and growing its text as further chunks arrive. `messages` is
    /// the conversation so far, sent to the backend as context for the reply.
    private func streamReply(chatId: String, model: String, messages: [ChatMessage], delayNanoseconds: UInt64) {
        let assistantId = UUID().uuidString
        Task {
            var started = false
            do {
                for try await chunk in backendClient.generateReply(chatId: chatId, model: model, messages: messages, baseURL: currentServerURL, delayNanoseconds: delayNanoseconds) {
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

extension Chat {
    /// The first exchange in the chat — the User's first message (if they've
    /// sent one yet) and the Assistant reply that answered it, skipping the
    /// opening greeting — used for the History preview card.
    var previewExchange: (user: ChatMessage?, assistant: ChatMessage?) {
        guard let userIndex = messages.firstIndex(where: { $0.role == .user }) else {
            return (nil, messages.first(where: { $0.role == .assistant }))
        }
        let user = messages[userIndex]
        let assistant = messages[(userIndex + 1)...].first(where: { $0.role == .assistant })
        return (user, assistant)
    }
}
