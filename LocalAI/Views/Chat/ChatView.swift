import SwiftUI

struct ChatView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(model.strings.appName)
                    .font(AppFont.heading(17))
                    .foregroundStyle(theme.text)
                Spacer()
                IconButtonView(title: model.strings.deleteConversations, systemName: "trash", theme: theme) {
                    model.showDeleteRangeDialog = true
                }
                .confirmationDialog(
                    model.strings.deleteRangeDialogTitle,
                    isPresented: $model.showDeleteRangeDialog,
                    titleVisibility: .visible
                ) {
                    Button(model.strings.deleteRangeToday, role: .destructive) { deleteChatsAndStartFresh(in: .today) }
                    Button(model.strings.deleteRangeSinceYesterday, role: .destructive) { deleteChatsAndStartFresh(in: .sinceYesterday) }
                    Button(model.strings.deleteRangeThisWeek, role: .destructive) { deleteChatsAndStartFresh(in: .thisWeek) }
                    Button(model.strings.deleteRangeThisMonth, role: .destructive) { deleteChatsAndStartFresh(in: .thisMonth) }
                    Button(model.strings.deleteRangeAll, role: .destructive) { model.showDeleteAllConfirmation = true }
                }
                IconButtonView(title: model.strings.settingsTitle, systemName: "gearshape", theme: theme) {
                    model.goSettings()
                }
            }
            .padding(.horizontal, 14)
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
                .scrollDismissesKeyboard(.interactively)
                .padding(.vertical, 8)
                .onChange(of: model.currentChat?.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: model.generating) { _, _ in
                    scrollToBottom(proxy)
                }
                .onAppear {
                    // RootView rebuilds ChatView from scratch on every
                    // screen switch (no persistent navigation stack), so
                    // this List always mounts scrolled to the top — the
                    // `onChange`s above only fire for a count/generating
                    // change that happens *during* this mount's lifetime,
                    // not one that already happened while the user was in
                    // Settings/Model Picker. Scrolling here on every
                    // (re)appearance is what makes returning to Chat land
                    // back on the latest message instead of the top.
                    // Dispatched to the next run loop turn — right on
                    // `onAppear`, the List may not have finished
                    // materializing its rows yet, so `proxy.scrollTo` can
                    // silently target a row that isn't laid out.
                    DispatchQueue.main.async {
                        scrollToBottom(proxy)
                    }
                }
            }

            InputBarView(model: model, theme: theme)
        }
        .background(theme.bg.ignoresSafeArea())
        .alert(
            model.strings.deleteAllConfirmTitle,
            isPresented: $model.showDeleteAllConfirmation
        ) {
            Button(model.strings.cancel, role: .cancel) { }
            Button(model.strings.delete, role: .destructive) {
                deleteChatsAndStartFresh(in: .all)
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
