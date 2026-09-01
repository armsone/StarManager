import Combine
import Foundation

/// 클라우드 AI 제공자(ChatGPT·Gemini·Claude)를 사용자가 독립적으로 켜고 끌 수 있게 하고,
/// 스튜디오·자동화가 마지막으로 사용한 AI를 안전하게 다시 고를 수 있도록 돕는 저장소.
/// 세 제공자를 모두 꺼도 아이폰 AI(기기 AI)는 항상 사용할 수 있다.
@MainActor
final class AIProviderAvailabilityStore: ObservableObject {
    @Published var isOpenAIEnabled: Bool { didSet { persist() } }
    @Published var isGeminiEnabled: Bool { didSet { persist() } }
    @Published var isClaudeEnabled: Bool { didSet { persist() } }
    @Published private(set) var lastUsedChoice: AIProviderIdentity { didSet { persist() } }

    private let defaults: UserDefaults
    private static let openAIKey = "aiProviderEnabled.openAI"
    private static let geminiKey = "aiProviderEnabled.gemini"
    private static let claudeKey = "aiProviderEnabled.claude"
    private static let lastUsedKey = "aiProviderLastUsedChoice"
    /// 마지막 사용 제공자가 꺼졌을 때 대신 고를 클라우드 제공자 순서.
    private static let cloudFallbackOrder: [AIProviderIdentity] = [.gemini, .openAI, .claude]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOpenAIEnabled = (defaults.object(forKey: Self.openAIKey) as? Bool) ?? true
        isGeminiEnabled = (defaults.object(forKey: Self.geminiKey) as? Bool) ?? true
        isClaudeEnabled = (defaults.object(forKey: Self.claudeKey) as? Bool) ?? true
        lastUsedChoice = AIProviderIdentity(rawValue: defaults.string(forKey: Self.lastUsedKey) ?? "") ?? .device
    }

    func isEnabled(_ identity: AIProviderIdentity) -> Bool {
        switch identity {
        case .device: true
        case .openAI: isOpenAIEnabled
        case .gemini: isGeminiEnabled
        case .claude: isClaudeEnabled
        }
    }

    func isEnabled(_ provider: ExternalAIProvider) -> Bool {
        switch provider {
        case .openAI: isOpenAIEnabled
        case .gemini: isGeminiEnabled
        case .claude: isClaudeEnabled
        case .grok: false
        }
    }

    func setEnabled(_ isEnabled: Bool, for identity: AIProviderIdentity) {
        switch identity {
        case .device: return
        case .openAI: isOpenAIEnabled = isEnabled
        case .gemini: isGeminiEnabled = isEnabled
        case .claude: isClaudeEnabled = isEnabled
        }
        guard !isEnabled, lastUsedChoice == identity else { return }
        // 방금 끈 제공자가 마지막 선택이었다면 다른 켜진 제공자로 조용히 넘긴다.
        // 꺼둔 클라우드 제공자를 사용자 모르게 다시 켜지는 않는다.
        lastUsedChoice = resolvedChoice(preferring: identity)
    }

    func recordUsed(_ identity: AIProviderIdentity) {
        guard isEnabled(identity) else { return }
        lastUsedChoice = identity
    }

    /// 선호 선택지가 꺼져 있으면 켜진 클라우드 제공자로, 그것도 없으면 기기 AI로 안전하게 대체한다.
    func resolvedChoice(preferring identity: AIProviderIdentity) -> AIProviderIdentity {
        if isEnabled(identity) { return identity }
        if let firstEnabledCloud = Self.cloudFallbackOrder.first(where: { isEnabled($0) }) {
            return firstEnabledCloud
        }
        return .device
    }

    var enabledExternalProviders: [ExternalAIProvider] {
        ExternalAIProvider.allCases.filter { isEnabled($0) }
    }

    private func persist() {
        defaults.set(isOpenAIEnabled, forKey: Self.openAIKey)
        defaults.set(isGeminiEnabled, forKey: Self.geminiKey)
        defaults.set(isClaudeEnabled, forKey: Self.claudeKey)
        defaults.set(lastUsedChoice.rawValue, forKey: Self.lastUsedKey)
    }
}
