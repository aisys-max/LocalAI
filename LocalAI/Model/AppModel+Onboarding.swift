import Foundation

extension AppModel {
    func onboardingNext() { onboardingStep += 1 }
    func onboardingBack() { onboardingStep = max(0, onboardingStep - 1) }
    func finishOnboarding() {
        screen = .chat
        newChat()
    }
}
