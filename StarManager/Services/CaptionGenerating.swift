import Combine
import Foundation
import Security
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol CaptionGenerating: Sendable {
    func generate(
        from idea: String,
        mood: PostMood,
        length: PostLength,
        profile: CreatorProfile
    ) async throws -> GeneratedPost
}

enum DeviceIntelligenceAvailability: Equatable, Sendable {
    case available
    case unsupportedDevice
    case needsAppleIntelligence
    case modelDownloading

    var title: String {
        switch self {
        case .available: "아이폰 AI"
        case .unsupportedDevice: "기본 생성"
        case .needsAppleIntelligence: "기본 생성"
        case .modelDownloading: "기본 생성"
        }
    }

    var detail: String {
        switch self {
        case .available: "로그인 없이 기기에서 작성"
        case .unsupportedDevice: "이 기기에서도 바로 작성"
        case .needsAppleIntelligence: "Apple Intelligence를 켜면 기기 AI 사용"
        case .modelDownloading: "기기 AI 준비가 끝날 때까지 기본 생성"
        }
    }
}

enum DeviceIntelligenceError: LocalizedError {
    case unavailable
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unavailable: "아이폰 AI를 지금 사용할 수 없습니다."
        case .invalidFormat: "아이폰 AI 결과의 작성 기준을 맞추지 못했습니다."
        }
    }
}

struct DeviceIntelligenceCaptionGenerator: CaptionGenerating {
    static var availability: DeviceIntelligenceAvailability {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return SystemLanguageModel.default.supportsLocale(Locale(identifier: "ko_KR"))
                    ? .available
                    : .unsupportedDevice
            case .unavailable(.deviceNotEligible): return .unsupportedDevice
            case .unavailable(.appleIntelligenceNotEnabled): return .needsAppleIntelligence
            case .unavailable(.modelNotReady): return .modelDownloading
            case .unavailable: return .unsupportedDevice
            }
        }
#endif
        return .unsupportedDevice
    }

    func generate(
        from idea: String,
        mood: PostMood,
        length: PostLength,
        profile: CreatorProfile
    ) async throws -> GeneratedPost {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard Self.availability == .available else { throw DeviceIntelligenceError.unavailable }
            let instructions = """
            당신은 한국어 인스타그램 산문 전문 작가입니다.
            결과에는 완성된 게시 문구만 출력합니다.
            사용자의 모든 형식 조건과 금지 표현을 반드시 지킵니다.
            """
            let session = LanguageModelSession(instructions: instructions)
            let basePrompt = """
            \(profile.prompt(for: idea))
            - 선택한 분위기: \(mood.rawValue)
            - 이야기 비중: \(length.storyWeightTitle) — \(length.promptInstruction)
            - 공백과 줄바꿈을 포함해 정확히 \(profile.controls.characterCount)자로 작성
            """

            var response = try await session.respond(to: basePrompt).content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var report = CaptionFormatReport.evaluate(
                response,
                requiredCharacterCount: profile.controls.characterCount
            )

            if !report.passesAllRules {
                let repairPrompt = """
                방금 결과를 아래 실패 항목만 고쳐서 완성 문구만 다시 출력하세요.
                실패 항목: \(report.failedRuleDescriptions.joined(separator: ", "))
                반드시 공백과 줄바꿈 포함 정확히 \(profile.controls.characterCount)자여야 합니다.
                """
                response = try await session.respond(to: repairPrompt).content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                report = CaptionFormatReport.evaluate(
                    response,
                    requiredCharacterCount: profile.controls.characterCount
                )
            }

            guard report.passesAllRules else { throw DeviceIntelligenceError.invalidFormat }
            let lines = response.components(separatedBy: "\n")
            let hashtags = (lines.first ?? "").split(separator: " ").map { String($0.dropFirst()) }
            return GeneratedPost(
                sourceIdea: idea,
                hook: lines.dropFirst().first ?? "",
                caption: lines.dropFirst().dropLast().joined(separator: "\n"),
                callToAction: lines.last ?? "",
                hashtags: hashtags,
                composedText: response,
                targetCharacterCount: profile.controls.characterCount
            )
        }
