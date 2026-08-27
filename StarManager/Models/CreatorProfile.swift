import Combine
import Foundation

struct CreatorProfile: Codable, Equatable, Sendable {
    var accountTopic = "나의 일상과 경험"
    var voice = "다정하고 솔직하게"
    var audience = "내 이야기에 공감하는 사람들"
    var preferredLength = PostLength.medium
    var usesEmoji = true
    var prohibitedPhrases = ""
    var hashtagStyle = "핵심 키워드 중심"
    var writingGuidelines = Self.defaultWritingGuidelines
    var generationControls: GenerationControls?
    var additionalInstructions: String?

    var controls: GenerationControls {
        get { generationControls ?? GenerationControls() }
        set { generationControls = newValue }
    }

    static let defaultWritingGuidelines = """
    인스타그램에 올릴 글로 작성해줘. 아래의 내용을 참고해
    - 결과만 출력
    - 인스타그램용 산문
    - 공백 포함 200자 정확히 준수
    - 감동 20% / 친절함 20% / 참신함 30% / 남자다움 20% / 시크함 10%
    - 혼잣말처럼 서술
    - 흔하지 않은 유의어 사용
    - 라임과 리듬 살릴 것
    - 문장 중간 따옴표 사용 가능
    - 전체 따옴표 사용 금지
    - 마침표 있으면 무조건 줄바꿈
    - 쉼표도 문맥에 맞게 가능하면 줄바꿈
    - 첫 줄에 한글 태그 2개 연속
    - 이모티콘은 첫줄 빼고 문단 앞쪽에만 절제해서 사용
    - 마지막 줄은 전체 요약 1줄 + 이모티콘 앞뒤 배치
    - 글자수 표기 금지
    """

