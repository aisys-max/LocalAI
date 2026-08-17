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
    /// The synthetic "hi" message a new chat opens with — unlike a real
    /// generated reply, it isn't tied to whatever Engine/Model produced it,
    /// so it's re-rendered against the live Engine/Model instead of the
    /// snapshot captured when the chat was created. Never persisted —
    /// synthesized fresh each time a Chat is loaded/displayed.
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
