import Combine
import Foundation

/// 사람마다 다른 글쓰기 취향을 담는 값. 특정 개인(운영자)의 말투나 기본 문구를 강제하지 않고,
/// 모든 항목은 사용자가 직접 채우거나 비워 둘 수 있는 중립 값으로 시작한다.
struct CreatorProfile: Codable, Equatable, Sendable {
    /// 주로 쓰는 주제. 비어 있으면 프롬프트에 포함하지 않는다.
    var accountTopic: String
    /// 글을 읽을 사람. 비어 있으면 프롬프트에 포함하지 않는다.
    var audience: String
    /// "내 글 반영" 정도(원문을 얼마나 유지할지).
    var preferredLength: PostLength
    /// 이모지 사용 강도(4단계).
    var emojiIntensity: EmojiIntensity
    var prohibitedPhrases: String
    /// 해시태그 취향. 비어 있으면 프롬프트에 포함하지 않는다.
    var hashtagStyle: String
    /// 설정 화면의 다른 항목으로 표현되지 않는 나머지 요구사항을 사용자가 직접 적는 자유 입력란.
    var detailedGuidelines: String
    /// 게시할 곳(플랫폼별 글자 수 기준에 영향을 준다).
    var destination: PostDestination
    /// 글을 읽을 나잇대 힌트. 프롬프트의 독자 나잇대 힌트로만 쓰이고 다른 설정을 바꾸지 않는다.
    var ageGroup: AudienceAgeGroup
    /// 글의 형식(스타일).
    var style: PostStyle
    /// 말투.
    var tone: PostTone
    /// 줄넘김(줄바꿈) 빈도.
    var lineBreakFrequency: LineBreakFrequency
    var generationControls: GenerationControls?
    var additionalInstructions: String?

    var controls: GenerationControls {
        get { generationControls ?? GenerationControls() }
        set { generationControls = newValue }
    }

    init(
        accountTopic: String = "",
        audience: String = "",
        preferredLength: PostLength = .medium,
        emojiIntensity: EmojiIntensity = .low,
        prohibitedPhrases: String = "",
        hashtagStyle: String = "",
        detailedGuidelines: String = "",
        destination: PostDestination = .instagram,
        ageGroup: AudienceAgeGroup = .xz,
        style: PostStyle = .memo,
        tone: PostTone = .kind,
        lineBreakFrequency: LineBreakFrequency = .moderate,
        generationControls: GenerationControls? = nil,
        additionalInstructions: String? = nil
    ) {
        self.accountTopic = accountTopic
        self.audience = audience
        self.preferredLength = preferredLength
        self.emojiIntensity = emojiIntensity
        self.prohibitedPhrases = prohibitedPhrases
        self.hashtagStyle = hashtagStyle
        self.detailedGuidelines = detailedGuidelines
        self.destination = destination
        self.ageGroup = ageGroup
        self.style = style
        self.tone = tone
        self.lineBreakFrequency = lineBreakFrequency
        self.generationControls = generationControls
        self.additionalInstructions = additionalInstructions
    }

    private enum CodingKeys: String, CodingKey {
        case accountTopic, audience, preferredLength, emojiIntensity, usesEmoji,
             prohibitedPhrases, hashtagStyle, detailedGuidelines, destination, ageGroup,
             style, tone, lineBreakFrequency,
             generationControls, additionalInstructions
    }

