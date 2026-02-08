import SwiftUI

struct SkillSetupView: View {
    @State private var copied = false

    let onComplete: () -> Void

    private let installCommand = """
    # From your project root:
    curl -fsSL https://raw.githubusercontent.com/your-org/marshroom/main/Skills/install-skill.sh | bash
    """

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Install Claude Code Skills")
                .font(.title2.bold())

            Text("Copy the Claude Code slash commands to your project's `.claude/commands/` directory.")
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

            Text("You can also copy the files manually from the Skills/ directory.")
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
