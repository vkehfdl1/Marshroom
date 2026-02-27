import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var showPATAlert = false
    @State private var newPAT = ""
    @State private var patUpdateMessage: String?
    @State private var stateFilePath: String = ""

    var body: some View {
        Form {
            Section("GitHub Authentication") {
                HStack {
                    if let user = appState.currentUser {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.green)
                        Text("Signed in as \(user.login)")
                    } else {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                        Text("Not authenticated")
                    }
                    Spacer()
                    Button("Update PAT") {
                        showPATAlert = true
                    }
                }

                if let message = patUpdateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.contains("Error") ? .red : .green)
                }
            }

            Section("Polling") {
                HStack {
                    Text("Interval: \(appState.settings.pollingIntervalSeconds)s")
                    Slider(
                        value: .init(
                            get: { Double(appState.settings.pollingIntervalSeconds) },
                            set: { appState.settings.pollingIntervalSeconds = Int($0) }
                        ),
                        in: Double(Constants.minPollingIntervalSeconds)...Double(Constants.maxPollingIntervalSeconds),
                        step: 5
                    )
                }
            }

            Section("State File") {
                HStack {
                    TextField("Path", text: $stateFilePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes = [.json]
                        panel.directoryURL = URL(fileURLWithPath: (stateFilePath as NSString).deletingLastPathComponent)
                        if panel.runModal() == .OK, let url = panel.url {
                            stateFilePath = url.path
                            applyStateFilePath()
                        }
                    }
                    Button("Reset") {
                        stateFilePath = Constants.defaultStateFilePath
                        appState.settings.customStateFilePath = nil
                        appState.restartFileWatcher()
                    }
                    .foregroundStyle(.secondary)
                }

                if Constants.stateFileIsRemote {
                    Label("Remote path detected — using poll-based file watching", systemImage: "network")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let envPath = ProcessInfo.processInfo.environment["MARSHROOM_STATE"], !envPath.isEmpty {
                    Label("Overridden by MARSHROOM_STATE env var: \(envPath)", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            stateFilePath = Constants.stateFilePath
        }
        .sheet(isPresented: $showPATAlert) {
            VStack(spacing: 16) {
                Text("Update Personal Access Token")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Token type: **Classic** personal access token", systemImage: "key.fill")
                    Label("Scope: **repo** — Full control of private repositories", systemImage: "checkmark.circle.fill")
                    Label("Expiration: **90 days** recommended", systemImage: "calendar.badge.clock")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 300, alignment: .leading)

                SecureField("New PAT", text: $newPAT)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Link("Create Token", destination: URL(string: "https://github.com/settings/tokens/new")!)
                        .font(.caption)
                    Spacer()
                    Button("Cancel") { showPATAlert = false }
                    Button("Save") { updatePAT() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPAT.isEmpty)
                }
                .frame(width: 300)
            }
            .padding()
        }
    }

    private func applyStateFilePath() {
        let path = stateFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path == Constants.defaultStateFilePath || path.isEmpty {
            appState.settings.customStateFilePath = nil
        } else {
            appState.settings.customStateFilePath = path
        }
        appState.restartFileWatcher()
    }

    private func updatePAT() {
        Task {
            do {
                _ = try await appState.validateAndSavePAT(newPAT)
                patUpdateMessage = "PAT updated successfully"
                showPATAlert = false
                newPAT = ""
            } catch {
                patUpdateMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
