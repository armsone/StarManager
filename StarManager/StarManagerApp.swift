import SwiftUI

@main
struct StarManagerApp: App {
    @StateObject private var profileStore = CreatorProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(BrandTheme.accent)
                .preferredColorScheme(.light)
                .environmentObject(profileStore)
        }
    }
}
