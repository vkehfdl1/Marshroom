import Foundation

struct MarshroomState: Codable {
    var version: Int = 3
    var updatedAt: String
    var cart: [CartEntry]
    var repos: [RepoEntry]
    var todayCompletions: Int?
    var todayCompletionsDate: String?

    struct CartEntry: Codable {
        let repoFullName: String
        let repoCloneURL: String
        let repoSSHURL: String
        let issueNumber: Int
        let issueTitle: String
        let branchName: String
        var status: IssueStatus
        var issueBody: String?
        var prNumber: Int?
        var prURL: String?

        enum CodingKeys: String, CodingKey {
            case repoFullName, repoCloneURL, repoSSHURL
            case issueNumber, issueTitle, branchName
            case status, issueBody, prNumber, prURL
        }

        init(repoFullName: String, repoCloneURL: String, repoSSHURL: String,
             issueNumber: Int, issueTitle: String, branchName: String,
             status: IssueStatus = .soon, issueBody: String? = nil,
             prNumber: Int? = nil, prURL: String? = nil) {
            self.repoFullName = repoFullName
            self.repoCloneURL = repoCloneURL
            self.repoSSHURL = repoSSHURL
            self.issueNumber = issueNumber
            self.issueTitle = issueTitle
            self.branchName = branchName
            self.status = status
            self.issueBody = issueBody
            self.prNumber = prNumber
            self.prURL = prURL
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            repoFullName = try container.decode(String.self, forKey: .repoFullName)
            repoCloneURL = try container.decode(String.self, forKey: .repoCloneURL)
            repoSSHURL = try container.decode(String.self, forKey: .repoSSHURL)
            issueNumber = try container.decode(Int.self, forKey: .issueNumber)
            issueTitle = try container.decode(String.self, forKey: .issueTitle)
            branchName = try container.decode(String.self, forKey: .branchName)
            // v2 backward compat: status defaults to .soon if missing
            status = try container.decodeIfPresent(IssueStatus.self, forKey: .status) ?? .soon
            issueBody = try container.decodeIfPresent(String.self, forKey: .issueBody)
            prNumber = try container.decodeIfPresent(Int.self, forKey: .prNumber)
            prURL = try container.decodeIfPresent(String.self, forKey: .prURL)
        }
    }

    struct RepoEntry: Codable {
        let fullName: String
        let cloneURL: String
        let sshURL: String
        var claudeMdCache: String?
        var claudeMdCachedAt: String?
        var localPath: String?

        enum CodingKeys: String, CodingKey {
            case fullName, cloneURL, sshURL
            case claudeMdCache, claudeMdCachedAt, localPath
        }

        init(fullName: String, cloneURL: String, sshURL: String,
             claudeMdCache: String? = nil, claudeMdCachedAt: String? = nil,
             localPath: String? = nil) {
            self.fullName = fullName
            self.cloneURL = cloneURL
            self.sshURL = sshURL
            self.claudeMdCache = claudeMdCache
            self.claudeMdCachedAt = claudeMdCachedAt
            self.localPath = localPath
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fullName = try container.decode(String.self, forKey: .fullName)
            cloneURL = try container.decode(String.self, forKey: .cloneURL)
            sshURL = try container.decode(String.self, forKey: .sshURL)
            // v2 backward compat: these fields may not exist
            claudeMdCache = try container.decodeIfPresent(String.self, forKey: .claudeMdCache)
            claudeMdCachedAt = try container.decodeIfPresent(String.self, forKey: .claudeMdCachedAt)
            localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
        }
    }

    static func empty() -> MarshroomState {
        MarshroomState(
            updatedAt: Constants.iso8601Formatter.string(from: Date()),
            cart: [],
            repos: [],
            todayCompletions: 0,
            todayCompletionsDate: nil
        )
    }
}
