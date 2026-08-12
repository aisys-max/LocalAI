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
                        model.showDeleteRangeDialog = true
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
                List {
                    if let chat = model.currentChat {
                        ForEach(chat.messages) { msg in
                            MessageBubbleView(model: model, message: msg, theme: theme)
                                .id(msg.id)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        model.deleteMessage(chatId: chat.id, messageId: msg.id)
                                    } label: {
                                        Label(model.strings.delete, systemImage: "trash")
                                    }
                                }
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
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.vertical, 8)
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
            model.strings.deleteRangeDialogTitle,
            isPresented: $model.showDeleteRangeDialog,
            titleVisibility: .visible
        ) {
            Button(model.strings.deleteRangeToday, role: .destructive) { deleteChatsAndStartFresh(in: .today) }
            Button(model.strings.deleteRangeSinceYesterday, role: .destructive) { deleteChatsAndStartFresh(in: .sinceYesterday) }
            Button(model.strings.deleteRangeThisWeek, role: .destructive) { deleteChatsAndStartFresh(in: .thisWeek) }
            Button(model.strings.deleteRangeThisMonth, role: .destructive) { deleteChatsAndStartFresh(in: .thisMonth) }
            Button(model.strings.deleteRangeAll, role: .destructive) { model.pendingDeleteRange = .all }
        }
        .alert(
            model.strings.deleteAllConfirmTitle,
            isPresented: Binding(
                get: { model.pendingDeleteRange != nil },
                set: { if !$0 { model.pendingDeleteRange = nil } }
            )
        ) {
            Button(model.strings.cancel, role: .cancel) { model.pendingDeleteRange = nil }
            Button(model.strings.delete, role: .destructive) {
                if let range = model.pendingDeleteRange {
                    deleteChatsAndStartFresh(in: range)
                }
                model.pendingDeleteRange = nil
            }
        } message: {
            Text(model.strings.deleteAllConfirmMessage)
        }
    }

    private func deleteChatsAndStartFresh(in range: ChatDeleteRange) {
        model.deleteChats(in: range)
        model.newChat()
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
