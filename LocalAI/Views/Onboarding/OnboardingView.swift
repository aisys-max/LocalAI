import SwiftUI

/// Container for the 3-step onboarding flow — ports the `screenIsOnboarding`
/// branch of the design: back button, one of three step pages, and a footer
/// with progress dots + a primary button whose label/action changes per step.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if model.onboardingStep > 0 {
                    IconButtonView(title: model.strings.back, systemName: "chevron.left", theme: theme) {
                        model.onboardingBack()
                    }
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.leading, 12)
            .frame(height: 44)

            Group {
                switch model.onboardingStep {
                case 0: WelcomeStepView(model: model, theme: theme)
                case 1: BackendStepView(model: model, theme: theme)
                default: ModelStepView(model: model, theme: theme)
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == model.onboardingStep ? theme.accent : theme.divider)
                            .frame(width: 7, height: 7)
                    }
                }

                Button(action: primaryAction) {
                    Text(primaryLabel)
                        .font(AppFont.body(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(theme.accent))
                        .foregroundStyle(theme.onAccentText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
            .padding(.top, 10)
        }
        .background(theme.bg.ignoresSafeArea())
    }

    private var primaryLabel: String {
        switch model.onboardingStep {
        case 0, 1: return model.strings.continueBtn
        default: return model.strings.getStarted
        }
    }

    private func primaryAction() {
        if model.onboardingStep < 2 {
            model.onboardingNext()
        } else {
            model.finishOnboarding()
        }
    }
}
