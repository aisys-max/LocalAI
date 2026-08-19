import SwiftUI

struct MessageBubbleView: View {
    @ObservedObject var model: AppModel
    let message: ChatMessage
    let theme: Theme

    private var isUser: Bool { message.role == .user }

    /// The (Model, Backend) this specific Message was actually generated
    /// with — frozen at the time, same as `ChatMessage.backend`'s Greeting
    /// usage — not the currently selected one. Falls back to
    /// `noModelSelected` for a Message generated (or, for a legacy Message,
    /// persisted) with no Model, and omits the Backend half for a Message
    /// that predates `ChatMessage.backend`.
    private var modelBackendLabel: String {
        let modelText = message.model ?? model.strings.noModelSelected
        guard let backend = message.backend else { return modelText }
        return "\(modelText) · \(backend.label)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isUser {
                Button {
                    model.openModelPicker(from: .chat)
                } label: {
                    Text(modelBackendLabel.uppercased())
                        .font(AppFont.body(10.5, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(theme.accent2)
                }
                .buttonStyle(.plain)
            }

            ForEach(MessageParsing.blocks(from: message.text)) { block in
                switch block {
                case .code(_, let text):
                    Text(text)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Palette.Neutral.n100)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.Neutral.n900))
                case .text(_, let parts):
                    inlineText(parts)
                        .font(AppFont.body(14.5))
                        .foregroundStyle(isUser ? theme.onAccentText : theme.text)
                }
            }

            if !isUser {
                HStack(spacing: 14) {
                    Button {
                        model.copyMessage(id: message.id, text: message.text)
                    } label: {
                        Label(model.copiedId == message.id ? model.strings.copied : model.strings.copy, systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let chatId = model.currentChatId {
                            model.regenerate(chatId: chatId, messageId: message.id)
                        }
                    } label: {
                        Label(model.strings.regenerate, systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                }
                .font(AppFont.body(11.5))
                .foregroundStyle(theme.textMuted)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .chatBubbleStyle(isUser: isUser, theme: theme, cornerRadius: 20, maxWidth: 320)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func inlineText(_ parts: [InlinePart]) -> Text {
        parts.reduce(Text("")) { acc, part in
            let piece = part.bold ? Text(part.text).fontWeight(.bold) : Text(part.text)
            return Text("\(acc)\(piece)")
        }
    }
}
