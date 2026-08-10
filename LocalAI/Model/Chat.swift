import Foundation

enum ChatDay: String {
    case today, yesterday, previous7
}

enum MessageRole {
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
}

struct Chat: Identifiable {
    let id: String
    var day: ChatDay
    var title: String
    var snippet: String
    var messages: [ChatMessage]
}
