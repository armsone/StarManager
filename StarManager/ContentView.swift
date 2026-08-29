import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case composer, reset, settings }

    @State private var selectedTab = Tab.composer
    @State private var resetRequest = UUID()
    @Environment(\.brandTheme) private var theme
    @EnvironmentObject private var automationCoordinator: AutomationCoordinator

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
        .onChange(of: automationCoordinator.trigger, initial: true) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = .composer
        }
        .onChange(of: automationCoordinator.cameraTrigger, initial: true) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = .composer
        }
        .onChange(of: automationCoordinator.shareBatchTrigger, initial: true) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = .composer
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CreatorProfileStore())
        .environmentObject(AutomationCoordinator.shared)
}