    /// 예전 저장 데이터(usesEmoji Bool 등)도 계속 읽을 수 있도록 하는 호환 디코딩.
    /// false -> 안 씀, true -> 소극적으로 대응시켜 정보를 잃지 않는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountTopic = try container.decodeIfPresent(String.self, forKey: .accountTopic) ?? ""
        audience = try container.decodeIfPresent(String.self, forKey: .audience) ?? ""
        preferredLength = try container.decodeIfPresent(PostLength.self, forKey: .preferredLength) ?? .medium
        prohibitedPhrases = try container.decodeIfPresent(String.self, forKey: .prohibitedPhrases) ?? ""
        hashtagStyle = try container.decodeIfPresent(String.self, forKey: .hashtagStyle) ?? ""
        detailedGuidelines = try container.decodeIfPresent(String.self, forKey: .detailedGuidelines) ?? ""
        destination = try container.decodeIfPresent(PostDestination.self, forKey: .destination) ?? .instagram
        ageGroup = try container.decodeIfPresent(AudienceAgeGroup.self, forKey: .ageGroup) ?? .xz
        style = try container.decodeIfPresent(PostStyle.self, forKey: .style) ?? .memo
        tone = try container.decodeIfPresent(PostTone.self, forKey: .tone) ?? .kind
        lineBreakFrequency = try container.decodeIfPresent(LineBreakFrequency.self, forKey: .lineBreakFrequency) ?? .moderate
        generationControls = try container.decodeIfPresent(GenerationControls.self, forKey: .generationControls)
        additionalInstructions = try container.decodeIfPresent(String.self, forKey: .additionalInstructions)

        if let intensity = try container.decodeIfPresent(EmojiIntensity.self, forKey: .emojiIntensity) {
            emojiIntensity = intensity
        } else if let legacyUsesEmoji = try container.decodeIfPresent(Bool.self, forKey: .usesEmoji) {
            emojiIntensity = legacyUsesEmoji ? .low : .none
        } else {
            emojiIntensity = .low
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountTopic, forKey: .accountTopic)
        try container.encode(audience, forKey: .audience)
        try container.encode(preferredLength, forKey: .preferredLength)
        try container.encode(emojiIntensity, forKey: .emojiIntensity)
        try container.encode(prohibitedPhrases, forKey: .prohibitedPhrases)
        try container.encode(hashtagStyle, forKey: .hashtagStyle)
        try container.encode(detailedGuidelines, forKey: .detailedGuidelines)
        try container.encode(destination, forKey: .destination)
        try container.encode(ageGroup, forKey: .ageGroup)
        try container.encode(style, forKey: .style)
        try container.encode(tone, forKey: .tone)
        try container.encode(lineBreakFrequency, forKey: .lineBreakFrequency)
        try container.encodeIfPresent(generationControls, forKey: .generationControls)
        try container.encodeIfPresent(additionalInstructions, forKey: .additionalInstructions)
    }

    /// 사용자에게 노출하는 목표 글자 수 범위.
    static let characterCountRange = 50...500

    /// 목표 글자 수를 min(500, 게시 기준 글자 수) 범위 안으로, 최소 50자 이상으로 맞춘다.
    mutating func clampCharacterCountToDestinationLimit() {
        let upperBound = min(Self.characterCountRange.upperBound, destination.characterLimit)
        var updatedControls = controls
        updatedControls.characterCount = min(max(updatedControls.characterCount, Self.characterCountRange.lowerBound), upperBound)
        controls = updatedControls
    }

    /// 모든 AI에 동일하게 전달하는 단일 요청문.
    /// 여기 나오는 항목은 전부 작성 화면에서 보이는 값이거나 "추가로 하고 싶은 설정"에 사용자가 직접 적은 내용이다.
    func generationPrompt(for idea: String, mood: PostMood, length: PostLength) -> String {
        var lines: [String] = [
            "[내가 입력한 내용]",
            idea.trimmingCharacters(in: .whitespacesAndNewlines),
            "",
            "[원하는 결과]",
            "위 내용을 바탕으로 \(destination.title)에 올릴 한국어 글을 쓰고, 완성 문구만 출력해.",
            "- 게시 기준: \(destination.limitBasisDescription)",
            "- 목표 분량: 공백과 줄바꿈 포함 \(controls.characterCount)자를 넘지 않는 선에서 자연스럽게 (억지로 글자 수를 맞추려고 문장을 늘리거나 자르지 마)",
            "- 나잇대: \(ageGroup.promptAudienceHint)",
            "- 분위기: \(mood.rawValue)",
            "- 원문 반영: \(length.promptInstruction)",
            "- 이모지 사용: \(emojiIntensity.promptInstruction)",
            "- 스타일: \(style.promptInstruction)",
            "- 말투: \(tone.promptInstruction)",
            "- 줄넘김: \(lineBreakFrequency.promptInstruction)"
        ]
        if !accountTopic.isEmpty { lines.append("- 주로 쓰는 주제: \(accountTopic)") }
        if !audience.isEmpty { lines.append("- 읽을 사람: \(audience)") }
        if !prohibitedPhrases.isEmpty { lines.append("- 금지 표현: \(prohibitedPhrases)") }
        if !hashtagStyle.isEmpty { lines.append("- 해시태그 취향: \(hashtagStyle)") }
        let details = detailedGuidelines.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty { lines.append("- 추가로 하고 싶은 설정: \(details)") }
        let extra = (additionalInstructions ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { lines.append("- 그 외 요청: \(extra)") }
        return lines.joined(separator: "\n")
    }
}

