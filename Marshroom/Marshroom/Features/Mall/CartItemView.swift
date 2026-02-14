import SwiftUI

struct CartItemView: View {
    @Environment(AppStateManager.self) private var appState
    let item: CartItem

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 8, height: 8)
                    Text(item.status.displayName)
                        .font(.caption2)
                        .foregroundStyle(item.status.color)

                    // Show sub-status for pending items
                    if let subStatus = item.pendingSubStatus {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(subStatus.color)
                            .frame(width: 8, height: 8)
                        Text(subStatus.rawValue)
                            .font(.caption2)
                            .foregroundStyle(subStatus.color)
                    }

                    if let prNumber = item.prNumber {
                        Text("PR #\(prNumber)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                }

                Text(item.repo.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("#\(item.issue.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(item.issue.title)
                        .font(.body)
                        .lineLimit(1)
                }
                Text(item.branchName)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()

            if item.prURL != nil {
                Button {
                    openPR()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Open PR in browser")
            }

            Button(role: .destructive) {
                appState.removeIssueFromCart(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openPR()
        }
    }

    private func openPR() {
        guard let urlString = item.prURL,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
