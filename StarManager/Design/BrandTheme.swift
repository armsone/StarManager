import SwiftUI

enum BrandTheme {
    static let accent = Color(red: 228 / 255, green: 30 / 255, blue: 37 / 255)
    static let accentSoft = Color(red: 0.965, green: 0.90, blue: 0.90)
    static let warm = Color(red: 0.65, green: 0.27, blue: 0.12)
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let canvas = Color(red: 0.955, green: 0.945, blue: 0.925)
    static let surface = Color(red: 0.985, green: 0.975, blue: 0.96)
    static let resultSurface = Color.white
    static let ink = Color(red: 0.075, green: 0.065, blue: 0.06)
    static let chrome = Color(red: 0.58, green: 0.56, blue: 0.53)
    static let border = Color(red: 0.55, green: 0.52, blue: 0.47).opacity(0.34)

    static let canvasGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.97, blue: 0.95),
            canvas,
            Color(red: 0.92, green: 0.90, blue: 0.87)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

struct StarCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.9), BrandTheme.chrome.opacity(0.5), BrandTheme.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: BrandTheme.ink.opacity(0.07), radius: 16, y: 7)
    }
}

struct GlossyPrimaryButtonStyle: ButtonStyle {
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
            .shadow(color: BrandTheme.ink.opacity(configuration.isPressed ? 0.18 : 0.34), radius: configuration.isPressed ? 4 : 10, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func starCard() -> some View {
        modifier(StarCardModifier())
    }
}