#endif
        throw DeviceIntelligenceError.unavailable
    }
}

enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case openAI
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: "ChatGPT"
        case .gemini: "Gemini"
        }
    }
}

enum AIBackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(status: Int, message: String)
    case invalidFormat([String])
    case missingImage

    var errorDescription: String? {
        switch self {
        case .invalidURL: "AI 서버 주소가 올바르지 않습니다."
        case .invalidResponse: "AI 서버의 응답을 읽지 못했습니다."
        case let .server(status, message): "AI 서버 오류 \(status): \(message)"
        case let .invalidFormat(rules): "AI 문구가 작성 기준을 지키지 못했습니다: \(rules.joined(separator: ", "))"
        case .missingImage: "AI 서버에서 이미지를 받지 못했습니다."
        }
    }
}

enum AIConnectionStatus: Equatable {
    case notChecked
    case checking
    case connected(openAI: Bool, gemini: Bool)
    case failed(String)
}

@MainActor
final class AIConfigurationStore: ObservableObject {
    @Published var isEnabled: Bool { didSet { persist() } }
    @Published var backendURLString: String { didSet { persist() } }
    @Published var accessToken: String { didSet { saveAccessToken() } }
    @Published var selectedProvider: AIProvider { didSet { persist() } }
    @Published private(set) var connectionStatus: AIConnectionStatus = .notChecked

