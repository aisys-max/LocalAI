import Foundation
import UIKit

extension AppModel {
    /// A greeting Message worded against whichever Backend/Model is
    /// *currently* selected — used both when starting a new Chat and when
    /// bootstrapping a legacy Chat that predates persisted greetings (see
    /// `bootstrapMissingGreetings()`). Identity is a fresh UUID per
    /// occurrence, not derived from the Chat it belongs to, since a Chat can
    /// end up holding more than one greeting over its lifetime.
    func greetingMessage(createdAt: Date) -> ChatMessage {
        let greeting = strings.greeting(backendLabel: backend.label, model: model, language: language)
        return ChatMessage(id: UUID().uuidString, role: .assistant, text: greeting, model: model, backend: backend, isGreeting: true, createdAt: createdAt)
    }

    /// One-time bootstrap for Chats that predate persisted greetings: any
    /// loaded Chat with zero greeting Messages gets exactly one synthesized
    /// (worded against the currently selected Backend/Model) and persisted
    /// immediately — the same treatment `newChat()` already gives a brand
    /// new Chat. A Chat that already has a greeting is left untouched, so
    /// this never rewrites or duplicates one. Called once at launch, before
    /// any UI reads `chats`.
    func bootstrapMissingGreetings() {
        for (id, chat) in chats {
            guard !chat.messages.contains(where: { $0.isGreeting }) else { continue }
            var bootstrapped = chat
            // `chat.messages` is already `createdAt`-ordered (guaranteed by
            // `PersistenceStore.loadChats()`), so prepending here is enough.
            bootstrapped.messages = [greetingMessage(createdAt: chat.createdAt)] + chat.messages
            chats[id] = bootstrapped
            persistChat(id)
        }
    }

    /// Called from `goChat()` — the single "return to Chat" choke point —
    /// once at launch (for the case where the app is killed mid-Settings
    /// before the user ever taps back), and from `loadModels()`'s
    /// successful-resolution branch, gated on `screen == .chat` there (a
    /// Model-list fetch kicked off by a Backend/Model switch can resolve
    /// after the user has already returned to Chat — that catch-up path is
    /// what actually keeps the Greeting from going stale on a slow/remote
    /// network). Keeps the current Chat's Greeting history an accurate
    /// record of which Backend/Model actually produced each stretch of
    /// conversation. Compares the currently selected (Backend, Model)
    /// against the pair recorded on the Chat's most recent Greeting (not
    /// its full history — switching back to an earlier Backend/Model still
    /// counts as a change). No-op if they match, if the Chat has no
    /// Greeting at all (shouldn't happen post-`bootstrapMissingGreetings()`),
    /// or if no Model is selected yet — `selectBackend(_:)` clears `model`
    /// before a fresh fetch resolves, and reconciling against that
    /// transient `nil` would permanently bake a "no model" Greeting into
    /// history for what's normally a brief window.
    func reconcileGreetingForCurrentChat() {
        guard let chatId = currentChatId, var chat = chats[chatId],
              let lastGreetingIndex = chat.messages.lastIndex(where: { $0.isGreeting }),
              model != nil else { return }
        let lastGreeting = chat.messages[lastGreetingIndex]

        guard let lastBackend = lastGreeting.backend else {
            // Predates the `backend` field — there's no way to tell whether
            // a switch actually happened, so this backfills the field in
            // place rather than guessing at history. Matches
            // `bootstrapMissingGreetings()`'s own rule: only ever add
            // missing information, never rewrite what's already recorded.
            chat.messages[lastGreetingIndex].backend = backend
            chats[chatId] = chat
            persistChat(chatId)
            return
        }

        if lastGreeting.model == nil && lastBackend == backend {
            // The Model wasn't known yet when this Greeting was created —
            // e.g. bootstrapped at launch, or written by `goChat()` while a
            // Backend switch's async Model fetch was still in flight. Now
            // that a Model is known (this function's own top-level guard
            // requires `model != nil`) and the Backend hasn't also changed,
            // this regenerates the Greeting in place rather than treating
            // "we now know the Model" as a real switch worth logging —
            // otherwise every Chat bootstrapped/greeted before its first
            // Model resolves would get a spurious extra Greeting the
            // moment that resolution lands.
            chat.messages[lastGreetingIndex] = greetingMessage(createdAt: lastGreeting.createdAt)
            chats[chatId] = chat
            persistChat(chatId)
            return
        }
        guard lastBackend != backend || lastGreeting.model != model else { return }

        let newGreeting = greetingMessage(createdAt: Date())
        // "Still unstarted" is judged from the Chat's current Messages only
        // — not its full Greeting history. A Chat that had its one real
        // Message swipe-deleted (via ChatView) after multiple Greetings had
        // already accumulated does fall back to replacing, losing that
        // Greeting history — a known, accepted trade-off (matches the
        // original #39 spec: switching Backend/Model on a Chat with zero
        // real Messages right now always replaces, unconditionally).
        let hasHistory = chat.messages.contains(where: { !$0.isGreeting })
        if hasHistory {
            // Real conversation already happened under the old Greeting —
            // append, so it stays in place as a marker of what was true at
            // the time, rather than being overwritten.
            chat.messages.append(newGreeting)
        } else {
            // Still unstarted — an empty Chat only ever shows one, current
            // Greeting, no matter how many times Backend/Model is flipped
            // before the user sends anything.
            chat.messages = [newGreeting]
        }
        chat.snippet = String(newGreeting.text.prefix(60))
        chats[chatId] = chat
        persistChat(chatId)
    }

