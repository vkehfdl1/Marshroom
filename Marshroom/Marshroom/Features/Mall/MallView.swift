import SwiftUI

struct MallView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var selectedRepo: GitHubRepo?
    @State private var selectedIssue: GitHubIssue?
    @State private var showAddRepoSheet = false

    var body: some View {
        NavigationSplitView {
            RepoListView(selectedRepo: $selectedRepo, showAddSheet: $showAddRepoSheet)
        } content: {
            if let repo = selectedRepo {
                IssueListView(repo: repo, selectedIssue: $selectedIssue)
            } else {
                ContentUnavailableView(
                    "Select a Repository",
                    systemImage: "building.columns",
                    description: Text("Choose a repository from the sidebar to browse issues")
                )
            }
        } detail: {
            VStack(spacing: 0) {
                if let repo = selectedRepo, let issue = selectedIssue {
                    IssueDetailView(repo: repo, issue: issue)
                } else {
                    ContentUnavailableView(
                        "Select an Issue",
                        systemImage: "doc.text",
                        description: Text("Choose an issue from the list to view details")
                    )
                }
                Divider()
                CartView()
                    .frame(height: 250)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedRepo) {
            selectedIssue = nil
            appState.settings.selectedRepoFullName = selectedRepo?.fullName
        }
        .onAppear {
            if selectedRepo == nil, let saved = appState.settings.selectedRepoFullName {
                selectedRepo = appState.highlightRepos.first { $0.fullName == saved }
            }
        }
        .sheet(isPresented: $showAddRepoSheet) {
            AddRepoSheet(isPresented: $showAddRepoSheet)
                .frame(minWidth: 400, minHeight: 300)
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

// MARK: - Add Repo Sheet

private struct AddRepoSheet: View {
    @Environment(AppStateManager.self) private var appState
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var results: [GitHubRepo] = []
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Repository")
                .font(.headline)

            HStack {
                TextField("Search repositories...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { search() }
                if isSearching {
                    ProgressView().controlSize(.small)
                }
            }

            List(results) { repo in
                RepoSearchRow(repo: repo)
            }

            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func search() {
        guard !searchText.isEmpty, let client = appState.apiClient else { return }
        isSearching = true
        Task {
            do {
                let result = try await client.searchRepos(query: searchText)
                results = result.items
            } catch {}
            isSearching = false
        }
    }
}

// MARK: - Shared Repo Search Row

struct RepoSearchRow: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo

    private var isAdded: Bool {
        appState.highlightRepos.contains { $0.fullName == repo.fullName }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(repo.fullName).font(.body.bold())
                if let desc = repo.description {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if isAdded {
                Image(systemName: "checkmark").foregroundStyle(.green)
            } else {
                Button {
                    appState.addRepoToHighlights(repo)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
