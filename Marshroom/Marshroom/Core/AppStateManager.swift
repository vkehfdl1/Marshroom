import Foundation
import SwiftUI

@MainActor
@Observable
final class AppStateManager {
    // MARK: - Published State

    var highlightRepos: [GitHubRepo] = []
    var todayCart: [CartItem] = []
    var isLoading = false
    var errorMessage: String?
    var currentUser: GitHubUser?

    // Repo → Issues cache
    var issuesByRepo: [String: [GitHubIssue]] = [:]

    // MARK: - Dependencies

    let settings: SettingsStorage
    private(set) var apiClient: GitHubAPIClient?
    private var poller: GitHubPoller?

    var isOnboarded: Bool {
        settings.hasCompletedOnboarding
    }

    init(settings: SettingsStorage = SettingsStorage()) {
        self.settings = settings

        // Restore API client from keychain
        if let pat = KeychainService.loadPAT() {
            self.apiClient = GitHubAPIClient(pat: pat)
        }
    }

    // MARK: - Auth

    func setupAPIClient(pat: String) {
        self.apiClient = GitHubAPIClient(pat: pat)
    }

    func validateAndSavePAT(_ pat: String) async throws -> GitHubUser {
        let client = GitHubAPIClient(pat: pat)
        let user = try await client.validateToken()
        try KeychainService.savePAT(pat)
        self.apiClient = client
        self.currentUser = user
        return user
    }

    // MARK: - Repos

    func addRepoToHighlights(_ repo: GitHubRepo) {
        guard !highlightRepos.contains(where: { $0.fullName == repo.fullName }) else { return }
        highlightRepos.append(repo)
        settings.pinnedRepoNames.append(repo.fullName)
        persistHighlightRepos()
    }

    func removeRepo(_ repo: GitHubRepo) {
        highlightRepos.removeAll { $0.fullName == repo.fullName }
        settings.pinnedRepoNames.removeAll { $0 == repo.fullName }
        issuesByRepo.removeValue(forKey: repo.fullName)

        // Remove cart items from this repo
        todayCart.removeAll { $0.repo.fullName == repo.fullName }

        persistHighlightRepos()
        syncStateFile()
    }

    // MARK: - Issues

    func refreshIssues(for repo: String) async {
        guard let client = apiClient else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var allIssues: [GitHubIssue] = []
            for page in 1...3 {
                let pageIssues = try await client.fetchIssues(repo: repo, page: page)
                allIssues.append(contentsOf: pageIssues)
                if pageIssues.count < 30 { break }
            }
            issuesByRepo[repo] = allIssues.filter { !$0.isPullRequest }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAllCartIssues() async {
        guard let client = apiClient else { return }
        for item in todayCart {
            if let issue = try? await client.getIssue(
                repo: item.repo.fullName,
                number: item.issue.number
            ) {
                // Update issue in cache
                if var issues = issuesByRepo[item.repo.fullName],
                   let idx = issues.firstIndex(where: { $0.number == issue.number }) {
                    issues[idx] = issue
                    issuesByRepo[item.repo.fullName] = issues
                }
            }
        }
    }

    // MARK: - Cart

    func addIssueToCart(repo: GitHubRepo, issue: GitHubIssue) {
        let item = CartItem(repo: repo, issue: issue)
        guard !todayCart.contains(where: { $0.id == item.id }) else { return }

        todayCart.append(item)
        syncStateFile()
    }

    func removeIssueFromCart(_ item: CartItem) {
        todayCart.removeAll { $0.id == item.id }
        syncStateFile()
    }

    // MARK: - Highlight Repos Persistence

    func restoreHighlightRepos() {
        highlightRepos = settings.loadHighlightRepos()
    }

    private func persistHighlightRepos() {
        settings.saveHighlightRepos(highlightRepos)
    }

    // MARK: - Cart Restoration

    func restoreCartFromStateFile() {
        guard let state = StateFileManager.readState() else { return }

        for entry in state.cart {
            // Build stub objects from CartEntry data
            let repo = GitHubRepo(
                id: 0,
                name: entry.repoFullName.components(separatedBy: "/").last ?? entry.repoFullName,
                fullName: entry.repoFullName,
                owner: GitHubRepo.Owner(login: entry.repoFullName.components(separatedBy: "/").first ?? "", avatarURL: ""),
                htmlURL: "https://github.com/\(entry.repoFullName)",
                cloneURL: entry.repoCloneURL,
                sshURL: entry.repoSSHURL,
                description: nil,
                isPrivate: false
            )
            let issue = GitHubIssue(
                id: 0,
                number: entry.issueNumber,
                title: entry.issueTitle,
                body: nil,
                state: "open",
                labels: [],
                htmlURL: "https://github.com/\(entry.repoFullName)/issues/\(entry.issueNumber)",
                user: GitHubIssue.User(login: "", avatarURL: ""),
                assignees: [],
                createdAt: "",
                updatedAt: "",
                pullRequest: nil
            )

            let item = CartItem(repo: repo, issue: issue)
            if !todayCart.contains(where: { $0.id == item.id }) {
                todayCart.append(item)
            }
        }
    }

    // MARK: - State File

    func syncStateFile() {
        let state = StateFileManager.buildState(
            cart: todayCart,
            repos: highlightRepos
        )
        try? StateFileManager.writeState(state)
    }

    // MARK: - Polling

    func startPolling() {
        guard poller == nil else { return }
        poller = GitHubPoller(stateManager: self)
        poller?.start()
    }

    func stopPolling() {
        poller?.stop()
        poller = nil
    }

    // MARK: - Restore User

    func restoreCurrentUser() async {
        guard let client = apiClient, currentUser == nil else { return }
        currentUser = try? await client.validateToken()
    }
}
