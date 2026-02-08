import SwiftUI

struct IssueComposerView: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo

    @State private var rawInput = ""
    @State private var generatedTitle = ""
    @State private var isGenerating = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Issue")
                .font(.headline)

            TextEditor(text: $rawInput)
                .font(.body)
                .frame(minHeight: 60, idealHeight: 100)
                .border(Color.secondary.opacity(0.3))
                .overlay(alignment: .topLeading) {
                    if rawInput.isEmpty {
                        Text("What needs to be done?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button {
                    Task { await generateTitle() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Generate Title", systemImage: "sparkles")
                    }
                }
                .disabled(rawInput.isEmpty || isGenerating || !appState.settings.hasAnthropicKey)
                .keyboardShortcut(.return, modifiers: .command)

                if !appState.settings.hasAnthropicKey {
                    Text("Set up AI key in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !generatedTitle.isEmpty {
                TextField("Issue title", text: $generatedTitle)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await createIssue() }
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Create Issue", systemImage: "plus.circle.fill")
                    }
                }
                .disabled(generatedTitle.isEmpty || isCreating)
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func generateTitle() async {
        guard let client = appState.anthropicClient else {
            errorMessage = "Anthropic client not initialized. Try re-saving your API key in Settings."
            return
        }
        isGenerating = true
        errorMessage = nil

        do {
            let claudeMd = appState.claudeMdCache(for: repo.fullName)
            let title = try await client.generateTitle(
                rawInput: rawInput,
                claudeMd: claudeMd,
                repoName: repo.fullName
            )
            generatedTitle = title
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    private func createIssue() async {
        guard let client = appState.apiClient else { return }
        isCreating = true
        errorMessage = nil

        do {
            let body = rawInput.isEmpty ? nil : rawInput
            let _ = try await client.createIssue(repo: repo.fullName, title: generatedTitle, body: body)
            // Reset form
            rawInput = ""
            generatedTitle = ""
            // Refresh issue list
            await appState.refreshIssues(for: repo.fullName)
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}
