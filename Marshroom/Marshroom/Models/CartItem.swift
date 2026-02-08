import Foundation

struct CartItem: Identifiable, Hashable {
    let repo: GitHubRepo
    let issue: GitHubIssue
    var status: IssueStatus

    var id: String { "\(repo.fullName)#\(issue.number)" }
    var branchName: String { issue.branchName }

    init(repo: GitHubRepo, issue: GitHubIssue, status: IssueStatus = .soon) {
        self.repo = repo
        self.issue = issue
        self.status = status
    }
}
