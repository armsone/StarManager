import SwiftUI

private enum ComposerTab: Hashable, CaseIterable { case composer, newAction, settings }

struct ContentView: View {
    private let tabBarBottomSpacing: CGFloat = 8

    @State private var selectedTab = ComposerTab.composer
    @State private var resetRequest = UUID()
    @EnvironmentObject private var automationCoordinator: AutomationCoordinator
    @StateObject private var composerNavState = ComposerNavState()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == .settings {
                    NavigationStack {
                        ProfileSettingsView()
                    }
                } else {
                    NavigationStack {
                        ComposerView(resetRequest: resetRequest)
                    }
                }
            }
            .safeAreaPadding(.bottom, 72)

            FloatingTabBar(
                selectedTab: $selectedTab,
                hasSendableContent: composerNavState.hasSendableContent,
                sendChoice: composerNavState.sendChoice,
                onSend: { composerNavState.requestSend() },
                onLongPress: {
                    selectedTab = .composer
                    composerNavState.requestAIChoiceReveal()
                }
            )
            .padding(.horizontal, 72)
            .padding(.bottom, tabBarBottomSpacing)
            .zIndex(2)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(composerNavState)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .newAction {
                resetRequest = UUID()
                selectedTab = .composer
            }
        }
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

private struct FloatingTabBar: View {
    @Binding var selectedTab: ComposerTab
    let hasSendableContent: Bool
    let sendChoice: AIProviderIdentity
    let onSend: () -> Void
    let onLongPress: () -> Void
    @State private var suppressNextSend = false

    var body: some View {
        glassContent
    }

    @ViewBuilder
    private var glassContent: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                tabBarContent
                    .glassEffect(.clear.interactive(), in: .capsule)
            }
        } else {
            tabBarContent
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 0.75))
        }
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            tabButton(
                title: hasSendableContent ? "Send" : "Studio",
                icon: hasSendableContent ? sendChoice.tabBarImage : Image(systemName: "sparkles"),
                tab: .composer
            ) {
                if hasSendableContent {
                    guard !suppressNextSend else {
                        suppressNextSend = false
                        return
                    }
                    selectedTab = .composer
                    DispatchQueue.main.async { onSend() }
                } else {
                    selectedTab = .composer
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    guard hasSendableContent else { return }
                    suppressNextSend = true
                    onLongPress()
                }
            )

            tabButton(title: "New", icon: Image(systemName: "arrow.counterclockwise.circle.fill"), tab: .newAction) {
                selectedTab = .newAction
            }

            tabButton(title: "Setting", icon: Image(systemName: "gearshape.fill"), tab: .settings) {
                selectedTab = .settings
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 6)
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    private func tabButton(title: String, icon: Image, tab: ComposerTab, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedTab == tab ? Color.red : Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selectedTab == tab {
                    selectedGlassBackground
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var selectedGlassBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule().fill(Color.primary.opacity(0.07))
        }
    }
}

/// 네이티브 SwiftUI `TabView`/`UITabBar`의 형태·머티리얼·유리 효과를 100% 그대로 보존하면서,
/// 탭바 하단 위치를 16pt 상향(-16pt 변환)하고 첫 번째 탭(스튜디오/보내기)의 탭 및 롱프레스 제스처를 안정적으로 감지한다.
/// 비공개 서브뷰 검색이나 SwiftUI가 덮어쓸 수 있는 `UITabBarControllerDelegate`에 의존하지 않고,
/// 첫 번째 탭 영역 위에 투명한 `UIControl` 오버레이를 배치해 터치를 전담 처리한다.
private final class FirstTabOverlayControl: UIControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }
}

private final class TabBarBridgeViewController: UIViewController {
    var onLayout: (() -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onLayout?()
    }
}

private struct TabBarGestureBridge: UIViewControllerRepresentable {
    @Binding var selectedTab: ComposerTab
    let hasSendableContent: Bool
    let onSend: () -> Void
    let onLongPressFirstTab: () -> Void

