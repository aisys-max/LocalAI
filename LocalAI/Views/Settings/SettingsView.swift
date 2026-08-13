import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            SubHeader(title: model.strings.settingsTitle, theme: theme, backLabel: model.strings.back, onBack: { model.goChat() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(model.strings.sectionModel, theme: theme)
                    GroupCard(theme: theme) {
                        SegmentedPillControl(
                            items: Backend.allCases, label: { $0.label },
                            isSelected: { $0 == model.backend },
                            onSelect: { model.selectBackend($0) },
                            theme: theme
                        )
                        .padding(12)

                        GroupRow(theme: theme, isFirst: false) {
                            model.openModelPicker(from: .settings)
                        } content: {
                            Text(model.model ?? model.strings.noModelSelected)
                                .foregroundColor(theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(theme.textMuted)
                        }

                        if model.isRetryingModels {
                            Text(model.strings.retryingAutomatically)
                                .font(AppFont.body(12))
                                .foregroundColor(theme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 13)
                        }
                    }

                    SectionLabel(model.strings.serverAddress, theme: theme)
                    GroupCard(theme: theme) {
                        TextField(model.backend.defaultServerAddress, text: serverAddressBinding)
                            .font(AppFont.body(14.5))
                            .foregroundColor(theme.text)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                    }

                    SectionLabel(model.strings.sectionAppearance, theme: theme)
                    GroupCard(theme: theme) {
                        SegmentedPillControl(
                            items: AppearanceItem.all, label: { $0.label(model.strings) },
                            isSelected: { $0.mode == model.appearance },
                            onSelect: { model.setAppearance($0.mode) },
                            theme: theme
                        )
                        .padding(12)
                    }

                    SectionLabel(model.strings.sectionLanguage, theme: theme)
                    GroupCard(theme: theme) {
                        SegmentedPillControl(
                            items: AppLanguage.allCases, label: { $0.label },
                            isSelected: { $0 == model.language },
                            onSelect: { model.setLanguage($0) },
                            theme: theme
                        )
                        .padding(12)
                    }

                    SectionLabel(model.strings.sectionAbout, theme: theme)
                    GroupCard(theme: theme) {
                        ForEach(Array(LegalKey.allCases.enumerated()), id: \.element) { index, key in
                            GroupRow(theme: theme, isFirst: index == 0) {
                                model.openLegal(key)
                            } content: {
                                Text(legalLabel(key))
                                    .foregroundColor(theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                        Text(model.strings.version)
                            .font(AppFont.body(12))
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().fill(theme.divider).frame(height: 1), alignment: .top)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .sheet(item: $model.legalOpenKey) { key in
            LegalSheetView(model: model, key: key, theme: theme)
        }
    }

    private var serverAddressBinding: Binding<String> {
        Binding(
            get: { model.serverAddress(for: model.backend) },
            set: { model.setServerAddress($0, for: model.backend) }
        )
    }

    private func legalLabel(_ key: LegalKey) -> String {
        switch key {
        case .privacy: return model.strings.privacyPolicy
        case .terms: return model.strings.terms
        case .safety: return model.strings.safety
        case .security: return model.strings.security
        }
    }
}

private struct AppearanceItem: Identifiable {
    let mode: AppearanceMode
    var id: String { mode.id }
    func label(_ s: Strings) -> String {
        switch mode {
        case .light: return s.light
        case .dark: return s.dark
        case .system: return s.system
        }
    }
    static let all: [AppearanceItem] = AppearanceMode.allCases.map { AppearanceItem(mode: $0) }
}

struct SectionLabel: View {
    let text: String
    let theme: Theme
    init(_ text: String, theme: Theme) { self.text = text; self.theme = theme }
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.body(11, weight: .bold))
            .tracking(0.5)
            .foregroundColor(theme.textMuted)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
    }
}

struct GroupCard<Content: View>: View {
    let theme: Theme
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0, content: content)
            .background(RoundedRectangle(cornerRadius: 20).fill(theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct GroupRow<Content: View>: View {
    let theme: Theme
    let isFirst: Bool
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8, content: content)
                .font(AppFont.body(14.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(
                    Group { if !isFirst { Rectangle().fill(theme.divider).frame(height: 1) } },
                    alignment: .top
                )
        }
        .buttonStyle(.plain)
    }
}