struct GenerationControls: Codable, Equatable, Sendable {
    var characterCount = 200
}

/// 나잇대 힌트. 프롬프트의 독자 나잇대 설명에만 쓰이고, 이모지·글자 수·분위기·다른 설정을 건드리지 않는다.
enum AudienceAgeGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case xz
    case x
    case threeEightSix
    case kkondae

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xz: "XZ"
        case .x: "X"
        case .threeEightSix: "386"
        case .kkondae: "꼰대"
        }
    }

    var promptAudienceHint: String {
        switch self {
        case .xz: "XZ세대(10~20대)가 편하게 느낄 감각으로"
        case .x: "X세대(40~50대)가 편하게 느낄 감각으로"
        case .threeEightSix: "386세대(50~60대)가 편하게 느낄 감각으로"
        case .kkondae: "꼰대 감성을 흉내 내는 재미있는 톤으로"
        }
    }
}

/// 스타일(글의 형식). 프롬프트의 글 형식 지시로만 쓰인다.
enum PostStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case memo
    case poem
    case diary
    case essay
    case novel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memo: "메모"
        case .poem: "시"
        case .diary: "일기"
        case .essay: "수필"
        case .novel: "소설"
        }
    }

    var promptInstruction: String {
        switch self {
        case .memo: "짧고 간결한 메모 형식으로"
        case .poem: "시적인 형식으로, 행과 여백을 살려서"
        case .diary: "그날의 일을 적는 일기 형식으로"
        case .essay: "생각과 경험을 풀어내는 수필 형식으로"
        case .novel: "소설처럼 장면과 서사가 있는 형식으로"
        }
    }
}

/// 말투. 프롬프트의 어조 지시로만 쓰인다.
enum PostTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case chic
    case fresh
    case kind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chic: "시크하게"
        case .fresh: "참신하게"
        case .kind: "친절하게"
        }
    }

    var promptInstruction: String {
        switch self {
        case .chic: "감정을 절제하고 쿨하게 시크한 말투로"
        case .fresh: "뻔하지 않고 참신한 표현을 쓰는 말투로"
        case .kind: "다정하고 친절한 말투로"
        }
    }
}

/// 줄넘김(줄바꿈) 빈도. 프롬프트의 줄바꿈 지시로만 쓰인다.
enum LineBreakFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case frequent
    case minimal
    case moderate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frequent: "자주"
        case .minimal: "최소"
        case .moderate: "적당히"
        }
    }

    var promptInstruction: String {
        switch self {
        case .frequent: "짧은 문장마다 자주 줄을 바꿔서"
        case .minimal: "줄바꿈을 최소로 줄이고 문단을 길게 이어서"
        case .moderate: "문단 단위로 적당히 줄을 바꿔서"
        }
    }
}

/// 이모지 사용 강도 4단계.
enum EmojiIntensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case low
    case high
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "안 씀"
        case .low: "최소한"
        case .high: "적극적"
        case .heavy: "과하게"
        }
    }

    var promptInstruction: String {
        switch self {
        case .none: "이모지를 전혀 사용하지 않는다"
        case .low: "꼭 필요한 곳에만 아주 가끔 이모지를 사용한다"
        case .high: "문단마다 어울리는 이모지를 적극적으로 사용한다"
        case .heavy: "문장마다 이모지를 과감하게 여러 개 사용한다"
        }
    }
}