    private let defaults: UserDefaults
    private static let enabledKey = "aiBackendEnabled"
    private static let urlKey = "aiBackendURL"
    private static let providerKey = "aiProvider"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        backendURLString = defaults.string(forKey: Self.urlKey) ?? ""
        accessToken = Self.loadAccessToken()
        selectedProvider = AIProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "") ?? .openAI
    }

    var backendURL: URL? {
        let raw = backendURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host)) else {
            return nil
        }
        return url
    }

    var isReady: Bool { isEnabled && backendURL != nil }

    func providerAvailability(_ provider: AIProvider) -> Bool? {
        guard case let .connected(openAI, gemini) = connectionStatus else { return nil }
        return provider == .openAI ? openAI : gemini
    }

    var selectedProviderStatusText: String {
        guard isReady else { return "서버 연결 후 사용" }
        return switch connectionStatus {
        case .notChecked: "서버 주소 설정됨 · 연결 확인 권장"
        case .checking: "서버 연결 확인 중"
        case let .connected(openAI, gemini):
            (selectedProvider == .openAI ? openAI : gemini) ? "\(selectedProvider.title) 사용 가능" : "\(selectedProvider.title) 서버 키 필요"
        case .failed: "서버 연결을 다시 확인해 주세요"
        }
    }

    var canCompareProviders: Bool {
        guard case let .connected(openAI, gemini) = connectionStatus else { return isReady }
        return isReady && openAI && gemini
    }

    func checkConnection(session: URLSession = .shared) async {
        guard let backendURL else {
            connectionStatus = .failed("올바른 AI 서버 주소를 먼저 입력해 주세요.")
            return
        }

        connectionStatus = .checking
        do {
            var request = URLRequest(url: backendURL.appending(path: "health"))
            request.timeoutInterval = 15
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw AIBackendError.invalidResponse
            }
            let health = try JSONDecoder().decode(AIBackendHealthResponse.self, from: data)
            guard health.ok else { throw AIBackendError.invalidResponse }
            connectionStatus = .connected(
                openAI: health.providers.openAI,
                gemini: health.providers.gemini
            )
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    func resetConnectionStatus() {
        connectionStatus = .notChecked
    }

    private func persist() {
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(backendURLString, forKey: Self.urlKey)
        defaults.set(selectedProvider.rawValue, forKey: Self.providerKey)
    }

    private func saveAccessToken() {
        let account = "ai-backend-access-token"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.armsone.StarManager",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !accessToken.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = Data(accessToken.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadAccessToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.armsone.StarManager",
            kSecAttrAccount as String: "ai-backend-access-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

private struct AIBackendHealthResponse: Decodable {
    let ok: Bool
    let providers: Providers

    struct Providers: Decodable {
        let openAI: Bool
        let gemini: Bool
    }
}

struct BackendCaptionGenerator: CaptionGenerating {
    let baseURL: URL
    let provider: AIProvider
    var accessToken = ""
    var session: URLSession = .shared

    func generate(
        from idea: String,
        mood: PostMood,
        length: PostLength,
        profile: CreatorProfile
    ) async throws -> GeneratedPost {
        let endpoint = baseURL.appending(path: "v1/captions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty { request.setValue(accessToken, forHTTPHeaderField: "X-StarManager-Token") }
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(BackendCaptionRequest(
            provider: provider.rawValue,
            idea: idea,
            prompt: """
            \(profile.prompt(for: idea))
            - 선택한 분위기: \(mood.rawValue)
            - 이야기 비중: \(length.storyWeightTitle) — \(length.promptInstruction)
            """,
            mood: mood.rawValue,
            length: length.rawValue,
            targetCharacterCount: profile.controls.characterCount
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIBackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(BackendErrorResponse.self, from: data).error) ?? "요청 실패"
            throw AIBackendError.server(status: http.statusCode, message: message)
        }
        let payload = try JSONDecoder().decode(BackendCaptionResponse.self, from: data)
        let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = CaptionFormatReport.evaluate(text, requiredCharacterCount: profile.controls.characterCount)
        guard report.passesAllRules else { throw AIBackendError.invalidFormat(report.failedRuleDescriptions) }

        let lines = text.components(separatedBy: "\n")
        let hashtags = (lines.first ?? "").split(separator: " ").map { String($0.dropFirst()) }
        return GeneratedPost(
            sourceIdea: idea,
            hook: lines.dropFirst().first ?? "",
            caption: lines.dropFirst().dropLast().joined(separator: "\n"),
            callToAction: lines.last ?? "",
            hashtags: hashtags,
            composedText: text,
            targetCharacterCount: profile.controls.characterCount
        )
    }
}

struct BackendImageGenerator: Sendable {
    let baseURL: URL
    let provider: AIProvider
    var accessToken = ""
    var session: URLSession = .shared

    func generate(from post: GeneratedPost, profile: CreatorProfile, aspectRatio: String) async throws -> GeneratedImagePayload {
        let endpoint = baseURL.appending(path: "v1/images")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty { request.setValue(accessToken, forHTTPHeaderField: "X-StarManager-Token") }
        request.timeoutInterval = 180
        request.httpBody = try JSONEncoder().encode(BackendImageRequest(
            provider: provider.rawValue,
            sourceIdea: post.sourceIdea,
            postText: post.composedText,
            accountTopic: profile.accountTopic,
            voice: profile.voice,
            aspectRatio: aspectRatio
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIBackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(BackendErrorResponse.self, from: data).error) ?? "요청 실패"
            throw AIBackendError.server(status: http.statusCode, message: message)
        }
        let payload = try JSONDecoder().decode(BackendImageResponse.self, from: data)
        guard let image = Data(base64Encoded: payload.base64) else { throw AIBackendError.missingImage }
        return GeneratedImagePayload(data: image, fileExtension: payload.fileExtension)
    }
}

struct GeneratedImagePayload: Sendable {
    let data: Data
    let fileExtension: String
}

private struct BackendCaptionRequest: Encodable {
    let provider: String
    let idea: String
    let prompt: String
    let mood: String
    let length: String
    let targetCharacterCount: Int
}

private struct BackendCaptionResponse: Decodable { let text: String }
private struct BackendErrorResponse: Decodable { let error: String }

private struct BackendImageRequest: Encodable {
    let provider: String
    let sourceIdea: String
    let postText: String
    let accountTopic: String
    let voice: String
    let aspectRatio: String
}

private struct BackendImageResponse: Decodable {
    let base64: String
    let mimeType: String?

    var fileExtension: String {
        switch mimeType?.lowercased() {
        case "image/jpeg", "image/jpg": "jpg"
        case "image/webp": "webp"
        case "image/heic", "image/heif": "heic"
        default: "png"
        }
    }
}

enum DirectAIProvider: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case openAI
    case gemini
    case grok

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: "ChatGPT"
        case .gemini: "Gemini"
        case .grok: "Grok"
        }
    }
}

