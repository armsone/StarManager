import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case composer, reset, settings }

    @State private var selectedTab = Tab.composer
    @State private var resetRequest = UUID()
    @Environment(\.brandTheme) private var theme

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { tab in
                if tab == .reset {
                    selectedTab = .composer
                    resetRequest = UUID()
                } else {
                    selectedTab = tab
                }
            }
        )) {
            NavigationStack {
                ComposerView(resetRequest: resetRequest)
            }
            .tabItem {
                Label("스튜디오", systemImage: "sparkles")
            }
            .tag(Tab.composer)

            Color.clear
                .tabItem {
                    Label("새 캔버스", systemImage: "arrow.counterclockwise.circle")
                }
                .tag(Tab.reset)

            NavigationStack {
                ProfileSettingsView()
            }
            .tabItem {
                Label("설정", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .foregroundStyle(theme.ink)
    }
}

#Preview {
    ContentView()
        .environmentObject(CreatorProfileStore())
}