/// 게시할 곳. 플랫폼별 공개 글자 수 기준을 프롬프트와 목표 글자 수 상한에 반영한다.
enum PostDestination: String, CaseIterable, Identifiable, Codable, Sendable {
    case instagram
    case kakaoTalk
    case x

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagram: "Instagram"
        case .kakaoTalk: "카카오톡"
        case .x: "X"
        }
    }

    /// 각 서비스가 공개적으로 안내하는 기본 글자 수 상한.
    var characterLimit: Int {
        switch self {
        case .instagram: 2200
        case .kakaoTalk: 200
        case .x: 280
        }
    }

    var recommendedTargetCharacterCount: Int {
        switch self {
        case .instagram: 400
        case .kakaoTalk: 180
        case .x: 240
        }
    }

    var limitBasisDescription: String {
        switch self {
        case .instagram: "Instagram 캡션 최대 2,200자 기준"
        case .kakaoTalk: "카카오톡 공유(퍼가기) 메시지 문구 최대 200자 기준 (일반 채팅 글자 수 제한이 아님)"
        case .x: "X 기본 게시물 최대 280자 기준 (Premium은 더 긴 게시물을 지원하지만 기본값은 280자)"
        }
    }

    var purposeHint: String {
        switch self {
        case .instagram: "사진·영상과 함께 올릴 긴 캡션에 어울려요"
        case .kakaoTalk: "지인에게 공유할 짧은 요약 문구에 어울려요"
        case .x: "타임라인에 바로 올릴 짧고 임팩트 있는 글에 어울려요"
        }
    }
}

/// 과거 "내 프리셋" 저장 데이터 호환용 타입. 더 이상 UI에서 저장/적용하지 않지만,
/// 기존에 저장된 데이터를 그대로 디코딩할 수 있도록 타입만 남겨 둔다.
struct WritingPreset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var controls: GenerationControls
    var additionalInstructions: String
    var writingGuidelines: String
    var accountTopic: String?
    var voice: String?
    var audience: String?
    var preferredLength: PostLength?
    var usesEmoji: Bool?
    var prohibitedPhrases: String?
    var hashtagStyle: String?
}

@MainActor
final class CreatorProfileStore: ObservableObject {
    @Published var profile: CreatorProfile {
        didSet { save() }
    }
    /// 예전 "내 프리셋" 저장 데이터. UI는 더 이상 이 값을 저장/적용하지 않지만,
    /// 이미 저장된 사용자 데이터를 삭제하지 않고 그대로 유지한다.
    @Published private(set) var presets: [WritingPreset] {
        didSet { savePresets() }
    }

