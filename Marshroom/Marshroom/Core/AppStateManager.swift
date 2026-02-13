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

    // Completion tracking
    var todayCompletions: Int = 0
    var todayCompletionsDate: String?

    // MARK: - Dependencies

    let settings: SettingsStorage
    private(set) var apiClient: GitHubAPIClient?
    private(set) var anthropicClient: AnthropicClient?
    private var poller: GitHubPoller?
    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var lastSelfWriteTime: Date = .distantPast

    // CLAUDE.md cache (repo fullName → content)
    private var claudeMdCacheStore: [String: String] = [:]

    var isOnboarded: Bool {
        settings.hasCompletedOnboarding
    }

    init(settings: SettingsStorage = SettingsStorage()) {
        self.settings = settings

        // Restore API client from keychain
        if let pat = KeychainService.loadPAT() {
            self.apiClient = GitHubAPIClient(pat: pat)
        }

        // Restore Anthropic client from keychain
        if let anthropicKey = KeychainService.loadAnthropicKey() {
            self.anthropicClient = AnthropicClient(apiKey: anthropicKey)
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

    func refreshAnthropicClient() {
        if let key = KeychainService.loadAnthropicKey() {
            self.anthropicClient = AnthropicClient(apiKey: key)
        } else {
            self.anthropicClient = nil
        }
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

    func updateCartItemStatus(_ item: CartItem, to newStatus: IssueStatus) {
        guard let idx = todayCart.firstIndex(where: { $0.id == item.id }) else { return }
        let oldStatus = todayCart[idx].status
        todayCart[idx].status = newStatus

        if newStatus == .completed && oldStatus != .completed {
            resetCompletionsIfNewDay()
            todayCompletions += 1
        }

        syncStateFile()
    }

    func resetPendingCartItem(_ item: CartItem) {
        guard let idx = todayCart.firstIndex(where: { $0.id == item.id }) else { return }
        todayCart[idx].status = .soon
        todayCart[idx].prNumber = nil
        todayCart[idx].prURL = nil
        syncStateFile()
    }

    func updateCartItemPRDetails(_ item: CartItem, pr: GitHubPullRequest, hasChangesRequested: Bool) {
        guard let idx = todayCart.firstIndex(where: { $0.id == item.id }) else { return }
        todayCart[idx].prDetails = pr
        todayCart[idx].hasChangesRequested = hasChangesRequested
        // Note: No syncStateFile() - this is cached data, not persisted
    }

    // MARK: - Issue Creation

    func createIssue(repo: String, title: String, body: String?) async throws -> GitHubIssue {
        guard let client = apiClient else {
            throw GitHubAPIError.invalidResponse
        }
        return try await client.createIssue(repo: repo, title: title, body: body)
    }

    func generateIssueTitle(rawInput: String, repo: String) async throws -> String {
        guard let client = anthropicClient else {
            throw AnthropicError.invalidResponse
        }
        let claudeMd = claudeMdCache(for: repo)
        return try await client.generateTitle(rawInput: rawInput, claudeMd: claudeMd, repoName: repo)
    }

    // MARK: - CLAUDE.md Cache

    func claudeMdCache(for repoFullName: String) -> String? {
        claudeMdCacheStore[repoFullName]
    }

    func refreshClaudeMdCache(for repoFullName: String) async {
        guard let client = apiClient else { return }
        do {
            let content = try await client.fetchFileContent(repo: repoFullName, path: "CLAUDE.md")
            claudeMdCacheStore[repoFullName] = content
        } catch {
            // File may not exist — that's OK
        }
    }

    func isClaudeMdCacheStale(for repoFullName: String, state: MarshroomState?) -> Bool {
        guard let state,
              let repoEntry = state.repos.first(where: { $0.fullName == repoFullName }),
              let cachedAt = repoEntry.claudeMdCachedAt,
              let date = Constants.iso8601Formatter.date(from: cachedAt) else {
            return true
        }
        return Date().timeIntervalSince(date) > TimeInterval(Constants.claudeMdCacheTTLSeconds)
    }

    // MARK: - Completion Tracking

    func currentDayString() -> String {
        let now = Date()
        let adjusted = Calendar.current.date(byAdding: .hour, value: -settings.completionResetHour, to: now) ?? now
        return Constants.dateOnlyFormatter.string(from: adjusted)
    }

    func resetCompletionsIfNewDay() {
        let today = currentDayString()
        if todayCompletionsDate != today {
            todayCompletions = 0
            todayCompletionsDate = today
        }
    }

    /// Manually reset today's completion count and remove completed items (user-initiated)
    func manuallyResetDay() {
        // Reset counter
        todayCompletions = 0
        todayCompletionsDate = Constants.dateOnlyFormatter.string(from: Date())

        // Remove all completed items from cart
        todayCart.removeAll { $0.status == .completed }

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
                body: entry.issueBody,
                state: "open",
                labels: [],
                htmlURL: "https://github.com/\(entry.repoFullName)/issues/\(entry.issueNumber)",
                user: GitHubIssue.User(login: "", avatarURL: ""),
                assignees: [],
                createdAt: "",
                updatedAt: "",
                pullRequest: nil
            )

            let item = CartItem(repo: repo, issue: issue, status: entry.status,
                                prNumber: entry.prNumber, prURL: entry.prURL)
            if !todayCart.contains(where: { $0.id == item.id }) {
                todayCart.append(item)
            }
        }

        // Restore CLAUDE.md caches from state
        for repoEntry in state.repos {
            if let cache = repoEntry.claudeMdCache {
                claudeMdCacheStore[repoEntry.fullName] = cache
            }
        }

        // Restore completion count
        let today = currentDayString()
        if state.todayCompletionsDate == today {
            todayCompletions = state.todayCompletions ?? 0
            todayCompletionsDate = today
        } else {
            todayCompletions = 0
            todayCompletionsDate = today
        }
    }

    // MARK: - State File

    func syncStateFile() {
        lastSelfWriteTime = Date()
        let existingState = StateFileManager.readState()
        var state = StateFileManager.buildState(
            cart: todayCart,
            repos: highlightRepos,
            existingState: existingState
        )
        state.todayCompletions = todayCompletions
        state.todayCompletionsDate = todayCompletionsDate
        try? StateFileManager.writeState(state)
    }

    // MARK: - File Watcher

    func startFileWatcher() {
        stopFileWatcher()

        let dirPath = Constants.stateFileDirectory
        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleExternalStateChange()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        fileWatcherSource = source
        source.resume()
    }

    func stopFileWatcher() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
    }

    private func handleExternalStateChange() {
        // Ignore changes triggered by our own writes
        guard Date().timeIntervalSince(lastSelfWriteTime) > 1.0 else { return }

        guard let state = StateFileManager.readState() else { return }

        // Build lookup from state.json cart entries
        var stateEntries: [String: MarshroomState.CartEntry] = [:]
        for entry in state.cart {
            stateEntries["\(entry.repoFullName)#\(entry.issueNumber)"] = entry
        }

        // Update existing items and detect removals
        var updatedCart: [CartItem] = []
        for var item in todayCart {
            let key = item.id
            if let entry = stateEntries.removeValue(forKey: key) {
                item.status = entry.status
                item.prNumber = entry.prNumber
                item.prURL = entry.prURL
                updatedCart.append(item)
            }
            // If not in state file, item was removed externally — drop it
        }

        // Add new items that appeared in state.json (added by CLI or another source)
        for (_, entry) in stateEntries {
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
                body: entry.issueBody,
                state: "open",
                labels: [],
                htmlURL: "https://github.com/\(entry.repoFullName)/issues/\(entry.issueNumber)",
                user: GitHubIssue.User(login: "", avatarURL: ""),
                assignees: [],
                createdAt: "",
                updatedAt: "",
                pullRequest: nil
            )
            updatedCart.append(CartItem(repo: repo, issue: issue, status: entry.status,
                                        prNumber: entry.prNumber, prURL: entry.prURL))
        }

        todayCart = updatedCart

        // Sync completion count from external changes
        let today = currentDayString()
        if state.todayCompletionsDate == today {
            todayCompletions = state.todayCompletions ?? 0
            todayCompletionsDate = today
        }
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