    func makeUIViewController(context: Context) -> TabBarBridgeViewController {
        let controller = TabBarBridgeViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.onLayout = { [weak controller, weak coordinator = context.coordinator] in
            guard let controller, let coordinator else { return }
            guard let tabBar = coordinator.findTabBar(from: controller) else { return }
            coordinator.applyTabBarShiftAndOverlay(to: tabBar)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: TabBarBridgeViewController, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        context.coordinator.hasSendableContent = hasSendableContent
        context.coordinator.onSend = onSend
        context.coordinator.onLongPressFirstTab = onLongPressFirstTab
        uiViewController.onLayout = { [weak uiViewController, weak coordinator = context.coordinator] in
            guard let uiViewController, let coordinator else { return }
            guard let tabBar = coordinator.findTabBar(from: uiViewController) else { return }
            coordinator.applyTabBarShiftAndOverlay(to: tabBar)
        }

        DispatchQueue.main.async {
            guard let tabBar = context.coordinator.findTabBar(from: uiViewController) else { return }
            context.coordinator.applyTabBarShiftAndOverlay(to: tabBar)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedTab: $selectedTab,
            hasSendableContent: hasSendableContent,
            onSend: onSend,
            onLongPressFirstTab: onLongPressFirstTab
        )
    }

    @MainActor
    final class Coordinator: NSObject {
        var selectedTab: Binding<ComposerTab>
        var hasSendableContent: Bool
        var onSend: () -> Void
        var onLongPressFirstTab: () -> Void

        private weak var attachedTabBar: UITabBar?
        private weak var overlayControl: FirstTabOverlayControl?
        private var tapRecognizer: UITapGestureRecognizer?
        private var longPressRecognizer: UILongPressGestureRecognizer?

        init(
            selectedTab: Binding<ComposerTab>,
            hasSendableContent: Bool,
            onSend: @escaping () -> Void,
            onLongPressFirstTab: @escaping () -> Void
        ) {
            self.selectedTab = selectedTab
            self.hasSendableContent = hasSendableContent
            self.onSend = onSend
            self.onLongPressFirstTab = onLongPressFirstTab
        }

        func findTabBar(from viewController: UIViewController) -> UITabBar? {
            if let window = viewController.viewIfLoaded?.window,
               let tabBar = findTabBar(in: window) {
                return tabBar
            }
            if let tabBarController = viewController.tabBarController {
                return tabBarController.tabBar
            }
            var current = viewController.parent
            while let p = current {
                if let tc = p as? UITabBarController {
                    return tc.tabBar
                }
                if let tc = p.tabBarController {
                    return tc.tabBar
                }
                current = p.parent
            }
            if let root = viewController.view.window?.rootViewController {
                if let tc = root as? UITabBarController {
                    return tc.tabBar
                }
                if let tc = root.tabBarController {
                    return tc.tabBar
                }
            }
            for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                for window in scene.windows where !window.isHidden {
                    if let tabBar = findTabBar(in: window) {
                        return tabBar
                    }
                }
            }
            return nil
        }

        private func findTabBar(in view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar { return tabBar }
            for subview in view.subviews {
                if let tabBar = findTabBar(in: subview) { return tabBar }
            }
            return nil
        }

        func applyTabBarShiftAndOverlay(to tabBar: UITabBar) {
            let targetTransform = CGAffineTransform(translationX: 0, y: -100)
            if tabBar.transform != targetTransform {
                tabBar.transform = targetTransform
            }

            let targetFrame = firstTabFrame(in: tabBar)
            guard targetFrame.width > 0, targetFrame.height > 0 else { return }

            if let overlay = overlayControl, overlay.superview === tabBar {
                if overlay.frame != targetFrame {
                    overlay.frame = targetFrame
                }
                tabBar.bringSubviewToFront(overlay)
            } else {
                // 이전 탭바에 남아있던 오버레이 정리
                overlayControl?.removeFromSuperview()

                let overlay = FirstTabOverlayControl(frame: targetFrame)

                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                longPress.minimumPressDuration = 0.5
                longPress.cancelsTouchesInView = true
                self.longPressRecognizer = longPress
                overlay.addGestureRecognizer(longPress)

                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tap.numberOfTapsRequired = 1
                tap.cancelsTouchesInView = true
                tap.require(toFail: longPress)
                self.tapRecognizer = tap
                overlay.addGestureRecognizer(tap)

                tabBar.addSubview(overlay)
                tabBar.bringSubviewToFront(overlay)

                self.overlayControl = overlay
                self.attachedTabBar = tabBar
            }
        }

        private func firstTabFrame(in tabBar: UITabBar) -> CGRect {
            let bounds = tabBar.bounds
            guard bounds.width > 0, bounds.height > 0 else { return .zero }
            let itemCount = CGFloat(max(1, tabBar.items?.count ?? 3))
            guard itemCount > 0 else { return .zero }
            let itemWidth = bounds.width / itemCount
            guard itemWidth > 0 else { return .zero }

            let isRTL = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
            let originX: CGFloat = isRTL ? (bounds.width - itemWidth) : 0
            return CGRect(x: originX, y: 0, width: itemWidth, height: bounds.height)
        }

        // MARK: - Actions

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }

            // Studio short tap: selectedTab = composer only, no send.
            guard hasSendableContent else {
                if selectedTab.wrappedValue != .composer {
                    selectedTab.wrappedValue = .composer
                }
                return
            }

            // Send short tap:
            if selectedTab.wrappedValue == .composer {
                // Send short tap on composer: onSend exactly once.
                onSend()
            } else {
                // Send short tap from Setting: selectedTab = composer, then DispatchQueue.main.async onSend exactly once.
                selectedTab.wrappedValue = .composer
                DispatchQueue.main.async { [weak self] in
                    self?.onSend()
                }
            }
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }

            if hasSendableContent {
                // Send long press: open picker, never send.
                onLongPressFirstTab()
            } else {
                // Studio long press: do nothing.
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CreatorProfileStore())
        .environmentObject(AutomationCoordinator.shared)
        .environmentObject(AIProviderAvailabilityStore())
        .environmentObject(AIRunMetricsStore())
}
