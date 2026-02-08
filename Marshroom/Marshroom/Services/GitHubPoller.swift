import Foundation

@MainActor
final class GitHubPoller {
    private weak var stateManager: AppStateManager?
    private var pollingTask: Task<Void, Never>?

    init(stateManager: AppStateManager) {
        self.stateManager = stateManager
    }

    func start() {
        stop()
        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            guard let manager = stateManager else { return }
            let interval = manager.settings.pollingIntervalSeconds

            await pollRepos()

            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return // Cancelled
            }
        }
    }

    private func pollRepos() async {
        guard let manager = stateManager,
              let client = manager.apiClient else { return }

        // Check rate limit before polling
        let remaining = await client.rateLimitRemaining
        if remaining < Constants.rateLimitWarningThreshold {
            if remaining == 0 {
                manager.errorMessage = "GitHub API rate limit exceeded. Polling paused."
                return
            }
        }

        var changed = false

        // Refresh each cart item — detect closed issues, PR creation, and update cached data
        for item in manager.todayCart {
            guard !Task.isCancelled else { return }

            do {
                let freshIssue = try await client.getIssue(
                    repo: item.repo.fullName,
                    number: item.issue.number
                )

                if freshIssue.state == "closed" {
                    // Mark as completed, then schedule removal
                    manager.updateCartItemStatus(item, to: .completed)
                    changed = true

                    // Remove after a brief delay so UI can show completed state
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        manager.todayCart.removeAll { $0.id == item.id }
                        manager.syncStateFile()
                    }
                } else {
                    // Update cached issue data
                    if var issues = manager.issuesByRepo[item.repo.fullName],
                       let idx = issues.firstIndex(where: { $0.number == freshIssue.number }) {
                        issues[idx] = freshIssue
                        manager.issuesByRepo[item.repo.fullName] = issues
                    }
                }
            } catch {
                // Silently skip individual issue fetch failures
            }
        }

        // Refresh CLAUDE.md cache if stale
        let currentState = StateFileManager.readState()
        for repo in manager.highlightRepos {
            if manager.isClaudeMdCacheStale(for: repo.fullName, state: currentState) {
                await manager.refreshClaudeMdCache(for: repo.fullName)
            }
        }

        if changed {
            manager.syncStateFile()
        }
    }
}
