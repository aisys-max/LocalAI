import SwiftUI

struct MessageBubbleView: View {
    @ObservedObject var model: AppModel
    let message: ChatMessage
    let theme: Theme

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isUser, let modelName = message.model {
                Text(modelName.uppercased())
                    .font(AppFont.body(10.5, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(theme.accent2)
            }

            ForEach(MessageParsing.blocks(from: message.text)) { block in
                switch block {
                case .code(_, let text):
                    Text(text)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(Palette.Neutral.n100)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.Neutral.n900))
                case .text(_, let parts):
                    inlineText(parts)
                        .font(AppFont.body(14.5))
                        .foregroundColor(isUser ? theme.onAccentText : theme.text)
                }
            }

            if !isUser {
                HStack(spacing: 14) {
                    Button {
                        model.copyMessage(id: message.id, text: message.text)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                            Text(model.copiedId == message.id ? model.strings.copied : model.strings.copy)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let chatId = model.currentChatId {
                            model.regenerate(chatId: chatId, messageId: message.id)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(model.strings.regenerate)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .font(AppFont.body(11.5))
                .foregroundColor(theme.textMuted)
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
            acc + (part.bold ? Text(part.text).fontWeight(.bold) : Text(part.text))
        }
    }
}
