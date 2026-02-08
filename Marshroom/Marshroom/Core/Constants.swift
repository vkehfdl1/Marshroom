import Foundation

enum Constants {
    static let defaultPollingIntervalSeconds = 30
    static let minPollingIntervalSeconds = 10
    static let maxPollingIntervalSeconds = 120
    static let rateLimitWarningThreshold = 100
    static let stateFileDirectory: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/marshroom"
    }()
    static let stateFilePath = stateFileDirectory + "/state.json"
    static let gitHubAPIBaseURL = "https://api.github.com"
    static let iso8601Formatter = ISO8601DateFormatter()
}
