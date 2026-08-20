import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ComposerView()
            }
            .tabItem {
                Label("만들기", systemImage: "sparkles")
            }

            NavigationStack {
                ProfileSettingsView()
            }
            .tabItem {
                Label("내 설정", systemImage: "person.crop.circle")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CreatorProfileStore())
}