/// 각 제공사 API 키를 키체인에만 저장하는 개인용 설정 저장소.
/// UserDefaults나 로그에는 절대 기록하지 않는다.
@MainActor
final class DirectAIConfigurationStore: ObservableObject {
    @Published var openAIKey: String { didSet { saveKey(openAIKey, provider: .openAI) } }
    @Published var geminiKey: String { didSet { saveKey(geminiKey, provider: .gemini) } }
    @Published var grokKey: String { didSet { saveKey(grokKey, provider: .grok) } }

    init() {
        openAIKey = Self.loadKey(provider: .openAI)
        geminiKey = Self.loadKey(provider: .gemini)
        grokKey = Self.loadKey(provider: .grok)
    }

    func key(for provider: DirectAIProvider) -> String {
        switch provider {
        case .openAI: openAIKey
        case .gemini: geminiKey
        case .grok: grokKey
        }
    }

    func clear(_ provider: DirectAIProvider) {
        switch provider {
        case .openAI: openAIKey = ""
        case .gemini: geminiKey = ""
        case .grok: grokKey = ""
        }
    }

    private static let service = "com.armsone.StarManager"

    private static func account(for provider: DirectAIProvider) -> String {
        "direct-ai-key-\(provider.rawValue)"
    }

    private func saveKey(_ key: String, provider: DirectAIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account(for: provider)
        ]
        guard !key.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var add = query
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadKey(provider: DirectAIProvider) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

enum DirectAIError: LocalizedError {
    case missingKey(DirectAIProvider)
    case invalidResponse
    case server(status: Int, message: String)
    case emptyText
    case invalidFormat([String])

    var errorDescription: String? {
        switch self {
        case let .missingKey(provider): "\(provider.title) API 키를 먼저 입력해 주세요."
        case .invalidResponse: "AI 응답을 읽지 못했습니다."
        case let .server(status, message): "\(message) (\(status))"
        case .emptyText: "AI가 문구를 만들지 못했습니다."
        case let .invalidFormat(rules): "AI 문구가 작성 기준을 지키지 못했습니다: \(rules.joined(separator: ", "))"
        }
    }
}

/// ChatGPT·Gemini·Grok 공식 HTTPS API를 직접 호출하는 개인용 생성기.
struct DirectAICaptionGenerator: CaptionGenerating {
    let provider: DirectAIProvider
    let apiKey: String
    var session: URLSession = .shared

    private static let instructions = """
    당신은 한국어 인스타그램 산문 전문 작가입니다.
    결과에는 완성된 게시 문구만 출력합니다.
    사용자의 모든 형식 조건과 금지 표현을 반드시 지킵니다.
    """

