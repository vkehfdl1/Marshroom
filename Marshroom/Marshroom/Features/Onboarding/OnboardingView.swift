import SwiftUI

struct OnboardingView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)

            TabView(selection: $currentStep) {
                PATInputView(onNext: { currentStep = 1 })
                    .tag(0)

                RepoSearchView(onNext: { currentStep = 2 })
                    .tag(1)

                SkillSetupView(onComplete: completeOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func completeOnboarding() {
        appState.settings.hasCompletedOnboarding = true
        appState.syncStateFile()

        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            delegate.onOnboardingComplete()
        }
    }
}
