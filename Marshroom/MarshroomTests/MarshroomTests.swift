import Foundation
import Testing
@testable import Marshroom

@Suite("GitHubIssue Branch Name")
struct GitHubIssueBranchNameTests {
    @Test("Feature branch for regular issue")
    func featureBranch() {
        let issue = makeIssue(number: 42, title: "Add dark mode support")
        #expect(issue.branchName == "Feature/#42")
    }

    @Test("HotFix branch for bug issue")
    func hotfixBranchBug() {
        let issue = makeIssue(number: 7, title: "Bug: login fails on empty password")
        #expect(issue.branchName == "HotFix/#7")
    }

    @Test("HotFix branch for fix issue")
    func hotfixBranchFix() {
        let issue = makeIssue(number: 15, title: "Fix crash when scrolling")
        #expect(issue.branchName == "HotFix/#15")
    }

    @Test("HotFix branch for hotfix issue")
    func hotfixBranchHotfix() {
        let issue = makeIssue(number: 3, title: "HotFix production timeout")
        #expect(issue.branchName == "HotFix/#3")
    }

    @Test("isAssigned(to:) returns true for matching login")
    func isAssigned() {
        let issue = makeIssue(
            number: 1,
            title: "Test",
            assignees: [GitHubIssue.User(login: "me", avatarURL: "")]
        )
        #expect(issue.isAssigned(to: "me"))
        #expect(!issue.isAssigned(to: "other"))
    }

    private func makeIssue(
        number: Int,
        title: String,
        labels: [GitHubLabel] = [],
        assignees: [GitHubIssue.User] = []
    ) -> GitHubIssue {
        GitHubIssue(
            id: number,
            number: number,
            title: title,
            body: nil,
            state: "open",
            labels: labels,
            htmlURL: "https://github.com/test/repo/issues/\(number)",
            user: GitHubIssue.User(login: "testuser", avatarURL: ""),
            assignees: assignees,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            pullRequest: nil
        )
    }
}

@Suite("MarshroomState")
struct MarshroomStateTests {
    @Test("Empty state creates valid JSON")
    func emptyState() throws {
        let state = MarshroomState.empty()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MarshroomState.self, from: data)
        #expect(decoded.version == 2)
        #expect(decoded.cart.isEmpty)
        #expect(decoded.repos.isEmpty)
    }

    @Test("State with cart entry round-trips")
    func cartEntryRoundTrip() throws {
        var state = MarshroomState.empty()
        state.cart = [
            MarshroomState.CartEntry(
                repoFullName: "owner/repo",
                repoCloneURL: "https://github.com/owner/repo.git",
                repoSSHURL: "git@github.com:owner/repo.git",
                issueNumber: 42,
                issueTitle: "Test issue",
                branchName: "Feature/#42"
            )
        ]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MarshroomState.self, from: data)
        #expect(decoded.cart.count == 1)
        #expect(decoded.cart.first?.issueNumber == 42)
        #expect(decoded.cart.first?.branchName == "Feature/#42")
        #expect(decoded.cart.first?.repoCloneURL == "https://github.com/owner/repo.git")
    }
}
