import SwiftUI

struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            RepoSettingsView()
                .tabItem { Label("Repositories", systemImage: "building.columns") }

            AISettingsView()
                .tabItem { Label("AI", systemImage: "sparkles") }
        }
        .frame(width: 450, height: 350)
    }
}
