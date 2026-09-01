import Combine
import Foundation

/// 제공자별 마지막 실제 실행 시각과 걸린 시간. 설정 화면에서 어떤 AI가 실행됐고
/// 응답을 받는 데 얼마나 걸렸는지 보여주는 데에만 쓰인다.
struct AIRunMetric: Codable, Equatable, Sendable {
    var lastRunAt: Date
    var elapsedSeconds: Double
}

@MainActor
final class AIRunMetricsStore: ObservableObject {
    @Published private(set) var metrics: [AIProviderIdentity: AIRunMetric] = [:] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private static let storageKey = "aiProviderRunMetrics"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: AIRunMetric].self, from: data) else { return }
        metrics = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            AIProviderIdentity(rawValue: key).map { ($0, value) }
        })
    }

    func metric(for identity: AIProviderIdentity) -> AIRunMetric? {
        metrics[identity]
    }

    /// 실제 실행 시작·종료 시각을 기준으로 걸린 시간을 기록한다. 미리보기용 결정적 생성 등
    /// 실제 AI 호출이 아닌 경로에서는 호출하지 않는다.
    func recordRun(for identity: AIProviderIdentity, elapsedSeconds: Double, at date: Date = Date()) {
        metrics[identity] = AIRunMetric(lastRunAt: date, elapsedSeconds: max(0, elapsedSeconds))
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues: metrics.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
