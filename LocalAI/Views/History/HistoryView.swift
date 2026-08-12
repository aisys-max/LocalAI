import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            SubHeader(title: model.strings.historyTitle, theme: theme, onBack: { model.goChat() }) {
                IconButtonView(systemName: "plus", theme: theme) { model.newChat() }
            }

            List {
                ForEach(model.historyGroups, id: \.day) { group in
                    Section {
                        ForEach(group.chats) { chat in
                            HistoryChatCardView(chat: chat, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { model.openChat(chat.id) }
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        model.deleteChat(chat.id)
                                    } label: {
                                        Label(model.strings.delete, systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(group.label.uppercased())
                            .font(AppFont.body(11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .listRowInsets(EdgeInsets())
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(theme.bg.ignoresSafeArea())
    }
}

/// A History row previewing a chat as a miniature version of its opening
/// exchange — same bubble colors/alignment as `MessageBubbleView` in the
/// Chatting screen, so the preview reads as "this chat, smaller" rather
/// than a differently-styled summary card.
private struct HistoryChatCardView: View {
    let chat: Chat
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let preview = chat.previewExchange
            if let assistant = preview.assistant {
                bubble(text: assistant.text, isUser: false)
            }
            if let user = preview.user {
                bubble(text: user.text, isUser: true)
            }
        }
        .padding(.vertical, 10)
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(AppFont.body(13))
            .foregroundColor(isUser ? theme.onAccentText : theme.text)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .chatBubbleStyle(isUser: isUser, theme: theme, cornerRadius: 16, maxWidth: 240)
    }
}

/// Shared back-chevron / title / trailing-icon header for History, Settings, and Model Picker.
struct SubHeader: View {
    let title: String
    let theme: Theme
    let onBack: () -> Void
    let trailing: AnyView

    init(title: String, theme: Theme, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.theme = theme
        self.onBack = onBack
        self.trailing = AnyView(trailing())
    }

    init(title: String, theme: Theme, onBack: @escaping () -> Void) {
        self.init(title: title, theme: theme, onBack: onBack) {
            Color.clear.frame(width: 36, height: 36)
        }
    }

    var body: some View {
        HStack {
            IconButtonView(systemName: "chevron.left", theme: theme, action: onBack)
            Spacer()
            Text(title)
                .font(AppFont.heading(18))
                .foregroundColor(theme.text)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}
