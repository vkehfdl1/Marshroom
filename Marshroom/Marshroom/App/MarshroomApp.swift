import SwiftUI

@main
struct MarshroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isOnboarded {
                    MallView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
            .onAppear {
                appDelegate.appState = appState
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsWindow()
                .environment(appState)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "leaf.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
