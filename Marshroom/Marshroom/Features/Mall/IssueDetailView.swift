import SwiftUI

struct IssueDetailView: View {
    @Environment(AppStateManager.self) private var appState
    let repo: GitHubRepo
    let issue: GitHubIssue

    private var isInCart: Bool {
        appState.todayCart.contains { $0.id == "\(repo.fullName)#\(issue.number)" }
    }

    private var createdDate: String {
        formatDate(issue.createdAt)
    }

    private var updatedDate: String {
        formatDate(issue.updatedAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(issue.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(issue.title)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                }

                // Metadata
                HStack(spacing: 16) {
                    if !issue.assignees.isEmpty {
                        Label(issue.assignees.map(\.login).joined(separator: ", "), systemImage: "person.circle")
                            .font(.caption)
                    } else {
                        Label("Unassigned", systemImage: "person.circle")
                            .font(.caption)
                    }
                    Label(createdDate, systemImage: "calendar")
                        .font(.caption)
                    if issue.createdAt != issue.updatedAt {
                        Label("Updated \(updatedDate)", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                // Labels
                if !issue.labels.isEmpty {
                    FlowLayout(spacing: 6) {
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
                }

                Divider()

                // Body
                if let body = issue.body, !body.isEmpty {
                    Text(body)
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    Text("No description provided.")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("#\(issue.number)")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isInCart {
                    Label("In Cart", systemImage: "cart.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Button {
                        appState.addIssueToCart(repo: repo, issue: issue)
                    } label: {
                        Label("Add to Cart", systemImage: "cart.badge.plus")
                    }
                }

                if let url = URL(string: issue.htmlURL) {
                    Link(destination: url) {
                        Label("Open in GitHub", systemImage: "safari")
                    }
                }
            }
        }
    }

    private func formatDate(_ isoString: String) -> String {
        if let date = Constants.iso8601Formatter.date(from: isoString) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return isoString
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
