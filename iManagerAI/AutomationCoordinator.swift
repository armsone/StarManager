import UIKit

/// 기본 실행의 자동화 미디어 선택, Home Screen의 카메라 퀵 액션, 공유 확장 사진 배치를
/// SwiftUI 컴포저 흐름으로 전달하는 다리 역할.
@MainActor
final class AutomationCoordinator: ObservableObject {
    static let shared = AutomationCoordinator()

    static let cameraShortcutItemType = "com.armsone.iManagerAI.camera"
    static let legacyCameraShortcutItemTypes: Set<String> = [
        "com.armsone.iManager.camera",
        "com.armsone.StarManager.camera",
    ]
    static let automationShortcutItemType = "com.armsone.iManagerAI.automation"
    static let urlScheme = "imanagerai"
    static let legacyURLSchemes: Set<String> = ["imanager", "starmanager"]
    static let urlHost = "automation"

    /// 설정에서 선택한 자동화 사용 여부. 사용자가 직접 켜기 전까지는 기본적으로 꺼져 있다.
    @Published private(set) var isAutomationEnabled: Bool
    /// 일반 앱 실행 트리거 — 자동화를 사용하는 경우 사진 선택기를 띄운다.
    @Published private(set) var trigger: UUID?
    /// 카메라 퀵 액션 트리거 — 컴포저의 촬영 화면을 바로 띄운다.
    @Published private(set) var cameraTrigger: UUID?
    /// 공유 확장 트리거 — 사진 선택기 없이 공유 보관함의 사진을 바로 컴포저에 채운다.
    @Published private(set) var shareBatchTrigger: UUID?

    private init(defaults: UserDefaults = .standard) {
        let hasSavedPreference = defaults.object(forKey: SharedGenerationSettings.automationEnabledKey) != nil
        let isEnabled = hasSavedPreference
            ? defaults.bool(forKey: SharedGenerationSettings.automationEnabledKey)
            : false
        isAutomationEnabled = isEnabled
        trigger = isEnabled ? UUID() : nil
    }

    /// 설정 변경은 즉시 반영하되, 켜는 순간 설정 화면 위에 사진 선택기를 띄우지는 않는다.
    func setAutomationEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: SharedGenerationSettings.automationEnabledKey)
        isAutomationEnabled = isEnabled
        if !isEnabled {
            trigger = nil
        }
    }

    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // 퀵 액션의 명시적인 요청이므로 설정의 "자동화 사용" 여부와 관계없이 바로 시작한다.
        if shortcutItem.type == Self.automationShortcutItemType {
            cameraTrigger = nil
            trigger = UUID()
            return true
        }
        guard shortcutItem.type == Self.cameraShortcutItemType
            || Self.legacyCameraShortcutItemTypes.contains(shortcutItem.type) else { return false }
        trigger = nil
        cameraTrigger = UUID()
        return true
    }

    func clear(_ requestID: UUID) {
        guard trigger == requestID else { return }
        trigger = nil
    }

    func clearCameraTrigger(_ requestID: UUID) {
        guard cameraTrigger == requestID else { return }
        cameraTrigger = nil
    }

    func clearShareBatchTrigger(_ requestID: UUID) {
        guard shareBatchTrigger == requestID else { return }
        shareBatchTrigger = nil
    }

    /// 공유 확장이 연 `imanagerai://automation` URL을 처리한다(예전 `imanager://automation`, `starmanager://automation`도 계속 받는다).
    /// URL 자체는 신호일 뿐이며, 실제 사진 데이터는 항상 공유 보관함에서 읽는다.
    @discardableResult
    func handle(openURL url: URL) -> Bool {
        guard let scheme = url.scheme,
              scheme == Self.urlScheme || Self.legacyURLSchemes.contains(scheme),
              url.host == Self.urlHost else { return false }
        trigger = nil
        cameraTrigger = nil
        checkForPendingShareBatch()
        return true
    }

    /// 공유 확장에서 앱을 여는 데 실패해 사용자가 직접 다시 실행했을 때도,
    /// 대기 중인 배치가 있으면 자동으로 자동화를 시작한다.
    func checkForPendingShareBatch() {
        guard shareBatchTrigger == nil, SharedInbox.oldestPendingBatch() != nil else { return }
        trigger = nil
        cameraTrigger = nil
        shareBatchTrigger = UUID()
    }

    /// 앱이 충분히 오래 백그라운드에 머문 뒤 돌아오면 새 기본 자동화 세션을 시작한다.
    /// 공유 확장과 카메라 퀵 액션으로 전달된 명시적인 입력은 항상 우선한다.
    func requestFreshAutomationSession() {
        guard isAutomationEnabled,
              shareBatchTrigger == nil,
              cameraTrigger == nil,
              SharedInbox.oldestPendingBatch() == nil else { return }
        trigger = UUID()
    }
}

final class IManagerAIAppDelegate: NSObject, UIApplicationDelegate {
    let automationCoordinator = AutomationCoordinator.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            _ = automationCoordinator.handle(shortcutItem)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            _ = automationCoordinator.handle(shortcutItem)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = IManagerAISceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(automationCoordinator.handle(shortcutItem))
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        automationCoordinator.handle(openURL: url)
    }
}

final class IManagerAISceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let urlContext = connectionOptions.urlContexts.first {
            _ = AutomationCoordinator.shared.handle(openURL: urlContext.url)
        }
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = AutomationCoordinator.shared.handle(shortcutItem)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first else { return }
        _ = AutomationCoordinator.shared.handle(openURL: urlContext.url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AutomationCoordinator.shared.checkForPendingShareBatch()
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(AutomationCoordinator.shared.handle(shortcutItem))
    }
}
