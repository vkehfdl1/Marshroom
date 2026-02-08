import SwiftUI

struct IssueListView: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo
    @Binding var selectedIssue: GitHubIssue?
    @State private var showComposer = false

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
                VStack(spacing: 0) {
                    if showComposer {
                        IssueComposerView(repo: repo)
                        Divider()
                    }

                    List(selection: $selectedIssue) {
                        ForEach(issues) { issue in
                            IssueRowView(repo: repo, issue: issue)
                                .tag(issue)
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle(repo.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        showComposer.toggle()
                    } label: {
                        Image(systemName: showComposer ? "minus.circle" : "plus.circle")
                    }
                    .help(showComposer ? "Hide composer" : "New issue")

                    Button {
                        Task { await appState.refreshIssues(for: repo.fullName) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task(id: repo.fullName) {
            await appState.refreshIssues(for: repo.fullName)
        }
    }
}
