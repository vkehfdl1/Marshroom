import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var showPATAlert = false
    @State private var newPAT = ""
    @State private var patUpdateMessage: String?

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

            Section("Completion Tracking") {
                Picker("Day resets at", selection: Binding(
                    get: { appState.settings.completionResetHour },
                    set: {
                        appState.settings.completionResetHour = $0
                        appState.resetCompletionsIfNewDay()
                    }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
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
        }
        .formStyle(.grouped)
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
