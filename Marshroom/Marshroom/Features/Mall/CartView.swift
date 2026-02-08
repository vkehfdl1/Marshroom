import SwiftUI

struct CartView: View {
    @Environment(AppStateManager.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cart.fill")
                Text("Today's Cart")
                    .font(.headline)
                Spacer()
                Text("\(appState.todayCart.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    ForEach(appState.todayCart) { item in
                        CartItemView(item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
