import SwiftUI

struct ChatView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Text(model.strings.appName)
                        .font(AppFont.heading(17))
                        .foregroundColor(theme.text)
                    Spacer()
                    IconButtonView(systemName: "trash", theme: theme) {
                        model.showDeleteChatConfirmation = true
                    }
                    IconButtonView(systemName: "gearshape", theme: theme) {
                        model.goSettings()
                    }
                }
                .padding(.horizontal, 14)

                Text("\(model.model ?? model.strings.noModelSelected) · \(model.backend.label)")
                    .font(AppFont.body(11.5, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.surface2))
                    .onTapGesture { model.openModelPicker(from: .chat) }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if let chat = model.currentChat {
                            ForEach(chat.messages) { msg in
                                MessageBubbleView(model: model, message: msg, theme: theme)
                                    .id(msg.id)
                            }
                        }
                        if model.generating {
                            HStack {
                                TypingIndicatorView(theme: theme)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(theme.surface))
                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .id("__typing")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: model.currentChat?.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: model.generating) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            InputBarView(model: model, theme: theme)
        }
        .background(theme.bg.ignoresSafeArea())
        .confirmationDialog(
            model.strings.deleteChatConfirmTitle,
            isPresented: $model.showDeleteChatConfirmation,
            titleVisibility: .visible
        ) {
            Button(model.strings.delete, role: .destructive) {
                if let id = model.currentChatId {
                    model.deleteChat(id)
                }
                model.newChat()
            }
        } message: {
            Text(model.strings.deleteChatConfirmMessage)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if model.generating {
                proxy.scrollTo("__typing", anchor: .bottom)
            } else if let last = model.currentChat?.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
