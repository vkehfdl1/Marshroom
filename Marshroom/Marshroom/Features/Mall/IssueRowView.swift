import SwiftUI

struct IssueRowView: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo
    let issue: GitHubIssue

    private var isInCart: Bool {
        appState.todayCart.contains { $0.id == "\(repo.fullName)#\(issue.number)" }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(issue.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(issue.title)
                        .font(.body)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    ForEach(issue.labels) { label in
                        Text(label.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: label.color).opacity(0.2))
                            .foregroundStyle(Color(hex: label.color))
                            .cornerRadius(4)
                    }
                }

                if !issue.assignees.isEmpty {
                    Text(issue.assignees.map(\.login).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isInCart {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    appState.addIssueToCart(repo: repo, issue: issue)
                } label: {
                    Image(systemName: "cart.badge.plus")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