    private let defaults: UserDefaults
    private static let storageKey = "creatorProfile"
    private static let presetsStorageKey = "writingPresets"
    private static let migrationVersionKey = "creatorProfileMigrationVersion"
    private static let currentMigrationVersion = 2

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.presetsStorageKey),
           let storedPresets = try? JSONDecoder().decode([WritingPreset].self, from: data) {
            presets = storedPresets
        } else {
            presets = []
        }

        if let data = defaults.data(forKey: Self.storageKey) {
            var decoded = (try? JSONDecoder().decode(CreatorProfile.self, from: data)) ?? CreatorProfile()
            if defaults.integer(forKey: Self.migrationVersionKey) < Self.currentMigrationVersion,
               let legacy = try? JSONDecoder().decode(LegacyProfileSnapshot.self, from: data) {
                decoded = Self.neutralizingLegacyDefaults(in: decoded, legacy: legacy)
            }
            profile = decoded
        } else {
            profile = CreatorProfile()
        }
        defaults.set(Self.currentMigrationVersion, forKey: Self.migrationVersionKey)
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// 예전 저장 형식의 필드만 읽기 위한 임시 스냅샷.
    private struct LegacyProfileSnapshot: Decodable {
        var accountTopic: String?
        var audience: String?
        var hashtagStyle: String?
        var additionalInstructions: String?
    }

    private static let legacyAccountTopic = "나의 일상과 경험"
    private static let legacyAudience = "내 이야기에 공감하는 사람들"
    private static let legacyHashtagStyle = "핵심 키워드 중심"
    private static let legacyAdditionalInstructions: Set<String> = [
        "억지 유행어는 피하고 설명보다 장면, 장면보다 한 방 있는 말맛을 먼저 보여주기",
        "과한 신파 없이 장면은 선명하게, 결론은 무심한 듯 멋있게 남기기",
        "성공담보다 시행착오를 앞세우고, 잔소리가 될 순간에는 자조적인 유머로 방향 틀기",
        "한 번쯤 훈계할 듯 운을 떼되 결론에서는 자기 흑역사를 꺼내 웃음과 쓸 만한 지혜를 함께 남기기",
        "군더더기 없이 낯선 비유와 짧은 호흡을 사용",
        "잔잔한 여운과 따뜻한 장면 묘사를 강조"
    ]

    /// 예전 운영자 전용 기본값과 정확히 같은 값만 비워, 사용자가 직접 고친 내용은 그대로 둔다.
    private static func neutralizingLegacyDefaults(
        in profile: CreatorProfile,
        legacy: LegacyProfileSnapshot
    ) -> CreatorProfile {
        var updated = profile
        if legacy.accountTopic == legacyAccountTopic { updated.accountTopic = "" }
        if legacy.audience == legacyAudience { updated.audience = "" }
        if legacy.hashtagStyle == legacyHashtagStyle { updated.hashtagStyle = "" }
        if let instructions = legacy.additionalInstructions, legacyAdditionalInstructions.contains(instructions) {
            updated.additionalInstructions = nil
        }
        return updated
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: Self.presetsStorageKey)
    }
}

/// 스튜디오와 설정 화면이 함께 쓰는 생성 취향 값의 UserDefaults 키.
/// CreatorProfile JSON에 필드를 더하는 대신 별도 키로 저장해 기존 저장 데이터 호환을 유지한다.
enum SharedGenerationSettings {
    static let moodKey = "sharedPostMood"
    static let storyWeightKey = "sharedStoryWeight"
    static let showsExternalAIBrowserKey = "showsExternalAIBrowser"
}

enum PostLength: String, CaseIterable, Codable, Identifiable, Sendable {
    case short = "짧게"
    case medium = "보통"
    case long = "길게"

    var id: String { rawValue }

    /// "내 글 반영" 선택지 제목.
    var storyWeightTitle: String {
        switch self {
        case .short: "핵심만"
        case .medium: "균형 있게"
        case .long: "최대한 유지"
        }
    }

    /// 각 선택지에서 AI가 무엇을 더하거나 바꿀 수 있는지 설명.
    var storyWeightExplanation: String {
        switch self {
        case .short: "내가 쓴 글의 핵심만 남기고, 표현과 비유는 AI가 새로 씁니다"
        case .medium: "내가 쓴 글과 AI의 새 표현을 절반 정도씩 섞습니다"
        case .long: "내가 쓴 문장과 표현을 최대한 그대로 살리고, AI는 다듬기만 합니다"
        }
    }

    var promptInstruction: String {
        switch self {
        case .short: "입력한 이야기의 핵심만 남기고 새로운 비유와 해석을 적극적으로 더할 것"
        case .medium: "입력한 이야기와 새로운 해석을 균형 있게 섞을 것"
        case .long: "입력한 이야기의 장면과 표현을 최대한 많이 살리고 과도한 각색은 줄일 것"
        }
    }
}

enum PostMood: String, CaseIterable, Codable, Identifiable, Sendable {
    case warm = "따뜻하게"
    case witty = "재치 있게"
    case calm = "담백하게"

    var id: String { rawValue }
}
