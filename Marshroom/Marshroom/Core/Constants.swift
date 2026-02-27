import Foundation

enum Constants {
    static let defaultPollingIntervalSeconds = 30
    static let minPollingIntervalSeconds = 10
    static let maxPollingIntervalSeconds = 120
    static let rateLimitWarningThreshold = 100

    /// Resolved state file path. Priority: MARSHROOM_STATE env var → UserDefaults → default.
    static var stateFilePath: String {
        if let envPath = ProcessInfo.processInfo.environment["MARSHROOM_STATE"], !envPath.isEmpty {
            return envPath
        }
        if let customPath = UserDefaults.standard.string(forKey: "customStateFilePath"), !customPath.isEmpty {
            return customPath
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/marshroom/state.json"
    }

    /// Directory containing the state file.
    static var stateFileDirectory: String {
        (stateFilePath as NSString).deletingLastPathComponent
    }

    /// True when the state file is outside `$HOME` (e.g. NFS mount). kqueue won't detect remote changes.
    static var stateFileIsRemote: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return !stateFilePath.hasPrefix(home)
    }

    static let defaultStateFilePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/marshroom/state.json"
    }()

    static let gitHubAPIBaseURL = "https://api.github.com"
    static let anthropicAPIBaseURL = "https://api.anthropic.com"
    static let claudeMdCacheTTLSeconds = 3600
    static let iso8601Formatter = ISO8601DateFormatter()
    static let dateOnlyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt
    }()
}
