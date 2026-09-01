import SwiftUI
import UIKit

@main
struct IManagerAIApp: App {
    @UIApplicationDelegateAdaptor(IManagerAIAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var profileStore = CreatorProfileStore()
    @StateObject private var automationCoordinator = AutomationCoordinator.shared
    @StateObject private var aiAvailabilityStore = AIProviderAvailabilityStore()
    @StateObject private var aiRunMetricsStore = AIRunMetricsStore()
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
                .environmentObject(aiAvailabilityStore)
                .environmentObject(aiRunMetricsStore)
                .onOpenURL { url in
                    // 잠금 화면 위젯의 `imanagerai://open`은 앱만 열고 기본 화면을 유지한다.
                    guard url.scheme == "imanagerai", url.host == "open" else { return }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        backgroundedAt = Date()
                    case .active:
                        resetStaleAlternateIconIfNeeded()
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

    private func resetStaleAlternateIconIfNeeded() {
        // 데이터 보존 업데이트 후 남은 AppIconInterstellar alternate 상태를 primary 아이콘으로 되돌린다.
        guard theme.style == .interstellar,
              UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != nil else { return }
        UIApplication.shared.setAlternateIconName(nil)
    }
}