    /// Detects a Generation interrupted by the app being killed/crashing
    /// mid-stream: since an assistant Message is only ever written once its
    /// stream completes (see `persistChat(_:)`'s call sites — never per
    /// chunk), an interrupted Generation leaves no trace of its own, only a
    /// trailing user Message with no reply after it. Scoped to just the
    /// currently-open Chat (matching how the Generation that could've been
    /// interrupted was itself scoped to one Chat). Reuses the existing
    /// failure-message treatment — no new "interrupted" category — and
    /// persists the inserted failure Message immediately so this doesn't
    /// need to re-detect it on the next launch.
    ///
    /// Requires `model != nil`: `sendMessage()`/`regenerate()` both persist
    /// a trailing user Message *before* checking whether a Model is
    /// selected (see their "no Model selected yet" comments) — that's a
    /// legitimate, un-interrupted state with the exact same on-disk shape
    /// as a real interruption. A real interruption implies a Generation was
    /// actually attempted, which implies a Model was selected at the time;
    /// gating on a currently-available Model is how this tells the two
    /// apart. Called once, after the launch Model-list fetch resolves (not
    /// synchronously in `init`, where `model` isn't populated yet) — see
    /// `AppModel.init`.
    func detectInterruptedGeneration() {
        guard model != nil, let chatId = currentChatId, let chat = chats[chatId],
              let lastMessage = chat.messages.last, lastMessage.role == .user else { return }

        let text = strings.replyFailureMessage(for: .other)
        appendAssistantMessage(chatId: chatId, message: ChatMessage(id: UUID().uuidString, role: .assistant, text: text))
        persistChat(chatId)
    }

    /// Saves one Chat (by id) to the persistence store — scoped to just
    /// that Chat, not a whole-store rewrite. Greeting Messages are saved
    /// like any other Message. Called at well-defined mutation points —
    /// never per streamed chunk, so an interrupted in-flight Generation
    /// never leaves a partial assistant Message on disk. No-op if `chatId`
    /// isn't in `chats` (e.g. already deleted — see `deleteChats(in:)`,
    /// which uses `deleteChat(id:)` instead).
    func persistChat(_ chatId: String) {
        guard let chat = chats[chatId] else { return }
        persistenceStore.saveChat(chat)
    }

    func newChat() {
        let id = "c\(Int(Date().timeIntervalSince1970 * 1000))"
        let createdAt = Date()
        let greeting = greetingMessage(createdAt: createdAt)
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
        appendAssistantMessage(chatId: chatId, message: ChatMessage(id: messageId, role: .assistant, text: chunk, model: model, backend: backend))
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
