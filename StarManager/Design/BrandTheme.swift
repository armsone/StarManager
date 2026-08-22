import SwiftUI

enum AppearanceStyle: String, CaseIterable, Identifiable, Sendable {
    case bk
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bk: "BK"
        case .classic: "클래식"
        }
    }
}

/// 앱 전체 테마. 루트에서 `\.brandTheme` 환경으로 주입되며,
/// 스타일이 바뀌면 환경 갱신으로 모든 뷰가 즉시 다시 그려진다.
struct BrandTheme: Equatable {
    static let appearanceStorageKey = "appearanceStyle"

    var style: AppearanceStyle

    /// 시그니처 레드 #E41E25 — BK에서는 구조 요소에만 소량, 클래식에서는 기존 틴트로 사용.
    static let accent = Color(red: 228 / 255, green: 30 / 255, blue: 37 / 255)
    var accent: Color { Self.accent }

    /// 카본 — 어두운 기술 구조(주 버튼, 아이콘 웰, 배지). BK 전용 구조색.
    static let carbon = Color(red: 0.125, green: 0.125, blue: 0.14)
    var carbon: Color { Self.carbon }

    /// 옥스블러드 가죽(BK) / 따뜻한 갈색(클래식) — 손이 닿는 개인 취향 영역에만 선택적으로 사용.
    var leather: Color {
        switch style {
        case .bk: Color(red: 0.33, green: 0.11, blue: 0.12)
        case .classic: Color(red: 0.65, green: 0.27, blue: 0.12)
        }
    }

    var accentSoft: Color {
        switch style {
        case .bk: Color(red: 0.955, green: 0.91, blue: 0.91)
        case .classic: Color(red: 0.965, green: 0.90, blue: 0.90)
        }
    }

    var warm: Color { leather }

    var paper: Color {
        switch style {
        case .bk: Color(red: 0.955, green: 0.955, blue: 0.962)
        case .classic: Color(red: 0.97, green: 0.94, blue: 0.88)
        }
    }

    var canvas: Color {
        switch style {
        case .bk: Color(red: 0.937, green: 0.94, blue: 0.947)
        case .classic: Color(red: 0.955, green: 0.945, blue: 0.925)
        }
    }

    /// BK: 흰 에나멜, 클래식: 따뜻한 종이 표면.
    var surface: Color {
        switch style {
        case .bk: .white
        case .classic: Color(red: 0.985, green: 0.975, blue: 0.96)
        }
    }

    static let resultSurface = Color.white
    var resultSurface: Color { Self.resultSurface }

    var ink: Color {
        switch style {
        case .bk: Color(red: 0.09, green: 0.09, blue: 0.10)
        case .classic: Color(red: 0.075, green: 0.065, blue: 0.06)
        }
    }

    /// 크롬 — BK 헤어라인 스트로크 전용, 넓은 면에 쓰지 않음.
    var chrome: Color {
        switch style {
        case .bk: Color(red: 0.71, green: 0.72, blue: 0.75)
        case .classic: Color(red: 0.58, green: 0.56, blue: 0.53)
        }
    }

    var border: Color {
        switch style {
        case .bk: Color(red: 0.60, green: 0.62, blue: 0.66).opacity(0.32)
        case .classic: Color(red: 0.55, green: 0.52, blue: 0.47).opacity(0.34)
        }
    }

    /// 선택된 항목의 바탕 — 두 스타일 모두 옅은 레드 계열, 채도는 각자 톤에 맞춤.
    var selectionFill: Color { accentSoft }

    /// 컨트롤 틴트 — BK는 카본으로 절제, 클래식은 기존 레드 유지.
    var controlTint: Color {
        switch style {
        case .bk: Self.carbon
        case .classic: Self.accent
        }
    }

    var canvasGradient: LinearGradient {
        switch style {
        case .bk:
            LinearGradient(
                colors: [
                    Color(red: 0.972, green: 0.974, blue: 0.98),
                    canvas,
                    Color(red: 0.905, green: 0.91, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .classic:
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.95),
                    canvas,
                    Color(red: 0.92, green: 0.90, blue: 0.87)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static let glossyBlack = LinearGradient(
        stops: [
            .init(color: Color(red: 0.23, green: 0.22, blue: 0.23), location: 0),
            .init(color: Color(red: 0.09, green: 0.08, blue: 0.085), location: 0.48),
            .init(color: Color(red: 0.035, green: 0.03, blue: 0.035), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

private struct BrandThemeKey: EnvironmentKey {
    static let defaultValue = BrandTheme(style: .bk)
}

extension EnvironmentValues {
    var brandTheme: BrandTheme {
        get { self[BrandThemeKey.self] }
        set { self[BrandThemeKey.self] = newValue }
    }
}

enum BrandIconTone {
    case carbon
    case leather

    func fill(in theme: BrandTheme) -> Color {
        switch self {
        case .carbon: theme.carbon
        case .leather: theme.leather
        }
    }
}

/// 섹션 제목 앞에 붙는 작은 아이콘 웰(BK 전용). 장식이므로 VoiceOver에서는 숨긴다.
struct BrandIconWell: View {
    let systemImage: String
    var tone = BrandIconTone.carbon

    @Environment(\.brandTheme) private var theme
    @ScaledMetric(relativeTo: .footnote) private var wellSize: CGFloat = 26

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: wellSize, height: wellSize)
            .background(tone.fill(in: theme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.chrome.opacity(0.5), lineWidth: 0.7)
            }
            .accessibilityHidden(true)
    }
}

/// 섹션 제목. BK는 아이콘 웰, 클래식은 원래의 평범한 텍스트를 그대로 쓴다.
struct BrandSectionTitle: View {
    let title: String
    let systemImage: String
    var tone = BrandIconTone.carbon

    @Environment(\.brandTheme) private var theme

    var body: some View {
        switch theme.style {
        case .bk:
            HStack(spacing: 9) {
                BrandIconWell(systemImage: systemImage, tone: tone)
                Text(title)
            }
        case .classic:
            Text(title)
        }
    }
}

struct StarCardModifier: ViewModifier {
    @Environment(\.brandTheme) private var theme

    func body(content: Content) -> some View {
        switch theme.style {
        case .bk:
            content
                .padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.9), theme.chrome.opacity(0.5), theme.border],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: theme.ink.opacity(0.07), radius: 16, y: 7)
        case .classic:
            content
                .padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.9), theme.chrome.opacity(0.5), theme.border],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: theme.ink.opacity(0.07), radius: 16, y: 7)
        }
    }
}

/// 주 실행 버튼. 클래식의 원래 글로시 블랙을 유지하고 BK도 카본 소재로 활용한다.
struct GlossyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.brandTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(BrandTheme.glossyBlack, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.08 : 0.28))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 0.8)
            }
            .shadow(color: theme.ink.opacity(configuration.isPressed ? 0.18 : 0.34), radius: configuration.isPressed ? 4 : 10, y: configuration.isPressed ? 2 : 5)
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func starCard() -> some View {
        modifier(StarCardModifier())
    }
}