    func generate(
        from idea: String,
        mood: PostMood,
        length: PostLength,
        profile: CreatorProfile
    ) async throws -> GeneratedPost {
        guard !normalizedAPIKey.isEmpty else { throw DirectAIError.missingKey(provider) }

        let basePrompt = """
        \(profile.prompt(for: idea))
        - 선택한 분위기: \(mood.rawValue)
        - 이야기 비중: \(length.storyWeightTitle) — \(length.promptInstruction)
        - 공백과 줄바꿈을 포함해 정확히 \(profile.controls.characterCount)자로 작성
        """

        var text = try await requestText(prompt: basePrompt)
        let validationContext = CaptionValidationContext(
            requiredCharacterCount: profile.controls.characterCount,
            prohibitedPhrases: profile.prohibitedPhrases,
            allowsBodyEmoji: profile.usesEmoji
        )
        var report = CaptionValidationReport.evaluate(text, context: validationContext)

        if !report.passesAllRules {
            let repairPrompt = """
            아래 이전 결과를 실패 항목에 맞춰 고친 뒤 완성 문구만 다시 출력하세요.
            실패 항목: \(report.failedRuleDescriptions.joined(separator: ", "))
            반드시 공백과 줄바꿈 포함 정확히 \(profile.controls.characterCount)자여야 합니다.

            이전 결과:
            \(text)
            """
            text = try await requestText(prompt: repairPrompt)
            report = CaptionValidationReport.evaluate(text, context: validationContext)
        }

        guard report.passesAllRules else { throw DirectAIError.invalidFormat(report.failedRuleDescriptions) }

        let lines = text.components(separatedBy: "\n")
        let hashtags = (lines.first ?? "").split(separator: " ").map { String($0.dropFirst()) }
        return GeneratedPost(
            sourceIdea: idea,
            hook: lines.dropFirst().first ?? "",
            caption: lines.dropFirst().dropLast().joined(separator: "\n"),
            callToAction: lines.last ?? "",
            hashtags: hashtags,
            composedText: text,
            targetCharacterCount: profile.controls.characterCount
        )
    }

    private func requestText(prompt: String) async throws -> String {
        let raw: String
        switch provider {
        case .openAI: raw = try await requestOpenAI(prompt: prompt)
        case .gemini: raw = try await requestGemini(prompt: prompt)
        case .grok: raw = try await requestGrok(prompt: prompt)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DirectAIError.emptyText }
        return trimmed
    }

    private var normalizedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenAI Responses API

    private func requestOpenAI(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(normalizedAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5-mini",
            "input": [
                ["role": "system", "content": Self.instructions],
                ["role": "user", "content": prompt]
            ]
        ])

        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DirectAIError.invalidResponse
        }

        if let outputText = json["output_text"] as? String { return outputText }

        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                guard let content = item["content"] as? [[String: Any]] else { continue }
                for piece in content {
                    if let text = piece["text"] as? String { return text }
                }
            }
        }
        throw DirectAIError.invalidResponse
    }

    // MARK: - Gemini generateContent

    private func requestGemini(prompt: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(normalizedAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "systemInstruction": ["parts": [["text": Self.instructions]]],
            "contents": [
                ["role": "user", "parts": [["text": prompt]]]
            ]
        ])

        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw DirectAIError.invalidResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw DirectAIError.invalidResponse }
        return text
    }

    // MARK: - xAI chat completions

    private func requestGrok(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(normalizedAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "grok-4.5",
            "messages": [
                ["role": "system", "content": Self.instructions],
                ["role": "user", "content": prompt]
            ]
        ])

        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw DirectAIError.invalidResponse
        }
        return text
    }

    // MARK: - Transport

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DirectAIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message: String
            switch http.statusCode {
            case 401:
                message = "API 키가 올바르지 않거나 만료됐습니다."
            case 403:
                message = "이 API 키에 요청 권한이 없습니다."
            case 404:
                message = "현재 선택한 AI 모델을 사용할 수 없습니다."
            case 429:
                message = "API 사용 잔액이 없거나 사용 한도를 넘었습니다."
            default:
                message = "AI 요청을 처리하지 못했습니다."
            }
            throw DirectAIError.server(status: http.statusCode, message: message)
        }
        return data
    }
}

/// 오프라인 데모용 로컬 생성기.
/// 저장된 작성 지침의 필수 형식(공백 포함 정확히 200자, 첫 줄 한글 태그 2개 연속,
/// 마침표 뒤 줄바꿈, 전체 따옴표 금지, 절제된 문단 앞 이모지,
/// 이모지로 감싼 요약 마지막 줄)을 결정적으로 재현한다.
struct PreviewCaptionGenerator: CaptionGenerating {
    var simulatedDelay: Duration = .milliseconds(550)

