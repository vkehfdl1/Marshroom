import SwiftUI

struct MenuBarView: View {
    @Environment(AppStateManager.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Today's Issues")
                    .font(.headline)
                Spacer()
                Text("\(appState.todayCart.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Status summary bar
            if !appState.todayCart.isEmpty || appState.todayCompletions > 0 {
                HStack(spacing: 10) {
                    ForEach([IssueStatus.running, .pending, .soon], id: \.self) { status in
                        let count = appState.todayCart.filter { $0.status == status }.count
                        if count > 0 {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 8, height: 8)
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if appState.todayCompletions > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("\(appState.todayCompletions)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
            }

            if appState.todayCart.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No issues for today")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Add issues from the main window")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Issue list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.todayCart) { item in
                            MenuBarIssueRow(item: item)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Marshroom" || $0.className.contains("SwiftUI") }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Marshroom")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .onAppear {
            appState.resetCompletionsIfNewDay()
        }
    }
}

private struct MenuBarIssueRow: View {
    let item: CartItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.status.iconName)
                .font(.caption)
                .foregroundStyle(item.status.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("#\(item.issue.number)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(item.issue.title)
                        .font(.callout)
                        .lineLimit(1)
                }
                Text(item.repo.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.status.displayName)
                .font(.caption2)
                .foregroundStyle(item.status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
