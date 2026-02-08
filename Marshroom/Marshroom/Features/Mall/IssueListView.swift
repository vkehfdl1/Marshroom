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
        VStack(spacing: 0) {
            // Inline action buttons — always visible when repo is selected
            HStack {
                Spacer()
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
            .padding(.horizontal)
            .padding(.vertical, 6)

            // Composer — always reachable, outside the empty/non-empty conditional
            if showComposer {
                IssueComposerView(repo: repo)
                Divider()
            }

            // Content: loading / empty / list
            if appState.isLoading && issues.isEmpty {
                ProgressView("Loading issues...")
                    .frame(maxHeight: .infinity)
            } else if issues.isEmpty {
                ContentUnavailableView(
                    "No Open Issues",
                    systemImage: "checkmark.circle",
                    description: Text("This repository has no open issues")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selectedIssue) {
                    ForEach(issues) { issue in
                        IssueRowView(repo: repo, issue: issue)
                            .tag(issue)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(repo.name)
        .task(id: repo.fullName) {
            await appState.refreshIssues(for: repo.fullName)
        }
    }
}
