import SwiftUI

@main
struct StarManagerApp: App {
    @StateObject private var profileStore = CreatorProfileStore()
    @AppStorage(BrandTheme.appearanceStorageKey) private var appearanceStyleRaw = AppearanceStyle.bk.rawValue

    private var theme: BrandTheme {
        BrandTheme(style: AppearanceStyle(rawValue: appearanceStyleRaw) ?? .bk)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(theme.controlTint)
                .preferredColorScheme(.light)
                .environment(\.brandTheme, theme)
                .environmentObject(profileStore)
        }
    }
}
