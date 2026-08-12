import Foundation
import UIKit

extension AppModel {
    func newChat() {
        let id = "c\(Int(Date().timeIntervalSince1970 * 1000))"
        let greeting = strings.greeting(backendLabel: backend.label, model: model, language: language)
        let chat = Chat(
            id: id, createdAt: Date(), title: strings.newChat,
            snippet: String(greeting.prefix(60)),
            messages: [ChatMessage(id: id + "-g", role: .assistant, text: greeting, model: model, isGreeting: true)]
        )
        chats[id] = chat
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
                await MainActor.run {
                    self.appendFailureMessage(chatId: chatId, error: error)
                }
            }
            await MainActor.run { self.generating = false }
        }
    }

    private func beginReply(chatId: String, messageId: String, chunk: String) {
        appendAssistantMessage(chatId: chatId, message: ChatMessage(id: messageId, role: .assistant, text: chunk, model: model))
    }

    private func appendReplyChunk(chatId: String, messageId: String, chunk: String) {
        guard var chat = chats[chatId], let index = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        chat.messages[index].text += chunk
        chat.snippet = String(chat.messages[index].text.prefix(60))
        chats[chatId] = chat
    }

    private func appendFailureMessage(chatId: String, error: Error) {
        let text = strings.replyFailureMessage(for: classifyChatReplyFailure(error))
        appendAssistantMessage(chatId: chatId, message: ChatMessage(id: UUID().uuidString, role: .assistant, text: text))
    }

    private func appendAssistantMessage(chatId: String, message: ChatMessage) {
        guard var chat = chats[chatId] else { return }
        chat.messages.append(message)
        chat.snippet = String(message.text.prefix(60))
        chats[chatId] = chat
    }

    func deleteMessage(chatId: String, messageId: String) {
        guard var chat = chats[chatId] else { return }
        chat.messages.removeAll { $0.id == messageId }
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

    func deleteChats(in range: ChatDeleteRange, now: Date = Date(), calendar: Calendar = .current) {
        let idsToDelete = chats.values
            .filter { isChat($0, in: range, now: now, calendar: calendar) }
            .map(\.id)
        for id in idsToDelete {
            chats.removeValue(forKey: id)
        }
        if let currentChatId, !chats.keys.contains(currentChatId) {
            self.currentChatId = nil
        }
    }

    private func isChat(_ chat: Chat, in range: ChatDeleteRange, now: Date, calendar: Calendar) -> Bool {
        switch range {
        case .today:
            return chatDayBucket(for: chat.createdAt, now: now, calendar: calendar) == .today
        case .sinceYesterday:
            let bucket = chatDayBucket(for: chat.createdAt, now: now, calendar: calendar)
            return bucket == .today || bucket == .yesterday
        case .thisWeek:
            return isChat(chat, in: .sinceYesterday, now: now, calendar: calendar)
                || calendar.isDate(chat.createdAt, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth:
            return isChat(chat, in: .thisWeek, now: now, calendar: calendar)
                || calendar.isDate(chat.createdAt, equalTo: now, toGranularity: .month)
        case .all:
            return true
        }
    }
}

/// The bucket a chat's `createdAt` falls into for the range-based bulk
/// delete (Chat View's trash icon) — computed live at call time (not
/// stored). `now`/`calendar` are injectable for deterministic tests.
func chatDayBucket(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> ChatDay {
    if calendar.isDate(date, inSameDayAs: now) { return .today }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
        return .yesterday
    }
    return .previous7
}

/// The 5 selectable ranges for Chat View's trash-icon bulk-delete —
/// cumulative supersets, Today ⊆ Since Yesterday ⊆ This Week ⊆ This Month ⊆ All.
enum ChatDeleteRange: CaseIterable {
    case today, sinceYesterday, thisWeek, thisMonth, all
}
