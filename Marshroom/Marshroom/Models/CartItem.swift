import Foundation

struct CartItem: Identifiable, Hashable {
    let repo: GitHubRepo
    let issue: GitHubIssue
    var status: IssueStatus
    var prNumber: Int?
    var prURL: String?
    var prDetails: GitHubPullRequest?
    var hasChangesRequested: Bool = false

    var id: String { "\(repo.fullName)#\(issue.number)" }
    var branchName: String { issue.branchName }

    /// Computed sub-status for pending PRs based on GitHub data
    var pendingSubStatus: PendingSubStatus? {
        guard status == .pending, let pr = prDetails else { return nil }

        // Priority order (highest first):
        // 1. Changes requested by human
        if hasChangesRequested { return .changesRequested }

        // 2. Reviewer assigned
        let hasReviewers = !(pr.requestedReviewers?.isEmpty ?? true) ||
                           !(pr.requestedTeams?.isEmpty ?? true)
        if hasReviewers { return .reviewerAssigned }

        // 3. Has conversations/comments
        if pr.comments + pr.reviewComments > 0 { return .aiReviewCompleted }

        // 4. Default (just created)
        return .justCreated
    }

    init(repo: GitHubRepo, issue: GitHubIssue, status: IssueStatus = .soon,
         prNumber: Int? = nil, prURL: String? = nil,
         prDetails: GitHubPullRequest? = nil, hasChangesRequested: Bool = false) {
        self.repo = repo
        self.issue = issue
        self.status = status
        self.prNumber = prNumber
        self.prURL = prURL
        self.prDetails = prDetails
        self.hasChangesRequested = hasChangesRequested
    }

    // MARK: - Hashable
    // Custom implementation needed since prDetails (GitHubPullRequest) is not Hashable
    // We only hash the persisted fields that define identity

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
        hasher.combine(prNumber)
        hasher.combine(prURL)
        hasher.combine(hasChangesRequested)
    }

    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.prNumber == rhs.prNumber &&
        lhs.prURL == rhs.prURL &&
        lhs.hasChangesRequested == rhs.hasChangesRequested
    }
}
