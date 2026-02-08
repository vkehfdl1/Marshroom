import SwiftUI

struct RepoSettingsView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.highlightRepos.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "building.columns",
                    description: Text("Add repositories to track their issues")
                )
            } else {
                List {
                    ForEach(appState.highlightRepos) { repo in
                        HStack {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "building.columns.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(repo.fullName).font(.body)
                                Text(repo.owner.login).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                appState.removeRepo(repo)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { indices, newOffset in
                        appState.highlightRepos.move(fromOffsets: indices, toOffset: newOffset)
                        appState.settings.pinnedRepoNames = appState.highlightRepos.map(\.fullName)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Repository", systemImage: "plus")
                }
                .padding(8)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RepoSearchView(onNext: { showAddSheet = false })
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}
