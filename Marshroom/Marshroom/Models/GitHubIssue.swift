import Foundation

struct GitHubPullRequest: Codable {
    let state: String
    let mergedAt: String?
    let comments: Int
    let reviewComments: Int
    let requestedReviewers: [Reviewer]?
    let requestedTeams: [Team]?

    enum CodingKeys: String, CodingKey {
        case state
        case mergedAt = "merged_at"
        case comments
        case reviewComments = "review_comments"
        case requestedReviewers = "requested_reviewers"
        case requestedTeams = "requested_teams"
    }

    struct Reviewer: Codable {
        let login: String
    }

    struct Team: Codable {
        let name: String
    }
}

struct GitHubPullRequestReview: Codable {
    let id: Int
    let user: ReviewUser
    let state: String  // "APPROVED", "CHANGES_REQUESTED", "COMMENTED"
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, user, state
        case submittedAt = "submitted_at"
    }

    struct ReviewUser: Codable {
        let login: String
        let type: String  // "User" or "Bot"
    }
}

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
