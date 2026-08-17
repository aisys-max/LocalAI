import Foundation
import UIKit

extension AppModel {
    /// The synthetic greeting Message a Chat opens with, worded against
    /// whichever Backend/Model is *currently* selected — used both when
    /// starting a new Chat and when restoring a loaded Chat's greeting
    /// (never persisted; see `restoreGreetings()`).
    func greetingMessage(forChatId chatId: String, createdAt: Date) -> ChatMessage {
        let greeting = strings.greeting(backendLabel: backend.label, model: model, language: language)
        return ChatMessage(id: chatId + "-g", role: .assistant, text: greeting, model: model, isGreeting: true, createdAt: createdAt)
    }

    /// Re-inserts a fresh greeting Message as the first Message of every
    /// loaded Chat — greetings are never persisted (`persistChat(_:)`
    /// strips them before saving), so a Chat loaded from storage needs one
    /// synthesized back in. Called once at launch, before any UI reads
    /// `chats`.
    func restoreGreetings() {
        for (id, chat) in chats {
            var restored = chat
            let realMessages = chat.messages.filter { !$0.isGreeting }.sorted { $0.createdAt < $1.createdAt }
            restored.messages = [greetingMessage(forChatId: id, createdAt: chat.createdAt)] + realMessages
            chats[id] = restored
        }
    }

    /// Saves one Chat (by id) to the persistence store — scoped to just
    /// that Chat, not a whole-store rewrite — stripping its Greeting
    /// Message first (synthesized fresh on load, never stored). Called at
    /// well-defined mutation points — never per streamed chunk, so an
    /// interrupted in-flight Generation never leaves a partial assistant
    /// Message on disk. No-op if `chatId` isn't in `chats` (e.g. already
    /// deleted — see `deleteChats(in:)`, which uses `deleteChat(id:)` instead).
    func persistChat(_ chatId: String) {
        guard let chat = chats[chatId] else { return }
        var sanitized = chat
        sanitized.messages = chat.messages.filter { !$0.isGreeting }
        persistenceStore.saveChat(sanitized)
    }

    func newChat() {
        let id = "c\(Int(Date().timeIntervalSince1970 * 1000))"
        let createdAt = Date()
        let greeting = greetingMessage(forChatId: id, createdAt: createdAt)
        let chat = Chat(
            id: id, createdAt: createdAt, title: strings.newChat,
            snippet: String(greeting.text.prefix(60)),
            messages: [greeting]
        )
        chats[id] = chat
        // Persisted before `currentChatId` points at it: if the app is
        // killed between the two (separate) saves, a stale-but-valid
        // `currentChatId` beats a `currentChatId` dangling at a Chat that
        // was never actually written to disk.
        persistChat(id)
        currentChatId = id
        screen = .chat
    }

    @discardableResult
    func sendMessage() -> Task<Void, Never>? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !generating, let chatId = currentChatId, var chat = chats[chatId] else { return nil }

        let isFirstUser = !chat.messages.contains { $0.role == .user }
        chat.messages.append(ChatMessage(id: "m\(Int(Date().timeIntervalSince1970 * 1000))", role: .user, text: text))
        if isFirstUser { chat.title = String(text.prefix(40)) }
        chat.snippet = String(text.prefix(60))
        chats[chatId] = chat
        persistChat(chatId)

        draft = ""

        // No Model selected yet (still loading, or the fetch failed) — the
        // user's message stays posted, but there's nothing to send it to.
        guard let model else { return nil }
        generating = true

