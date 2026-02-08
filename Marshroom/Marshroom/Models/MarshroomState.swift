import Foundation

struct MarshroomState: Codable {
    var version: Int = 2
    var updatedAt: String
    var cart: [CartEntry]
    var repos: [RepoEntry]

    struct CartEntry: Codable {
        let repoFullName: String
        let repoCloneURL: String
        let repoSSHURL: String
        let issueNumber: Int
        let issueTitle: String
        let branchName: String
    }

    struct RepoEntry: Codable {
        let fullName: String
        let cloneURL: String
        let sshURL: String
    }

    static func empty() -> MarshroomState {
        MarshroomState(
            updatedAt: Constants.iso8601Formatter.string(from: Date()),
            cart: [],
            repos: []
        )
    }
}
