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
                                .foregroundStyle(theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(theme.textMuted)
                                .accessibilityHidden(true)
                        }

                        if model.isRetryingModels {
                            Text(model.strings.retryingAutomatically)
                                .font(AppFont.body(12))
                                .foregroundStyle(theme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 13)
                        }
                    }

                    SectionLabel(model.strings.serverAddress, theme: theme)
                    GroupCard(theme: theme) {
                        TextField(model.backend.defaultServerAddress, text: serverAddressBinding)
                            .font(AppFont.body(14.5))
                            .foregroundStyle(theme.text)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)

                        Text(model.backend.remoteAccessHint(model.language))
                            .font(AppFont.body(12))
                            .foregroundStyle(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 13)
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

                    SectionLabel(model.strings.sectionRetention, theme: theme)
                    GroupCard(theme: theme) {
                        SegmentedPillControl(
                            items: RetentionPeriodItem.all, label: { $0.label(model.strings) },
                            isSelected: { $0.period == model.retentionPeriod },
                            onSelect: { model.setRetentionPeriod($0.period) },
                            theme: theme
                        )
                        .padding(12)
                    }

                    SectionLabel(model.strings.sectionAbout, theme: theme)
                    GroupCard(theme: theme) {
                        ForEach(Array(LegalKey.allCases.enumerated()), id: \.element.id) { index, key in
                            GroupRow(theme: theme, isFirst: index == 0) {
                                model.openLegal(key)
                            } content: {
                                Text(legalLabel(key))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(theme.textMuted)
                                    .accessibilityHidden(true)
                            }
                        }
                        Text(model.strings.version)
                            .font(AppFont.body(12))
                            .foregroundStyle(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().fill(theme.divider).frame(height: 1), alignment: .top)
                    }

                    GroupCard(theme: theme) {
                        GroupRow(theme: theme, isFirst: true) {
                            model.showResetToDefaultConfirmation = true
                        } content: {
                            Text(model.strings.resetToDefault)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .sheet(item: $model.legalOpenKey) { key in
            LegalSheetView(model: model, key: key, theme: theme)
        }
        .alert(
            model.strings.resetToDefaultConfirmTitle,
            isPresented: $model.showResetToDefaultConfirmation
        ) {
            Button(model.strings.cancel, role: .cancel) { }
            Button(model.strings.reset, role: .destructive) {
                model.resetToDefault()
            }
        } message: {
            Text(model.strings.resetToDefaultConfirmMessage)
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

private struct RetentionPeriodItem: Identifiable {
    let period: RetentionPeriod
    var id: String { period.id }
    func label(_ s: Strings) -> String {
        switch period {
        case .oneWeek: return s.retentionOneWeek
        case .oneMonth: return s.retentionOneMonth
        case .sixMonths: return s.retentionSixMonths
        }
    }
    static let all: [RetentionPeriodItem] = RetentionPeriod.allCases.map { RetentionPeriodItem(period: $0) }
}

struct SectionLabel: View {
    let text: String
    let theme: Theme
    init(_ text: String, theme: Theme) { self.text = text; self.theme = theme }
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.body(11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(theme.textMuted)
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