    func generate(
        from idea: String,
        mood: PostMood,
        length: PostLength,
        profile: CreatorProfile
    ) async throws -> GeneratedPost {
        if simulatedDelay > .zero { try await Task.sleep(for: simulatedDelay) }

        let cleanIdea = Self.sanitize(idea)
        let controls = profile.controls
        var seed = Self.seed(from: cleanIdea + mood.rawValue + length.rawValue + String(describing: controls))

        let tags = Self.hashtagPair(from: cleanIdea, mood: mood, seed: &seed)
        let firstLine = "#\(tags.0) #\(tags.1)"
        let lastLine = Self.summaryLine(for: mood, targetCount: controls.characterCount)

        if controls.characterCount < 100 {
            let bodyLength = max(1, controls.characterCount - firstLine.count - lastLine.count - 2)
            let body = Self.compactBody(
                exactLength: bodyLength,
                idea: cleanIdea,
                mood: mood,
                length: length,
                emoji: profile.usesEmoji
            )
            let composedText = [firstLine, body, lastLine].joined(separator: "\n")
            return GeneratedPost(
                sourceIdea: cleanIdea,
                hook: body,
                caption: "",
                callToAction: lastLine,
                hashtags: [tags.0, tags.1],
                composedText: composedText,
                targetCharacterCount: controls.characterCount
            )
        }

        let maximumLeadLength = max(
            4,
            controls.characterCount - firstLine.count - lastLine.count - 4
        )
        let leadLine = Self.leadLine(
            idea: cleanIdea,
            mood: mood,
            cap: min(Self.leadCap(for: length), maximumLeadLength),
            emoji: profile.usesEmoji ? Self.paragraphEmoji(for: mood) : nil
        )

        // 전체 200자 = 각 줄 글자 수 합 + 줄바꿈 수(줄 수 - 1).
        // 고정 줄을 뺀 나머지 예산을 본문 문장으로 채우고,
        // 마지막 남은 글자 수는 가변 길이 문장으로 정확히 메운다.
        var remaining = controls.characterCount
            - firstLine.count
            - (1 + leadLine.count)
            - (1 + lastLine.count)

        var bodyLines = [leadLine]
        let banned = Self.bannedPhrases(in: profile.prohibitedPhrases)
        let bank = Self.toneSentenceBank(for: controls) + Self.rotated(Self.sentenceBank(for: mood), seed: &seed)
            .filter { sentence in !banned.contains { sentence.contains($0) } }

        for sentence in bank {
            let cost = 1 + sentence.count
            // 가변 문장 최소 비용(줄바꿈 1 + 글자 3)을 항상 남겨 둔다.
            if remaining - cost >= 4 {
                bodyLines.append(sentence)
                remaining -= cost
            }
        }
        bodyLines.append(Self.flexSentence(exactLength: remaining - 1, seed: &seed))

        let composedText = ([firstLine] + bodyLines + [lastLine]).joined(separator: "\n")

        return GeneratedPost(
            sourceIdea: cleanIdea,
            hook: leadLine,
            caption: bodyLines.dropFirst().joined(separator: "\n"),
            callToAction: lastLine,
            hashtags: [tags.0, tags.1],
            composedText: composedText,
            targetCharacterCount: controls.characterCount
        )
    }

    // MARK: - 입력 정리