    func prompt(for idea: String) -> String {
        let activeGuidelines = writingGuidelines
            .components(separatedBy: .newlines)
            .filter { line in
                !line.contains("공백 포함 200자")
                    && !line.contains("감동 20% / 친절함 20%")
            }
            .joined(separator: "\n")
        let extra = (additionalInstructions ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(activeGuidelines)

        아래 현재 설정을 기존 지침의 수치보다 최우선으로 적용:
        - 공백 포함 \(controls.characterCount)자 정확히 준수
        - 감동 \(controls.emotion)% / 친절함 \(controls.kindness)% / 참신함 \(controls.originality)% / 남자다움 \(controls.masculinity)% / 시크함 \(controls.chic)%
        - 계정 주제: \(accountTopic)
        - 주요 독자: \(audience)
        - 나의 말투: \(voice)
        - 본문 이모지 사용: \(usesEmoji ? "문단 앞쪽에만 절제해서 사용" : "마지막 요약 줄의 필수 이모지를 제외하고 사용하지 않음")
        - 금지 표현: \(prohibitedPhrases.isEmpty ? "없음" : prohibitedPhrases)
        - 해시태그 취향: \(hashtagStyle)
        \(extra.isEmpty ? "" : "- 추가 옵션: \(extra)")

        작성할 이야기:
        \(idea)
        """
    }

    /// 모든 AI에 동일하게 전달하는 짧고 명확한 단일 요청문.
    func generationPrompt(for idea: String, mood: PostMood, length: PostLength) -> String {
        let extra = (additionalInstructions ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        var request = """
        [내가 입력한 내용]
        \(idea.trimmingCharacters(in: .whitespacesAndNewlines))

        [원하는 결과]
        위 내용으로 한국어 인스타그램 산문을 쓰고 완성 문구만 출력해.
        - 공백과 줄바꿈을 포함해 정확히 \(controls.characterCount)자
        - 첫 줄: 한글 해시태그 2개 연속
        - 본문: \(mood.rawValue), \(voice), \(length.promptInstruction)
        - 문장마다 줄바꿈하고 상투어 없이 자연스럽게 작성
        - 이모지: \(usesEmoji ? "첫 줄을 제외한 문단 앞쪽에만 절제해 사용" : "마지막 요약 줄 외에는 사용하지 않음")
        - 마지막 줄: 전체 내용을 요약하고 앞뒤를 이모지로 감싸기
        - 금지 표현: \(prohibitedPhrases.isEmpty ? "없음" : prohibitedPhrases)
        - 해시태그 방향: \(hashtagStyle)
        """

        if !extra.isEmpty {
            request += "\n\n[추가 요청]\n" + extra
        }
        return request
    }
}

struct GenerationControls: Codable, Equatable, Sendable {
    var characterCount = 200
    var emotion = 20
    var kindness = 20
    var originality = 30
    var masculinity = 20
    var chic = 10

    var toneTotal: Int { emotion + kindness + originality + masculinity + chic }
}

enum GenerationStylePreset: String, CaseIterable, Identifiable, Sendable {
    case mz
    case genX
    case generation386
    case babyBoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mz: "MZ"
        case .genX: "X"
        case .generation386: "386"
        case .babyBoom: "꼰대"
        }
    }

    var symbolName: String {
        switch self {
        case .mz: "figure.wave"
        case .genX: "figure.walk"
        case .generation386: "figure.stand"
        case .babyBoom: "person.fill"
        }
    }

    var summary: String {
        switch self {
        case .mz: "짧고 힙하게, 말맛은 톡톡"
        case .genX: "감성은 뜨겁게, 표현은 쿨하게"
        case .generation386: "경험은 묵직하게, 잔소리는 가볍게"
        case .babyBoom: "라떼는 진하게, 잔소리는 짧게"
        }
    }

    func applying(to profile: CreatorProfile) -> CreatorProfile {
        var updated = profile
        let characterCount = profile.controls.characterCount

        switch self {
        case .mz:
            updated.voice = "짧고 빠른 호흡으로, 눈치 빠른 한마디와 신선한 비유를 섞어 재치 있게"
            updated.usesEmoji = true
            updated.additionalInstructions = "억지 유행어는 피하고 설명보다 장면, 장면보다 한 방 있는 말맛을 먼저 보여주기"
            updated.controls = GenerationControls(characterCount: characterCount, emotion: 15, kindness: 15, originality: 45, masculinity: 5, chic: 20)
        case .genX:
            updated.voice = "속은 뜨겁지만 겉은 쿨하게, 낭만과 현실을 한 문장 안에서 교차시키며"
            updated.usesEmoji = false
            updated.additionalInstructions = "과한 신파 없이 장면은 선명하게, 결론은 무심한 듯 멋있게 남기기"
            updated.controls = GenerationControls(characterCount: characterCount, emotion: 25, kindness: 15, originality: 25, masculinity: 15, chic: 20)
        case .generation386:
            updated.voice = "살아본 사람의 현실감은 살리되 정답을 강요하지 않고 유쾌하게"
            updated.usesEmoji = false
            updated.additionalInstructions = "성공담보다 시행착오를 앞세우고, 잔소리가 될 순간에는 자조적인 유머로 방향 틀기"
            updated.controls = GenerationControls(characterCount: characterCount, emotion: 20, kindness: 25, originality: 15, masculinity: 25, chic: 15)
        case .babyBoom:
            updated.voice = "라떼 한 잔 같은 연륜을 깔고, 스스로도 웃을 줄 아는 능청스러운 꼰대 말투로"
            updated.usesEmoji = false
            updated.additionalInstructions = "한 번쯤 훈계할 듯 운을 떼되 결론에서는 자기 흑역사를 꺼내 웃음과 쓸 만한 지혜를 함께 남기기"
            updated.controls = GenerationControls(characterCount: characterCount, emotion: 30, kindness: 35, originality: 10, masculinity: 15, chic: 10)
        }
        return updated
    }
}

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

    init(
        id: UUID = UUID(),
        name: String,
        controls: GenerationControls,
        additionalInstructions: String = "",
        writingGuidelines: String = CreatorProfile.defaultWritingGuidelines,
        accountTopic: String? = nil,
        voice: String? = nil,
        audience: String? = nil,
        preferredLength: PostLength? = nil,
        usesEmoji: Bool? = nil,
        prohibitedPhrases: String? = nil,
        hashtagStyle: String? = nil
    ) {
        self.id = id
        self.name = name
        self.controls = controls
        self.additionalInstructions = additionalInstructions
        self.writingGuidelines = writingGuidelines
        self.accountTopic = accountTopic
        self.voice = voice
        self.audience = audience
        self.preferredLength = preferredLength
        self.usesEmoji = usesEmoji
        self.prohibitedPhrases = prohibitedPhrases
        self.hashtagStyle = hashtagStyle
    }

    static let defaults: [WritingPreset] = [
        WritingPreset(name: "균형 잡힌 기본", controls: GenerationControls()),
        WritingPreset(
            name: "감성적인 기록",
            controls: GenerationControls(characterCount: 250, emotion: 40, kindness: 25, originality: 20, masculinity: 5, chic: 10),
            additionalInstructions: "잔잔한 여운과 따뜻한 장면 묘사를 강조"
        ),
        WritingPreset(
            name: "참신하고 시크하게",
            controls: GenerationControls(characterCount: 180, emotion: 10, kindness: 10, originality: 40, masculinity: 15, chic: 25),
            additionalInstructions: "군더더기 없이 낯선 비유와 짧은 호흡을 사용"
        )
    ]
}

@MainActor
final class CreatorProfileStore: ObservableObject {
    @Published var profile: CreatorProfile {
        didSet { save() }
    }
    @Published private(set) var presets: [WritingPreset] {
        didSet { savePresets() }
    }

    private let defaults: UserDefaults
    private static let storageKey = "creatorProfile"
    private static let presetsStorageKey = "writingPresets"
    private static let defaultStyleVersionKey = "defaultGenerationStyleVersion"
    private static let currentDefaultStyleVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.presetsStorageKey),
           let storedPresets = try? JSONDecoder().decode([WritingPreset].self, from: data) {
            presets = storedPresets
        } else {
            presets = WritingPreset.defaults
        }

        let storedProfile: CreatorProfile
        if let data = defaults.data(forKey: Self.storageKey),
           let decodedProfile = try? JSONDecoder().decode(CreatorProfile.self, from: data) {
            storedProfile = decodedProfile
        } else {
            storedProfile = CreatorProfile()
        }

        if defaults.integer(forKey: Self.defaultStyleVersionKey) < Self.currentDefaultStyleVersion {
            profile = GenerationStylePreset.generation386.applying(to: storedProfile)
            defaults.set(Self.currentDefaultStyleVersion, forKey: Self.defaultStyleVersionKey)
            if let data = try? JSONEncoder().encode(profile) {
                defaults.set(data, forKey: Self.storageKey)
            }
        } else {
            profile = storedProfile
        }
    }

    func restoreDefaultWritingGuidelines() {
        profile.writingGuidelines = CreatorProfile.defaultWritingGuidelines
    }

    func savePreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let preset = WritingPreset(
            name: name,
            controls: profile.controls,
            additionalInstructions: profile.additionalInstructions ?? "",
            writingGuidelines: profile.writingGuidelines,
            accountTopic: profile.accountTopic,
            voice: profile.voice,
            audience: profile.audience,
            preferredLength: profile.preferredLength,
            usesEmoji: profile.usesEmoji,
            prohibitedPhrases: profile.prohibitedPhrases,
            hashtagStyle: profile.hashtagStyle
        )
        var updated = presets.filter { $0.name != name }
        updated.append(preset)
        presets = updated
    }

    func apply(_ preset: WritingPreset) {
        var updated = profile
        updated.controls = preset.controls
        updated.additionalInstructions = preset.additionalInstructions
        updated.writingGuidelines = preset.writingGuidelines
        if let value = preset.accountTopic { updated.accountTopic = value }
        if let value = preset.voice { updated.voice = value }
        if let value = preset.audience { updated.audience = value }
        if let value = preset.preferredLength { updated.preferredLength = value }
        if let value = preset.usesEmoji { updated.usesEmoji = value }
        if let value = preset.prohibitedPhrases { updated.prohibitedPhrases = value }
        if let value = preset.hashtagStyle { updated.hashtagStyle = value }
        profile = updated
    }

    func deletePreset(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            presets.remove(at: index)
        }
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
    static let stylePresetKey = "sharedGenerationStylePreset"
}

enum PostLength: String, CaseIterable, Codable, Identifiable, Sendable {
    case short = "짧게"
    case medium = "보통"
    case long = "길게"

    var id: String { rawValue }

    var storyWeightTitle: String {
        switch self {
        case .short: "낮게"
        case .medium: "보통"
        case .long: "높게"
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
