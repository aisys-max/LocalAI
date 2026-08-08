import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            SubHeader(title: model.strings.historyTitle, theme: theme, onBack: { model.goChat() }) {
                IconButtonView(systemName: "plus", theme: theme) { model.newChat() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.historyGroups, id: \.day) { group in
                        Text(group.label.uppercased())
                            .font(AppFont.body(11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.textMuted)
                            .padding(.top, 18)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 2)

                        ForEach(group.chats) { chat in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chat.title)
                                    .font(AppFont.body(14.5, weight: .semibold))
                                    .foregroundColor(theme.text)
                                Text(chat.snippet)
                                    .font(AppFont.body(12.5))
                                    .foregroundColor(theme.textMuted)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface))
                            .padding(.bottom, 8)
                            .contentShape(Rectangle())
                            .onTapGesture { model.openChat(chat.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(theme.bg.ignoresSafeArea())
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
