import SwiftUI

struct CartItemView: View {
    @Environment(AppStateManager.self) private var appState
    let item: CartItem

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
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

            Button(role: .destructive) {
                appState.removeIssueFromCart(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
