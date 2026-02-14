import SwiftUI

struct CartView: View {
    @Environment(AppStateManager.self) private var appState

    private var soonItems: [CartItem] {
        appState.todayCart.filter { $0.status == .soon }
    }

    private var runningItems: [CartItem] {
        appState.todayCart.filter { $0.status == .running }
    }

    private var pendingItems: [CartItem] {
        appState.todayCart.filter { $0.status == .pending }
    }

    private var completedItems: [CartItem] {
        appState.todayCart.filter { $0.status == .completed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cart.fill")
                Text("Today's Cart")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    ForEach([IssueStatus.running, .pending, .soon], id: \.self) { status in
                        let count = appState.todayCart.filter { $0.status == status }.count
                        if count > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: status.iconName)
                                    .font(.caption2)
                                Text("\(count)")
                                    .font(.caption)
                            }
                            .foregroundStyle(status.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(status.color.opacity(0.12), in: Capsule())
                        }
                    }
                    if appState.todayCompletions > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("\(appState.todayCompletions)")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding()

            Divider()

            if appState.todayCart.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "cart")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Cart is Empty")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Browse issues and add them to today's cart")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !runningItems.isEmpty {
                        Section {
                            ForEach(runningItems) { item in
                                CartItemView(item: item)
                            }
                        } header: {
                            Label("Running", systemImage: IssueStatus.running.iconName)
                                .foregroundStyle(IssueStatus.running.color)
                        }
                    }

                    if !pendingItems.isEmpty {
                        // Group pending items by sub-status
                        let pendingGroups = Dictionary(grouping: pendingItems) { item in
                            item.pendingSubStatus ?? .justCreated
                        }

                        // Sort by sub-status order (1 → 4)
                        let sortedSubStatuses = pendingGroups.keys.sorted { $0.order < $1.order }

                        ForEach(sortedSubStatuses, id: \.self) { subStatus in
                            if let items = pendingGroups[subStatus], !items.isEmpty {
                                Section {
                                    ForEach(items) { item in
                                        CartItemView(item: item)
                                    }
                                } header: {
                                    HStack(spacing: 6) {
                                        Image(systemName: subStatus.iconName)
                                        Text(subStatus.rawValue)
                                    }
                                    .foregroundStyle(subStatus.color)
                                }
                            }
                        }
                    }

                    if !soonItems.isEmpty {
                        Section {
                            ForEach(soonItems) { item in
                                CartItemView(item: item)
                            }
                        } header: {
                            Label("Soon", systemImage: IssueStatus.soon.iconName)
                                .foregroundStyle(IssueStatus.soon.color)
                        }
                    }

                    if !completedItems.isEmpty {
                        Section {
                            ForEach(completedItems) { item in
                                CartItemView(item: item)
                            }
                        } header: {
                            Label("Completed", systemImage: IssueStatus.completed.iconName)
                                .foregroundStyle(IssueStatus.completed.color)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
