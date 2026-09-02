import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private static let maxImageCount = 8

    private let accentColor = UIColor(
        red: 228 / 255,
        green: 30 / 255,
        blue: 37 / 255,
        alpha: 1
    )
    private let carbonColor = UIColor(
        red: 0.125,
        green: 0.125,
        blue: 0.14,
        alpha: 1
    )

    private let gradientLayer = CAGradientLayer()
    private let ringLayer = CAShapeLayer()
    private let ringContainer = UIView()
    private let statusLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let actionButtonsStack = UIStackView()
    private lazy var openAppButton = makeActionButton(title: "Stargram 열기", action: #selector(openApp))
    private lazy var retryButton = makeActionButton(title: "다시 시도", action: #selector(retryImport))
    private let cancelButton = UIButton(type: .system)
    private let stack = UIStackView()

    private var importTask: Task<Void, Never>?
    private var isImportComplete = false
    private var isOpeningHostApp = false
    private var didAttemptAutomaticOpen = false
    private var copiedFilenames: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        importSharedPhotos()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        layoutRing()
    }

    private func configureView() {
        view.backgroundColor = carbonColor

        gradientLayer.colors = [
            carbonColor.cgColor,
            UIColor(red: 0.06, green: 0.06, blue: 0.075, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)

        ringContainer.translatesAutoresizingMaskIntoConstraints = false
        ringLayer.strokeColor = accentColor.cgColor
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = 7
        ringLayer.lineCap = .round
        ringContainer.layer.addSublayer(ringLayer)
        startRingRotation()

        statusLabel.text = nil
        statusLabel.font = .systemFont(ofSize: 20, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.numberOfLines = 0

        descriptionLabel.text = nil
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        descriptionLabel.numberOfLines = 0

        configureActionButtons()
        configureCancelButton()

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        [ringContainer, statusLabel, descriptionLabel, actionButtonsStack]
            .forEach(stack.addArrangedSubview)
        view.addSubview(stack)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            ringContainer.widthAnchor.constraint(equalToConstant: 96),
            ringContainer.heightAnchor.constraint(equalToConstant: 96),

            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerYAnchor,
                constant: -24
            ),
            stack.widthAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
                constant: -48
            ),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            descriptionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionButtonsStack.widthAnchor.constraint(equalTo: stack.widthAnchor),

            cancelButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            cancelButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            cancelButton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            cancelButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
            cancelButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func layoutRing() {
        let bounds = ringContainer.bounds
        guard bounds.width > 0 else { return }
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: bounds.width / 2 - ringLayer.lineWidth / 2,
            startAngle: -.pi / 2 + 0.25,
            endAngle: -.pi / 2 + 0.25 + 2 * .pi * 0.74,
            clockwise: true
        )
        ringLayer.path = path.cgPath
        ringLayer.frame = bounds
    }

    private func startRingRotation() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = 2 * Double.pi
        animation.duration = 1.1
        animation.repeatCount = .infinity
        ringContainer.layer.add(animation, forKey: "rotation")
    }

    private func configureActionButtons() {
        actionButtonsStack.axis = .vertical
        actionButtonsStack.alignment = .fill
        actionButtonsStack.distribution = .fill
        actionButtonsStack.spacing = 10
        actionButtonsStack.isHidden = true

        actionButtonsStack.addArrangedSubview(openAppButton)
        actionButtonsStack.addArrangedSubview(retryButton)
    }

    private func makeActionButton(title: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = accentColor
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 20, bottom: 0, trailing: 20
        )

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func configureCancelButton() {
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .disabled)
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        cancelButton.layer.cornerRadius = 16
        cancelButton.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        cancelButton.layer.borderWidth = 1
        cancelButton.addTarget(self, action: #selector(cancelImport), for: .touchUpInside)
    }

    private func importSharedPhotos() {
        statusLabel.isHidden = true
        descriptionLabel.isHidden = true
        actionButtonsStack.isHidden = true
        cancelButton.setTitle("취소", for: .normal)
        retryButton.isHidden = true
        openAppButton.isHidden = true

        let providers = Array(
            (extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? [])
                .flatMap { $0.attachments ?? [] }
                .prefix(Self.maxImageCount)
        )

        guard !providers.isEmpty else {
            statusLabel.isHidden = false
            descriptionLabel.isHidden = false
            statusLabel.text = "가져올 수 있는 사진이 없어요"
            descriptionLabel.text = "이미지를 선택한 뒤 다시 시도해 주세요."
            cancelButton.setTitle("닫기", for: .normal)
            return
        }

        importTask = Task {
            var filenames: [String] = []
            var failureCount = 0
            for provider in providers {
                guard !Task.isCancelled else { return }
                do {
                    let filename = try await copyImage(from: provider)
                    guard !Task.isCancelled else {
                        SharedInbox.deleteUncommittedFiles(named: [filename])
                        return
                    }
                    filenames.append(filename)
                    copiedFilenames.append(filename)
                } catch {
                    failureCount += 1
                }
                guard !Task.isCancelled else { return }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.importTask = nil
                if filenames.isEmpty {
                    self.statusLabel.isHidden = false
                    self.descriptionLabel.isHidden = false
                    self.statusLabel.text = "사진을 저장하지 못했어요"
                    self.descriptionLabel.text = "다시 시도해 주세요."
                    self.actionButtonsStack.isHidden = false
                    self.retryButton.isHidden = false
                    self.openAppButton.isHidden = true
                    self.cancelButton.setTitle("닫기", for: .normal)
                    return
                }
                let batch = SharedInbox.Batch(
                    id: UUID(),
                    filenames: filenames,
                    createdAt: Date()
                )
                do {
                    try SharedInbox.commit(batch)
                    self.copiedFilenames = []
                    self.showResult(count: filenames.count, failedCount: failureCount, batchID: batch.id)
                } catch {
                    SharedInbox.deleteUncommittedFiles(named: filenames)
                    self.copiedFilenames = []
                    self.statusLabel.isHidden = false
                    self.descriptionLabel.isHidden = false
                    self.statusLabel.text = "사진을 보관하지 못했어요"
                    self.descriptionLabel.text = error.localizedDescription
                    self.actionButtonsStack.isHidden = false
                    self.retryButton.isHidden = false
                    self.openAppButton.isHidden = true
                    self.cancelButton.setTitle("닫기", for: .normal)
                }
            }
        }
    }

    private func copyImage(from provider: NSItemProvider) async throws -> String {
        let imageTypeIdentifier = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? UTType.image.identifier

        if let filename = try? await copyFileRepresentation(
            from: provider,
            typeIdentifier: imageTypeIdentifier
        ) {
            return filename
        }
        if let filename = try? await copyInPlaceRepresentation(
            from: provider,
            typeIdentifier: imageTypeIdentifier
        ) {
            return filename
        }
        if let filename = try? await copyDataRepresentation(
            from: provider,
            typeIdentifier: imageTypeIdentifier
        ) {
            return filename
        }
        return try await copyLoadedItem(
            from: provider,
            typeIdentifier: imageTypeIdentifier
        )
    }

    private func copyFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: ShareError.missingFile)
                    return
                }
                do {
                    continuation.resume(returning: try Self.writeFileToInbox(url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func copyInPlaceRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: ShareError.missingFile)
                    return
                }
                do {
                    continuation.resume(returning: try Self.writeFileToInbox(url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func copyDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: ShareError.missingFile)
                    return
                }
                do {
                    continuation.resume(returning: try Self.writeDataToInbox(data))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func copyLoadedItem(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                do {
                    switch item {
                    case let url as URL:
                        continuation.resume(returning: try Self.writeFileToInbox(url))
                    case let data as Data:
                        continuation.resume(returning: try Self.writeDataToInbox(data))
                    case let image as UIImage:
                        guard let data = image.jpegData(compressionQuality: 0.96) else {
                            throw ShareError.missingFile
                        }
                        continuation.resume(returning: try Self.writeDataToInbox(data))
                    default:
                        continuation.resume(throwing: ShareError.missingFile)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// `static`로 두어 NSItemProvider 완료 클로저(다른 스레드에서 실행될 수 있음)가
    /// MainActor로 격리된 `self`를 캡처하지 않고도 호출할 수 있게 한다.
    private static func writeFileToInbox(_ source: URL) throws -> String {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess { source.stopAccessingSecurityScopedResource() }
        }
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = try SharedInbox.fileURL(named: filename)
        try FileManager.default.copyItem(at: source, to: destination)
        return filename
    }

    private static func writeDataToInbox(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let destination = try SharedInbox.fileURL(named: filename)
        try data.write(to: destination, options: .atomic)
        return filename
    }

    private func showResult(count: Int, failedCount: Int, batchID: UUID) {
        isImportComplete = true
        statusLabel.isHidden = failedCount == 0
        descriptionLabel.isHidden = failedCount == 0
        statusLabel.text = failedCount == 0 ? nil : "사진 \(count)장을 준비했어요"
        descriptionLabel.text = failedCount == 0 ? nil : "\(failedCount)장은 읽지 못했지만 준비된 사진으로 계속할게요."
        cancelButton.setTitle("닫기", for: .normal)
        actionButtonsStack.isHidden = true
        openHostAppAutomaticallyIfNeeded(batchID: batchID)
    }

    @objc private func cancelImport() {
        if let importTask {
            importTask.cancel()
            self.importTask = nil
            SharedInbox.deleteUncommittedFiles(named: copiedFilenames)
            copiedFilenames = []
            extensionContext?.cancelRequest(withError: ShareError.cancelled)
        } else {
            completeExtension()
        }
    }

    @objc private func openApp() {
        guard let batchID = pendingBatchID else {
            completeExtension()
            return
        }
        openHostApp(batchID: batchID, isAutomatic: false)
    }

    @objc private func retryImport() {
        guard importTask == nil, !isImportComplete else { return }
        copiedFilenames = []
        importSharedPhotos()
    }

    private var pendingBatchID: UUID?

    private func openHostAppAutomaticallyIfNeeded(batchID: UUID) {
        pendingBatchID = batchID
        guard !didAttemptAutomaticOpen else { return }
        didAttemptAutomaticOpen = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isImportComplete, !self.isOpeningHostApp else { return }
            self.openHostApp(batchID: batchID, isAutomatic: true)
        }
    }

    private func openHostApp(batchID: UUID, isAutomatic: Bool) {
        guard !isOpeningHostApp else { return }
        guard let url = URL(string: "imanagerai://automation?batch=\(batchID.uuidString)") else {
            completeExtension()
            return
        }

        isOpeningHostApp = true
        actionButtonsStack.isHidden = true
        cancelButton.isEnabled = true

        extensionContext?.open(url) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.finishOpeningHostApp(success: true)
                    return
                }
                self.openHostAppFromResponderChain(url) { [weak self] success in
                    self?.finishOpeningHostApp(success: success, wasAutomatic: isAutomatic)
                }
            }
        }
    }

    private func finishOpeningHostApp(success: Bool, wasAutomatic: Bool = false) {
        isOpeningHostApp = false
        cancelButton.isEnabled = true

        if success {
            completeExtension()
        } else {
            actionButtonsStack.isHidden = false
            retryButton.isHidden = true
            openAppButton.isHidden = false
            statusLabel.isHidden = false
            descriptionLabel.isHidden = false
            statusLabel.text = wasAutomatic ? "자동으로 열리지 않았어요" : "Stargram을 열지 못했어요"
            descriptionLabel.text = "사진은 안전하게 저장돼 있어요. 아래 버튼으로 Stargram을 열면 이어서 진행돼요."
        }
    }

    private func openHostAppFromResponderChain(
        _ url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self

        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication,
               currentResponder.responds(to: selector) {
                application.open(url, options: [:]) { success in
                    DispatchQueue.main.async { completion(success) }
                }
                return
            }
            if let scene = currentResponder as? UIScene,
               currentResponder.responds(to: selector) {
                scene.open(url, options: nil) { success in
                    DispatchQueue.main.async { completion(success) }
                }
                return
            }
            responder = currentResponder.next
        }

        completion(false)
    }

    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

private enum ShareError: LocalizedError {
    case missingFile
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingFile: "공유한 사진을 읽을 수 없습니다."
        case .cancelled: "가져오기를 취소했습니다."
        }
    }
}
