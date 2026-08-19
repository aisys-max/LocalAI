import Foundation

enum ChatDay: String {
    case today, yesterday, previous7
}

enum MessageRole: String {
    case user, assistant
}

struct InlinePart: Identifiable {
    let id = UUID()
    let bold: Bool
    let text: String
}

enum MessageBlock: Identifiable {
    case code(id: UUID, text: String)
    case text(id: UUID, parts: [InlinePart])

    var id: UUID {
        switch self {
        case .code(let id, _): return id
        case .text(let id, _): return id
        }
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let role: MessageRole
    var text: String
    var model: String?
    /// Only ever set on a Greeting (see below) — the Backend it was worded
    /// against, alongside `model`, so `AppModel.goChat()` can tell whether
    /// the currently selected (Backend, Model) still matches the Chat's most
    /// recent Greeting without re-parsing its text.
    var backend: Backend?
    /// The synthetic "hi" message a Chat opens with — worded against
    /// whichever Backend/Model was selected at the moment it was shown, then
    /// persisted like any other Message (see `AppModel.greetingMessage`).
    /// Unlike a real generated reply, its identity isn't reused across
    /// occurrences — a Chat accumulates a new one each time `goChat()` finds
    /// the Backend/Model has changed since the Chat's last Greeting (see
    /// `AppModel.reconcileGreetingForCurrentChat()`).
    var isGreeting: Bool = false
    /// Orders Messages within a Chat after a save/reload round-trip — `id`
    /// alone isn't sortable (assistant message ids are random UUIDs).
    var createdAt: Date = Date()
}

struct Chat: Identifiable {
    let id: String
    var createdAt: Date
    var title: String
    var snippet: String
    var messages: [ChatMessage]
}

/// How long a Chat is automatically kept before being pruned — a Settings
/// value, independent of (and not a replacement for) the manual bulk-delete
/// ranges (`ChatDeleteRange`) below. Enforced at Chat granularity via
/// `Chat.createdAt`, same as the manual ranges — never a partial per-Message
/// trim.
enum RetentionPeriod: String, CaseIterable, Identifiable {
    case oneWeek, oneMonth, sixMonths
    var id: String { rawValue }

    /// A Chat created before this date is out of the retention window.
    /// `now`/`calendar` are injectable for deterministic tests, matching
    /// `chatDayBucket`'s pattern below. Falls back to `.distantPast` (never
    /// prune) rather than `now` (prune everything) on the practically-never
    /// case where `calendar.date(byAdding:)` fails — pruning is filtered as
    /// `createdAt < cutoffDate`, so the fail-safe direction is "nothing is
    /// old enough," not "everything is."
    func cutoffDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .oneWeek: return calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? .distantPast
        case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: now) ?? .distantPast
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: now) ?? .distantPast
        }
    }
}
