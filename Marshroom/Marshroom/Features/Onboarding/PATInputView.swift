import SwiftUI

struct PATInputView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var patInput = ""
    @State private var isValidating = false
    @State private var validatedUser: GitHubUser?
    @State private var errorMessage: String?

    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("GitHub Personal Access Token")
                .font(.title2.bold())

            tokenGuideView

            SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $patInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)

            if let user = validatedUser {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Authenticated as \(user.login)")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .frame(maxWidth: 400)
            }

            HStack(spacing: 12) {
                Button(action: validateAndContinue) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(validatedUser != nil ? "Continue" : "Validate & Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(patInput.isEmpty || isValidating)

                Link("Create Token on GitHub", destination: URL(string: "https://github.com/settings/tokens/new")!)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private var tokenGuideView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create a **Classic personal access token** at GitHub Settings > Developer settings > Personal access tokens (classic).")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Label("Expiration: **90 days** recommended (no expiration is possible but discouraged)", systemImage: "calendar.badge.clock")
                Label {
                    Text("Scope: **repo** — Full control of private repositories")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                Label("Org access: after creation, authorize each org via **Configure SSO** if the org uses SAML SSO", systemImage: "building.2")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
        .frame(maxWidth: 440)
    }

    private func validateAndContinue() {
        if validatedUser != nil {
            onNext()
            return
        }

        isValidating = true
        errorMessage = nil

        Task {
            do {
                let user = try await appState.validateAndSavePAT(patInput)
                validatedUser = user
            } catch {
                errorMessage = error.localizedDescription
            }
            isValidating = false
        }
    }
}
