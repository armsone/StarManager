import Foundation

/// 하단 탭의 스튜디오 항목이 캔버스 내용에 따라 보내기 항목으로 바뀌는 상호작용을
/// `ContentView`(탭 표시)와 `ComposerView`(실제 전송 파이프라인) 사이에서 연결한다.
@MainActor
final class ComposerNavState: ObservableObject {
    /// 사진/영상 또는 비어 있지 않은 글이 캔버스에 있는지 여부.
    @Published var hasSendableContent = false
    /// 글과 미디어가 모두 있어 공유 경로(`share()`) 가드를 통과할 수 있는지 여부.
    @Published var hasShareableContent = false
    /// 보내기 항목에 표시할, 마지막으로 선택했거나 켜져 있는 AI.
    @Published var sendChoice: AIProviderIdentity = .device
    @Published private(set) var sendTrigger: UUID?
    @Published private(set) var instagramShareTrigger: UUID?
    @Published private(set) var aiChoiceRevealTrigger: UUID?

    func requestSend() {
        sendTrigger = UUID()
    }

    func clearSendTrigger(_ id: UUID) {
        guard sendTrigger == id else { return }
        sendTrigger = nil
    }

    func requestInstagramShare() {
        instagramShareTrigger = UUID()
    }

    func clearInstagramShareTrigger(_ id: UUID) {
        guard instagramShareTrigger == id else { return }
        instagramShareTrigger = nil
    }

    func requestAIChoiceReveal() {
        aiChoiceRevealTrigger = UUID()
    }
}
