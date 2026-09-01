import SwiftUI
import UIKit

/// 기기 AI와 클라우드 제공자(브라우저 자동화 대상)를 하나의 목록으로 다루기 위한 통합 식별자.
/// Grok은 결과 문구 품질 문제로 사용자 노출 목록에서 제외돼 있어 이 열거형에도 포함하지 않는다.
enum AIProviderIdentity: String, CaseIterable, Identifiable, Codable, Equatable, Hashable, Sendable {
    case device
    case gemini
    case openAI
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device: "아이폰 AI"
        case .openAI: "ChatGPT"
        case .gemini: "Gemini"
        case .claude: "Claude"
        }
    }

    var assetName: String? {
        switch self {
        case .device: nil
        case .openAI: "ChatGPTBrand"
        case .gemini: "GeminiBrand"
        case .claude: "ClaudeBrand"
        }
    }

    var externalProvider: ExternalAIProvider? {
        switch self {
        case .device: nil
        case .openAI: .openAI
        case .gemini: .gemini
        case .claude: .claude
        }
    }

    init?(externalProvider: ExternalAIProvider) {
        switch externalProvider {
        case .openAI: self = .openAI
        case .gemini: self = .gemini
        case .claude: self = .claude
        case .grok: return nil
        }
    }

    /// 탭 아이콘·자동화 원형 진행 표시 등 고정 크기 배지에 쓰는 아이콘.
    @ViewBuilder
    var tabIcon: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
        }
    }

    /// 네이티브 `TabView.tabItem`에서만 쓰는 안전한 아이콘.
    /// `tabIcon`은 불투명 `some View` 계층(clipShape 포함)이라 시스템 탭 바 스냅샷에
    /// 넣으면 원본 사진 콘텐츠가 그대로 번져 나오는 결함이 있었다. 여기서는 미리
    /// 고정 크기로 래스터화한 `UIImage`를 `Image`로만 감싸 그 결함을 피한다.
    var tabBarImage: Image {
        guard let assetName else {
            return Image(systemName: "apple.logo")
        }
        if let cached = Self.tabBarImageCache.object(forKey: assetName as NSString) {
            return Image(uiImage: cached)
        }
        guard let source = UIImage(named: assetName) else {
            return Image(systemName: "apple.logo")
        }
        let targetSize = CGSize(width: 26, height: 26)
        let scaled = UIGraphicsImageRenderer(size: targetSize).image { _ in
            let aspect = source.size.width / max(source.size.height, 1)
            var drawSize = targetSize
            if aspect > 1 {
                drawSize.height = targetSize.width / aspect
            } else {
                drawSize.width = targetSize.height * aspect
            }
            let origin = CGPoint(x: (targetSize.width - drawSize.width) / 2, y: (targetSize.height - drawSize.height) / 2)
            UIBezierPath(roundedRect: CGRect(origin: origin, size: drawSize), cornerRadius: 6).addClip()
            source.draw(in: CGRect(origin: origin, size: drawSize))
        }.withRenderingMode(.alwaysOriginal)
        Self.tabBarImageCache.setObject(scaled, forKey: assetName as NSString)
        return Image(uiImage: scaled)
    }

    nonisolated(unsafe) private static let tabBarImageCache = NSCache<NSString, UIImage>()
}
