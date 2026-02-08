import Foundation

struct PullRequestRef: Codable, Hashable {
    let url: String?
}

struct GitHubIssue: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let labels: [GitHubLabel]
    let htmlURL: String
    let user: User
    let assignees: [User]
    let createdAt: String
    let updatedAt: String
    let pullRequest: PullRequestRef?

    var isPullRequest: Bool { pullRequest != nil }

    func isAssigned(to login: String) -> Bool {
        assignees.contains { $0.login == login }
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, labels, user, assignees
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pullRequest = "pull_request"
    }

    struct User: Codable, Hashable {
        let login: String
        let avatarURL: String

        enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    var branchName: String {
        let lowered = title.lowercased()
        let hotfixKeywords = ["bug", "fix", "hotfix"]
        let isHotfix = hotfixKeywords.contains { lowered.contains($0) }
        return isHotfix ? "HotFix/#\(number)" : "Feature/#\(number)"
    }

}
