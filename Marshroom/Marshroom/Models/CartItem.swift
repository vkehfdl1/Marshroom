import Foundation

struct CartItem: Identifiable, Hashable {
    let repo: GitHubRepo
    let issue: GitHubIssue
    var status: IssueStatus
    var prNumber: Int?
    var prURL: String?

    var id: String { "\(repo.fullName)#\(issue.number)" }
    var branchName: String { issue.branchName }

    init(repo: GitHubRepo, issue: GitHubIssue, status: IssueStatus = .soon,
         prNumber: Int? = nil, prURL: String? = nil) {
        self.repo = repo
        self.issue = issue
        self.status = status
        self.prNumber = prNumber
        self.prURL = prURL
    }
}
