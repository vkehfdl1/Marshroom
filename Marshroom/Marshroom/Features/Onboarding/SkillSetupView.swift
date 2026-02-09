import SwiftUI

struct SkillSetupView: View {
    @State private var copied = false

    let onComplete: () -> Void

    private let installCommand = "npx skills add https://github.com/vkehfdl1/Marshroom/tree/main/marshroom-skills"

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Install Claude Code Skills")
                .font(.title2.bold())

            Text("Install the Marshroom skills for Claude Code in your project.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                Text("Available Skills:")
                    .font(.headline)

                SkillRow(name: "/start-issue", description: "Read active issue from state.json, create branch")
                SkillRow(name: "/create-pr", description: "Create PR with Closes #N in body")
                SkillRow(name: "/validate-pr", description: "Validate PR branch name and body")
            }
            .frame(maxWidth: 400, alignment: .leading)

            GroupBox {
                HStack {
                    Text(installCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(installCommand, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 400)

            Text("Run this command from your project root to install the skills.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct SkillRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Text(name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .frame(width: 120, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