        return streamReply(chatId: chatId, model: model, messages: chat.messages, delayNanoseconds: 1_100_000_000)
    }

    @discardableResult
    func regenerate(chatId: String, messageId: String) -> Task<Void, Never>? {
        // Matches sendMessage()'s `!generating` guard — without it, tapping
        // Regenerate while a reply is still streaming starts a second
        // `streamReply` racing the first; whichever finishes last would
        // overwrite the other's persisted result via `persistChat(_:)`.
        guard !generating, var chat = chats[chatId] else { return nil }
        chat.messages.removeAll { $0.id == messageId }
        chats[chatId] = chat
        persistChat(chatId)

        // See sendMessage() — no Model selected yet, nothing to regenerate with.
        guard let model else { return nil }
        generating = true

        return streamReply(chatId: chatId, model: model, messages: chat.messages, delayNanoseconds: 900_000_000)
    }

    /// Streams an assistant reply into a new `ChatMessage`, appending it on the
    /// first chunk and growing its text as further chunks arrive. `messages` is
    /// the conversation so far, sent to the backend as context for the reply.
    /// Returns the underlying `Task` so callers (namely tests) can await
    /// completion deterministically instead of guessing at a sleep duration.
    private func streamReply(chatId: String, model: String, messages: [ChatMessage], delayNanoseconds: UInt64) -> Task<Void, Never> {
        let assistantId = UUID().uuidString
        return Task {
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
            // One save for the whole Generation, here at the end — not per
            // chunk (`appendReplyChunk`/`beginReply` don't persist), so an
            // app kill mid-stream never leaves a partial assistant Message
            // on disk.
            await MainActor.run {
                self.generating = false
                self.persistChat(chatId)
            }
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
        persistChat(chatId)
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
        deleteChats(withIds: idsToDelete)
    }

    /// Removes every Chat older than `retentionPeriod` (by `createdAt`) —
    /// the automatic counterpart to the manual `deleteChats(in:)` above,
    /// independent of it and using the same Chat-granularity deletion.
    /// Called once at launch, and immediately whenever `retentionPeriod`
    /// is shortened in Settings (see `setRetentionPeriod(_:)`) — a no-op
    /// if nothing is out of the window. Deliberately not re-checked on a
    /// foreground resume within an already-running session — a Chat that
    /// crosses the cutoff mid-session waits for the next full launch, per
    /// the "checked once per app launch" scope this was built to.
    func pruneExpiredChats(now: Date = Date(), calendar: Calendar = .current) {
        let cutoff = retentionPeriod.cutoffDate(now: now, calendar: calendar)
        let idsToDelete = chats.values
            .filter { $0.createdAt < cutoff }
            .map(\.id)
        let currentChatWasPruned = currentChatId.map(idsToDelete.contains) ?? false
        deleteChats(withIds: idsToDelete)

        // If the open Chat was the one pruned but others survive, there's
        // no chat-switcher UI to fall back to one of them (see CONTEXT.md's
        // Chat entry — only one Chat is ever "current"). Start a fresh one
        // instead, matching how the app already handles this after a
        // manual bulk delete (ChatView always calls `newChat()` next) —
        // otherwise `screen` would stay `.chat` with no Chat selected.
        if currentChatWasPruned && !chats.isEmpty {
            newChat()
        }
    }

    /// Shared by `deleteChats(in:)` and `pruneExpiredChats()`: removes the
    /// given Chats from memory, reconciles `currentChatId` if it pointed at
    /// one of them, then persists the deletions. `currentChatId` is
    /// reconciled (and persisted, via its own `didSet`) *before* the Chats
    /// themselves are deleted below: if the app is killed in between, disk
    /// ends up with a `currentChatId` that's still valid (or already nil)
    /// alongside some not-yet-deleted Chats — orphaned data, not a
    /// dangling reference.
    private func deleteChats(withIds idsToDelete: [String]) {
        // No early-return on an empty `idsToDelete`: the currentChatId
        // reconciliation below must still run unconditionally, exactly as
        // it did before this helper was extracted — it's a self-healing
        // check independent of whether *this* call found anything to delete.
        for id in idsToDelete {
            chats.removeValue(forKey: id)
        }
        if let currentChatId, !chats.keys.contains(currentChatId) {
            self.currentChatId = nil
        }
        for id in idsToDelete {
            persistenceStore.deleteChat(id: id)
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
