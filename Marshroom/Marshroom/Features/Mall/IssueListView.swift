import SwiftUI

struct IssueListView: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo
    @Binding var selectedIssue: GitHubIssue?

    var issues: [GitHubIssue] {
        appState.issuesByRepo[repo.fullName] ?? []
    }

    var body: some View {
        Group {
            if appState.isLoading && issues.isEmpty {
                ProgressView("Loading issues...")
            } else if issues.isEmpty {
                ContentUnavailableView(
                    "No Open Issues",
                    systemImage: "checkmark.circle",
                    description: Text("This repository has no open issues")
                )
            } else {
                List(issues, selection: $selectedIssue) { issue in
                    IssueRowView(repo: repo, issue: issue)
                        .tag(issue)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(repo.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.refreshIssues(for: repo.fullName) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task(id: repo.fullName) {
            await appState.refreshIssues(for: repo.fullName)
        }
    }
}
