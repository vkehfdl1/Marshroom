import SwiftUI

struct RepoSearchView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var searchText = ""
    @State private var searchResults: [GitHubRepo] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Add Repositories")
                .font(.title2.bold())

            Text("Search for repositories to track issues from")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Search repositories...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: 500)

            // Added repos
            if !appState.highlightRepos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Added Repositories")
                        .font(.headline)
                    ForEach(appState.highlightRepos) { repo in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(repo.fullName)
                            Spacer()
                            Button("Remove") {
                                appState.removeRepo(repo)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(maxWidth: 500, alignment: .leading)
            }

            // Search results
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(searchResults) { repo in
                            RepoSearchRow(repo: repo)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(6)
                        }
                    }
                }
                .frame(maxWidth: 500, maxHeight: 200)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()

            Button("Continue") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.highlightRepos.isEmpty)
        }
        .padding()
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            errorMessage = nil
            do {
                guard let client = appState.apiClient else { return }
                let result = try await client.searchRepos(query: searchText)
                searchResults = result.items
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}