    /// 형식 규칙과 충돌하는 문자(따옴표, 해시, 이모지, 문장 중간 마침표)를 제거한다.
    private static func sanitize(_ raw: String) -> String {
        let mapped = raw.map { character -> String in
            if isEmoji(character) || "\"“”#".contains(character) { return "" }
            if ".!?…".contains(character) { return " " }
            return String(character)
        }
        return mapped.joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    private static func bannedPhrases(in raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - 줄 구성

    private static func leadCap(for length: PostLength) -> Int {
        switch length {
        case .short: 45
        case .medium: 65
        case .long: 90
        }
    }

    private static func leadLine(idea: String, mood: PostMood, cap: Int, emoji: String?) -> String {
        let prefix = emoji ?? ""
        let clause = idea.isEmpty ? defaultLead(for: mood) : idea
        let bodyCap = cap - prefix.count - 1

        if clause.count <= bodyCap {
            return prefix + clause + "."
        }
        // 해시태그·이모지·요약을 건드리지 않도록 아이디어 문장만 단어 경계에서 줄인다.
        var cut = String(clause.prefix(bodyCap))
        if let lastSpace = cut.lastIndex(of: " "),
           cut.distance(from: cut.startIndex, to: lastSpace) > bodyCap / 2 {
            cut = String(cut[..<lastSpace])
        }
        return prefix + cut.trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func summaryLine(for mood: PostMood, targetCount: Int) -> String {
        if targetCount < 100 {
            return switch mood {
            case .warm: "🧡 오늘을 남긴다 🧡"
            case .witty: "😎 오늘도 해냈다 😎"
            case .calm: "🌙 오늘을 담는다 🌙"
            }
        }
        let (emoji, clause) = switch mood {
        case .warm: ("🧡", "온기를 담아 오늘을 남긴다")
        case .witty: ("😎", "얼렁뚱땅 그래도 완벽한 하루")
        case .calm: ("🌙", "고요하게 채운 하루의 기록")
        }
        return "\(emoji) \(clause) \(emoji)"
    }

    private static func compactBody(
        exactLength target: Int,
        idea: String,
        mood: PostMood,
        length: PostLength,
        emoji: Bool
    ) -> String {
        guard target > 0 else { return "" }
        let prefix = emoji ? paragraphEmoji(for: mood) : ""
        let ratio: Double = switch length {
        case .short: 0.35
        case .medium: 0.6
        case .long: 0.85
        }
        let available = max(0, target - prefix.count - 1)
        let sourceCount = min(idea.count, max(1, Int(Double(available) * ratio)))
        var body = prefix + String(idea.prefix(sourceCount)).trimmingCharacters(in: .whitespaces)

        if body.count >= target {
            return String(body.prefix(max(0, target - 1))) + "."
        }

        var seed = seed(from: idea + mood.rawValue + length.rawValue)
        let remaining = target - body.count
        if remaining == 1 { return body + "…" }
        body += " " + flexSentence(exactLength: remaining - 1, seed: &seed)
        if body.count < target { body += String(repeating: "음", count: target - body.count) }
        return String(body.prefix(target))
    }

    private static func paragraphEmoji(for mood: PostMood) -> String {
        switch mood {
        case .warm: "✨"
        case .witty: "🙃"
        case .calm: "🌿"
        }
    }

    private static func defaultLead(for mood: PostMood) -> String {
        switch mood {
        case .warm: "별일 없던 하루에도 남기고 싶은 온기가 있다"
        case .witty: "오늘도 계획에 없던 장면 하나를 주웠다"
        case .calm: "지나가는 하루를 조용히 붙잡아 둔다"
        }
    }

    private static func sentenceBank(for mood: PostMood) -> [String] {
        switch mood {
        case .warm:
            [
                "별것 아닌 장면이 자꾸 마음에 남는다.",
                "따뜻한 기운이 하루 끝까지 따라왔다.",
                "이런 날은 오래 쥐고 싶어진다.",
                "누군가에게도 이 온기가 닿았으면 한다.",
                "작은 순간이 나를 다독인다.",
                "고맙다는 말이 입안에 맴돈다.",
                "내일의 나에게 건네는 응원 같았다.",
                "마음 한 켠이 노곤하게 풀린다."
            ]
        case .witty:
            [
                "계획은 없었는데 결과는 만족이다.",
                "이 정도면 오늘의 승자는 나다.",
                "우연이 실력처럼 보이는 날이 있다.",
                "웃음이 새어 나와서 참지 않았다.",
                "평범한 하루에 반전 하나 끼워 넣었다.",
                "다음에도 이런 우연은 환영이다.",
                "괜히 어깨가 으쓱해진다.",
                "누가 보면 준비한 줄 알겠다."
            ]
        case .calm:
            [
                "소란하지 않아서 좋은 하루였다.",
                "천천히 걷다 보니 마음도 느려졌다.",
                "말없이 지나가는 시간을 지켜봤다.",
                "덜어낸 자리에 여백이 남는다.",
                "오늘은 이 정도면 충분하다.",
                "생각을 정리하기 좋은 온도였다.",
                "가라앉은 마음이 나쁘지 않다.",
                "하루의 결이 고르게 느껴진다."
            ]
        }
    }

    private static func toneSentenceBank(for controls: GenerationControls) -> [String] {
        let groups: [(Int, [String])] = [
            (controls.emotion, ["마음의 잔향이 오래 머문다.", "무심한 장면이 가슴을 건드린다."]),
            (controls.kindness, ["다정한 시선 하나를 조용히 건넨다.", "서두르지 않아도 괜찮다고 말해 본다."]),
            (controls.originality, ["익숙한 풍경의 이면이 낯설게 반짝인다.", "평범함의 모서리에서 새 장면을 줍는다."]),
            (controls.masculinity, ["결심한 방향으로 묵묵히 걸어간다.", "말보다 단단한 걸음으로 답한다."]),
            (controls.chic, ["설명은 줄이고 여운만 남긴다.", "담백하게 선을 긋고 다음으로 간다."])
        ]
        return groups.sorted { $0.0 > $1.0 }.flatMap(\.1)
    }

    // MARK: - 해시태그

    private static func hashtagPair(
        from idea: String,
        mood: PostMood,
        seed: inout UInt64
    ) -> (String, String) {
        var candidates: [String] = []
        for word in idea.split(separator: " ") {
            let hangul = String(word.filter(isHangulSyllable).prefix(6))
            if hangul.count >= 2, !candidates.contains(hangul) {
                candidates.append(hangul)
            }
        }

        let fallback: [String] = switch mood {
        case .warm: ["온기기록", "마음한켠", "따뜻한하루"]
        case .witty: ["일상반전", "오늘의수확", "얼렁뚱땅"]
        case .calm: ["담백일기", "고요한하루", "느린기록"]
        }
        var pool = rotated(fallback, seed: &seed)
        while candidates.count < 2 {
            let next = pool.removeFirst()
            if !candidates.contains(next) { candidates.append(next) }
        }
        return (candidates[0], candidates[1])
    }

    // MARK: - 200자 맞춤 채움

    /// 마침표를 포함해 정확히 target 글자인 혼잣말 문장을 합성한다.
    /// 부사(길이 2~4, 공백 포함 비용 3~5)를 쌓다가 길이 2~6의 마무리 어절로 닫는다.
    private static func flexSentence(exactLength target: Int, seed: inout UInt64) -> String {
        switch target {
        case ..<1: return ""
        case 1: return "…"
        case 2: return "늘."
        default: break
        }

        let connectors: [[String]] = [
            ["문득", "괜히", "다시", "조금", "슬쩍"],
            ["천천히", "가만히", "고요히", "기꺼이", "나직이"],
            ["새삼스레", "다정하게", "무던하게", "은근하게"]
        ]
        let enders = ["오늘", "이대로", "잔잔하게", "고즈넉하게", "사부작사부작"]

        var remaining = target
        var words: [String] = []
        while remaining > 7 {
            let cost = 3 + Int(nextRandom(&seed) % 3)
            let pool = connectors[cost - 3]
            words.append(pool[Int(nextRandom(&seed) % UInt64(pool.count))])
            remaining -= cost
        }
        words.append(enders[remaining - 3])
        return words.joined(separator: " ") + "."
    }

    // MARK: - 결정적 난수

    /// 같은 아이디어·설정이면 항상 같은 결과가 나오도록 FNV-1a 기반 시드를 쓴다.
    private static func seed(from text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for scalar in text.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 0x100000001b3
        }
        return hash == 0 ? 1 : hash
    }

    private static func nextRandom(_ seed: inout UInt64) -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed >> 33
    }

    private static func rotated(_ items: [String], seed: inout UInt64) -> [String] {
        guard !items.isEmpty else { return items }
        let offset = Int(nextRandom(&seed) % UInt64(items.count))
        return Array(items[offset...] + items[..<offset])
    }

    // MARK: - 문자 판별

    private static func isHangulSyllable(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) }
    }

    private static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value >= 0x1F000)
        }
    }
}
