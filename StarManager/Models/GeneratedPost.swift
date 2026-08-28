import Foundation

/// 생성된 게시물 초안 한 건.
/// 공유 흐름과 상태 복원을 위해 Codable이며, id와 createdAt은 생성 시점에 고정된다.
struct GeneratedPost: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceIdea: String
    let hook: String
    let caption: String
    let callToAction: String
    let hashtags: [String]
    /// 실제 게시에 쓰는 완성 본문. 특정 게시할 곳이나 목표 글자 수를 강제하지 않고 자연스럽게 조립된다.
    let composedText: String
    /// 예전 저장 데이터 호환용으로만 남아 있음. 지금의 작성 흐름은 이 값을 만들거나 참조하지 않는다.
    let targetCharacterCount: Int?
    /// 예전 저장 데이터 호환용으로만 남아 있음. 지금의 작성 흐름은 이 값을 만들거나 참조하지 않는다.
    let destinationCharacterLimit: Int?

    init(
        sourceIdea: String,
        hook: String,
        caption: String,
        callToAction: String,
        hashtags: [String],
        composedText: String? = nil,
        targetCharacterCount: Int = 200,
        destinationCharacterLimit: Int? = nil,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.sourceIdea = sourceIdea
        self.hook = hook
        self.caption = caption
        self.callToAction = callToAction
        self.hashtags = hashtags
        self.composedText = composedText ?? Self.assembleText(
            hook: hook,
            caption: caption,
            callToAction: callToAction,
            hashtags: hashtags
        )
        self.targetCharacterCount = targetCharacterCount
        self.destinationCharacterLimit = destinationCharacterLimit
        self.id = id
        self.createdAt = createdAt
    }

    /// 목록형 UI에 쓰기 좋은 한 줄 제목.
    var listTitle: String {
        let source = sourceIdea.isEmpty ? hook : sourceIdea
        let firstLine = source.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? source
        return firstLine.count > 24 ? String(firstLine.prefix(24)) + "…" : firstLine
    }

    /// 목록형 UI의 부제로 쓰기 좋은 본문 요약.
    var previewSnippet: String {
        let body = composedText.replacingOccurrences(of: "\n", with: " ")
        return body.count > 60 ? String(body.prefix(60)) + "…" : body
    }

    /// 공백/줄바꿈 포함 Character 단위 글자 수.
    var characterCount: Int { composedText.count }

    /// UI에서 선택한 게시 기준 글자 수 상한을 지키는지 표시할 때 사용한다.
    var formatReport: CaptionFormatReport {
        CaptionFormatReport.evaluate(
            composedText,
            destinationLimit: destinationCharacterLimit ?? CaptionFormatReport.neutralSafetyCharacterLimit
        )
    }

    private static func assembleText(
        hook: String,
        caption: String,
        callToAction: String,
        hashtags: [String]
    ) -> String {
        var lines: [String] = []
        if !hashtags.isEmpty {
            lines.append(hashtags.map { "#\($0)" }.joined(separator: " "))
        }
        for part in [hook, caption, callToAction] where !part.isEmpty {
            lines.append(part)
        }
        return lines.joined(separator: "\n")
    }
}

/// 완성 본문이 선택한 게시 기준(플랫폼 글자 수 상한)을 지키는지 나타내는 재사용 가능한 검증 결과.
/// 예전의 해시태그·마침표 줄바꿈·따옴표 금지 같은 숨은 형식 규칙은 더 이상 강제하지 않는다.
struct CaptionFormatReport: Codable, Equatable, Sendable {
    /// 특정 게시할 곳이나 목표 글자 수를 강제하지 않는 지금의 작성 흐름에서, 검증 타입이 구조적으로
    /// 숫자를 요구할 때만 쓰는 넉넉한 안전 상한. 일반적인 글 길이에는 영향을 주지 않는다.
    static let neutralSafetyCharacterLimit = 20_000

    let destinationLimit: Int
    let characterCount: Int
    let isWithinDestinationLimit: Bool

    var passesAllRules: Bool { isWithinDestinationLimit }

    /// UI 배지/목록 표시에 쓰기 좋은, 실패한 규칙 설명 모음.
    var failedRuleDescriptions: [String] {
        isWithinDestinationLimit ? [] : ["게시 기준 \(destinationLimit)자 이내 (현재 \(characterCount)자)"]
    }

    static func evaluate(_ text: String, destinationLimit: Int) -> CaptionFormatReport {
        CaptionFormatReport(
            destinationLimit: destinationLimit,
            characterCount: text.count,
            isWithinDestinationLimit: text.count <= destinationLimit
        )
    }

    static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value >= 0x1F000)
        }
    }
}

/// 외부 AI에서 돌아온 원문을 개인 설정까지 포함해 검사하기 위한 문맥.
struct CaptionValidationContext: Equatable, Sendable {
    let destinationLimit: Int
    let prohibitedPhrases: String
    let emojiIntensity: EmojiIntensity
}

/// 게시 기준 글자 수, 금지 표현, "이모지 안 씀" 준수, 글자 수 표기 금지만 검사하는 가벼운 결과.
struct CaptionValidationReport: Equatable, Sendable {
    let format: CaptionFormatReport
    let prohibitedPhraseMatches: [String]
    let respectsEmojiNonePreference: Bool
    let hasNoCharacterCountLabel: Bool

    var passesAllRules: Bool {
        format.passesAllRules
            && prohibitedPhraseMatches.isEmpty
            && respectsEmojiNonePreference
            && hasNoCharacterCountLabel
    }

    var failedRuleDescriptions: [String] {
        var failures = format.failedRuleDescriptions
        if !prohibitedPhraseMatches.isEmpty {
            failures.append("금지 표현 제외: \(prohibitedPhraseMatches.joined(separator: ", "))")
        }
        if !respectsEmojiNonePreference { failures.append("이모지 안 씀 설정 준수") }
        if !hasNoCharacterCountLabel { failures.append("글자 수 표기 금지") }
        return failures
    }

    static func evaluate(_ text: String, context: CaptionValidationContext) -> CaptionValidationReport {
        let prohibited = context.prohibitedPhrases
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let matches = prohibited.filter { text.localizedCaseInsensitiveContains($0) }
        let containsEmoji = text.contains { CaptionFormatReport.isEmoji($0) }
        let countLabelPattern = #"글자\s*수|[0-9]+\s*자"#
        let hasCountLabel = text.range(of: countLabelPattern, options: .regularExpression) != nil

        return CaptionValidationReport(
            format: CaptionFormatReport.evaluate(text, destinationLimit: context.destinationLimit),
            prohibitedPhraseMatches: matches,
            respectsEmojiNonePreference: context.emojiIntensity != .none || !containsEmoji,
            hasNoCharacterCountLabel: !hasCountLabel
        )
    }
}
