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
                    // Mark as completed and keep in cart until manual reset
                    manager.updateCartItemStatus(item, to: .completed)
                    changed = true
                } else {
                    // Update cached issue data
                    if var issues = manager.issuesByRepo[item.repo.fullName],
                       let idx = issues.firstIndex(where: { $0.number == freshIssue.number }) {
                        issues[idx] = freshIssue
                        manager.issuesByRepo[item.repo.fullName] = issues
                    }

                    // Check PR status for pending items
                    if item.status == .pending, let prNumber = item.prNumber {
                        do {
                            // Fetch full PR details
                            let pr = try await client.getPullRequest(
                                repo: item.repo.fullName,
                                number: prNumber
                            )

                            // Reset if PR closed without merge
                            if pr.state == "closed", pr.mergedAt == nil {
                                manager.resetPendingCartItem(item)
                                changed = true
                                continue
                            }

                            // Fetch reviews to detect changes requested
                            let reviews = try await client.getPullRequestReviews(
                                repo: item.repo.fullName,
                                number: prNumber
                            )

                            // Check if any human reviewer requested changes
                            let hasChangesRequested = reviews.contains { review in
                                review.state == "CHANGES_REQUESTED" &&
                                review.user.type != "Bot"
                            }

                            // Update cart item with PR details
                            manager.updateCartItemPRDetails(item, pr: pr, hasChangesRequested: hasChangesRequested)
                            changed = true

                        } catch {
                            // Silently skip if API call fails
                        }
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
