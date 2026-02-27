import Foundation

@Observable
final class SettingsStorage {
    var pollingIntervalSeconds: Int {
        didSet { UserDefaults.standard.set(pollingIntervalSeconds, forKey: Keys.pollingInterval) }
    }

    var pinnedRepoNames: [String] {
        didSet { UserDefaults.standard.set(pinnedRepoNames, forKey: Keys.pinnedRepos) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    var selectedRepoFullName: String? {
        didSet { UserDefaults.standard.set(selectedRepoFullName, forKey: Keys.selectedRepo) }
    }

    var completionResetHour: Int {
        didSet { UserDefaults.standard.set(completionResetHour, forKey: Keys.completionResetHour) }
    }

    var customStateFilePath: String? {
        didSet { UserDefaults.standard.set(customStateFilePath, forKey: Keys.customStateFilePath) }
    }

    init() {
        let defaults = UserDefaults.standard
        let interval = defaults.integer(forKey: Keys.pollingInterval)
        self.pollingIntervalSeconds = interval > 0 ? interval : Constants.defaultPollingIntervalSeconds
        self.pinnedRepoNames = defaults.stringArray(forKey: Keys.pinnedRepos) ?? []
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        self.selectedRepoFullName = defaults.string(forKey: Keys.selectedRepo)
        let resetHour = defaults.object(forKey: Keys.completionResetHour) as? Int
        self.completionResetHour = resetHour ?? 0
        self.customStateFilePath = defaults.string(forKey: Keys.customStateFilePath)
    }

    // MARK: - Highlight Repos Persistence

    func saveHighlightRepos(_ repos: [GitHubRepo]) {
        let data = try? JSONEncoder().encode(repos)
        UserDefaults.standard.set(data, forKey: Keys.highlightReposData)
    }

    func loadHighlightRepos() -> [GitHubRepo] {
        guard let data = UserDefaults.standard.data(forKey: Keys.highlightReposData) else { return [] }
        return (try? JSONDecoder().decode([GitHubRepo].self, from: data)) ?? []
    }

    var hasAnthropicKey: Bool {
        KeychainService.loadAnthropicKey() != nil
    }

    private enum Keys {
        static let pollingInterval = "pollingIntervalSeconds"
        static let pinnedRepos = "pinnedRepoNames"
        static let onboarded = "hasCompletedOnboarding"
        static let selectedRepo = "selectedRepoFullName"
        static let highlightReposData = "highlightReposData"
        static let completionResetHour = "completionResetHour"
        static let customStateFilePath = "customStateFilePath"
    }
}
