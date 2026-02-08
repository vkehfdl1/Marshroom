import Foundation

struct CartItem: Identifiable, Hashable {
    let repo: GitHubRepo
    let issue: GitHubIssue

    var id: String { "\(repo.fullName)#\(issue.number)" }
    var branchName: String { issue.branchName }
}
