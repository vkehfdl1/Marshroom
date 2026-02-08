import SwiftUI

struct AISettingsView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var apiKey = ""
    @State private var isConfigured = KeychainService.loadAnthropicKey() != nil
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Status:")
                    if isConfigured {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Configured", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                SecureField("Anthropic API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        saveKey()
                    }
                    .disabled(apiKey.isEmpty)

                    if isConfigured {
                        Button("Delete", role: .destructive) {
                            deleteKey()
                        }

                        Button {
                            Task { await testConnection() }
                        } label: {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .disabled(isTesting)
                    }
                }

                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.contains("Success") ? Color.green : Color.red)
                }
            } header: {
                Text("Anthropic API")
            } footer: {
                Text("Used for AI-powered issue title generation. Get your key at console.anthropic.com")
            }
        }
        .formStyle(.grouped)
    }

    private func saveKey() {
        do {
            try KeychainService.saveAnthropicKey(apiKey)
            isConfigured = true
            apiKey = ""
            testResult = nil
            appState.refreshAnthropicClient()
        } catch {
            testResult = "Save failed: \(error.localizedDescription)"
        }
    }

    private func deleteKey() {
        KeychainService.deleteAnthropicKey()
        isConfigured = false
        apiKey = ""
        testResult = nil
        appState.refreshAnthropicClient()
    }

    private func testConnection() async {
        guard let key = KeychainService.loadAnthropicKey() else {
            testResult = "No API key found"
            return
        }

        isTesting = true
        testResult = nil

        let client = AnthropicClient(apiKey: key)
        do {
            let success = try await client.testConnection()
            testResult = success ? "Success! Connection verified." : "Connection failed."
        } catch {
            testResult = "Error: \(error.localizedDescription)"
        }

        isTesting = false
    }
}
