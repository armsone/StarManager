import SwiftUI

@main
struct IManagerAIApp: App {
    @UIApplicationDelegateAdaptor(IManagerAIAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var profileStore = CreatorProfileStore()
    @StateObject private var automationCoordinator = AutomationCoordinator.shared
    @State private var backgroundedAt: Date?
    @AppStorage(BrandTheme.appearanceStorageKey) private var appearanceStyleRaw = AppearanceStyle.bk.rawValue

    private var theme: BrandTheme {
        BrandTheme(style: AppearanceStyle(rawValue: appearanceStyleRaw) ?? .bk)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(theme.controlTint)
                .preferredColorScheme(theme.style == .interstellar ? .dark : .light)
                .environment(\.brandTheme, theme)
                .environmentObject(profileStore)
                .environmentObject(automationCoordinator)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        backgroundedAt = Date()
                    case .active:
                        guard let backgroundedAt else { return }
                        self.backgroundedAt = nil
                        guard Date().timeIntervalSince(backgroundedAt) >= 15 else { return }
                        automationCoordinator.requestFreshAutomationSession()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
