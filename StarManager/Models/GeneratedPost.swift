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
    /// 실제 게시에 쓰는 완성 본문. 공백/줄바꿈 포함 정확히 200자를 목표로 조립된다.
    let composedText: String
    let targetCharacterCount: Int?

    init(
        sourceIdea: String,
        hook: String,
        caption: String,
        callToAction: String,
        hashtags: [String],
        composedText: String? = nil,
        targetCharacterCount: Int = 200,
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

    /// UI에서 200자 준수 여부와 필수 형식 규칙 통과 여부를 표시할 때 사용한다.
    var formatReport: CaptionFormatReport {
        CaptionFormatReport.evaluate(composedText, requiredCharacterCount: targetCharacterCount ?? 200)
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

/// 완성 본문이 저장된 작성 지침의 필수 형식 규칙을 지키는지 나타내는 재사용 가능한 검증 결과.
struct CaptionFormatReport: Codable, Equatable, Sendable {
    let requiredCharacterCount: Int
    let characterCount: Int
    let hasExactCharacterCount: Bool
    let firstLineHasTwoKoreanHashtags: Bool
    let periodsAlwaysEndLines: Bool
    let hasNoFullTextQuotes: Bool
    let emojiUsageIsRestrained: Bool
    let lastLineIsEmojiWrappedSummary: Bool

    var passesAllRules: Bool {
        hasExactCharacterCount
            && firstLineHasTwoKoreanHashtags
            && periodsAlwaysEndLines
            && hasNoFullTextQuotes
            && emojiUsageIsRestrained
            && lastLineIsEmojiWrappedSummary
    }

    /// UI 배지/목록 표시에 쓰기 좋은, 실패한 규칙 설명 모음.
    var failedRuleDescriptions: [String] {
        var failures: [String] = []
        if !hasExactCharacterCount {
            failures.append("공백 포함 \(requiredCharacterCount)자 (현재 \(characterCount)자)")
        }
        if !firstLineHasTwoKoreanHashtags { failures.append("첫 줄 한글 해시태그 2개 연속") }
        if !periodsAlwaysEndLines { failures.append("마침표 뒤 줄바꿈") }
        if !hasNoFullTextQuotes { failures.append("전체 따옴표 금지") }
        if !emojiUsageIsRestrained { failures.append("이모지 절제 사용") }
        if !lastLineIsEmojiWrappedSummary { failures.append("마지막 줄 이모지로 감싼 요약") }
        return failures
    }

    static func evaluate(_ text: String, requiredCharacterCount: Int = 200) -> CaptionFormatReport {
        let lines = text.components(separatedBy: "\n")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let wrappedInQuotes = ["\"", "“", "”"].contains { mark in
            trimmed.count >= 2 && trimmed.hasPrefix(mark)
                && ["\"", "“", "”"].contains(String(trimmed.suffix(1)))
        }

        return CaptionFormatReport(
            requiredCharacterCount: requiredCharacterCount,
            characterCount: text.count,
            hasExactCharacterCount: text.count == requiredCharacterCount,
            firstLineHasTwoKoreanHashtags: firstLineHasHashtagPair(lines.first ?? ""),
            periodsAlwaysEndLines: lines.allSatisfy { !$0.dropLast().contains(".") },
            hasNoFullTextQuotes: !wrappedInQuotes,
            emojiUsageIsRestrained: emojiIsRestrained(in: lines),
            lastLineIsEmojiWrappedSummary: lastLineIsWrappedSummary(lines.last ?? "")
        )
    }

    private static func firstLineHasHashtagPair(_ line: String) -> Bool {
        let tokens = line.split(separator: " ")
        guard tokens.count == 2 else { return false }
        return tokens.allSatisfy { token in
            token.count >= 2 && token.hasPrefix("#")
                && token.dropFirst().allSatisfy(isHangul)
        }
    }

    private static func lastLineIsWrappedSummary(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, let last = line.last else { return false }
        let core = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        return isEmoji(first) && isEmoji(last) && !core.isEmpty
    }

    /// 첫 줄에는 이모지가 없어야 하고, 본문 줄은 문단 앞에만, 마지막 줄은 앞뒤 배치만 허용한다.
    private static func emojiIsRestrained(in lines: [String]) -> Bool {
        for (index, line) in lines.enumerated() {
            let characters = Array(line)
            for (position, character) in characters.enumerated() where isEmoji(character) {
                if index == 0 { return false }
                let isLastLine = index == lines.count - 1
                let allowed = position == 0 || (isLastLine && position == characters.count - 1)
                if !allowed { return false }
            }
        }
        return true
    }

    private static func isHangul(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) }
    }

    fileprivate static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value >= 0x1F000)
        }
    }
}

/// 외부 AI에서 돌아온 원문을 개인 설정까지 포함해 검사하기 위한 문맥.
struct CaptionValidationContext: Equatable, Sendable {
    let requiredCharacterCount: Int
    let prohibitedPhrases: String
    let allowsBodyEmoji: Bool
    var minimumLineCount = 3
}

/// 기본 형식 검사에 금지 표현, 본문 이모지, 글자 수 표기와 최소 문단 검사를 더한 결과.
struct CaptionValidationReport: Equatable, Sendable {
    let format: CaptionFormatReport
    let prohibitedPhraseMatches: [String]
    let respectsBodyEmojiPreference: Bool
    let hasNoCharacterCountLabel: Bool
    let hasMinimumLineCount: Bool

    var passesAllRules: Bool {
        format.passesAllRules
            && prohibitedPhraseMatches.isEmpty
            && respectsBodyEmojiPreference
            && hasNoCharacterCountLabel
            && hasMinimumLineCount
    }

    var failedRuleDescriptions: [String] {
        var failures = format.failedRuleDescriptions
        if !prohibitedPhraseMatches.isEmpty {
            failures.append("금지 표현 제외: \(prohibitedPhraseMatches.joined(separator: ", "))")
        }
        if !respectsBodyEmojiPreference { failures.append("본문 이모지 설정 준수") }
        if !hasNoCharacterCountLabel { failures.append("글자 수 표기 금지") }
        if !hasMinimumLineCount { failures.append("태그·본문·요약 문단 구성") }
        return failures
    }

    static func evaluate(_ text: String, context: CaptionValidationContext) -> CaptionValidationReport {
        let lines = text.components(separatedBy: "\n")
        let prohibited = context.prohibitedPhrases
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let matches = prohibited.filter { text.localizedCaseInsensitiveContains($0) }
        let bodyLines = lines.dropFirst().dropLast()
        let bodyContainsEmoji = bodyLines.joined(separator: "\n").contains { character in
            CaptionFormatReport.isEmoji(character)
        }
        let countLabelPattern = #"글자\s*수|[0-9]+\s*자"#
        let hasCountLabel = text.range(of: countLabelPattern, options: .regularExpression) != nil

        return CaptionValidationReport(
            format: CaptionFormatReport.evaluate(
                text,
                requiredCharacterCount: context.requiredCharacterCount
            ),
            prohibitedPhraseMatches: matches,
            respectsBodyEmojiPreference: context.allowsBodyEmoji || !bodyContainsEmoji,
            hasNoCharacterCountLabel: !hasCountLabel,
            hasMinimumLineCount: lines.count >= context.minimumLineCount
        )
    }
}
