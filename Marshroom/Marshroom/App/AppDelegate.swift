import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppStateManager! {
        didSet {
            guard appState != nil else { return }
            onAppStateReady()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // appState is set via .onAppear, so it's not yet available here.
        // Setup happens in onAppStateReady() via the didSet observer.
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopFileWatcher()
        appState?.stopPolling()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - App State Ready

    private func onAppStateReady() {
        guard appState.isOnboarded else { return }
        appState.restoreHighlightRepos()
        appState.restoreCartFromStateFile()
        Task {
            await appState.restoreCurrentUser()
            appState.startPolling()
            appState.startFileWatcher()
        }
    }

    func onOnboardingComplete() {
        appState.restoreHighlightRepos()
        appState.restoreCartFromStateFile()
        Task {
            await appState.restoreCurrentUser()
            appState.startPolling()
            appState.startFileWatcher()
        }
    }
}
