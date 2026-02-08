import SwiftUI

struct RepoListView: View {
    @Environment(AppStateManager.self) private var appState
    @Binding var selectedRepo: GitHubRepo?
    @Binding var showAddSheet: Bool

    var body: some View {
        List(selection: $selectedRepo) {
            Section("Pinned Repositories") {
                ForEach(appState.highlightRepos) { repo in
                    Label {
                        VStack(alignment: .leading) {
                            Text(repo.name)
                                .font(.body)
                            Text(repo.owner.login)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: repo.isPrivate ? "lock.fill" : "building.columns.fill")
                            .foregroundStyle(.secondary)
                    }
                    .tag(repo)
                    .contextMenu {
                        Button("Remove", role: .destructive) {
                            if selectedRepo?.fullName == repo.fullName {
                                selectedRepo = nil
                            }
                            appState.removeRepo(repo)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Repos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
