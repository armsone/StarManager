import SwiftUI

enum BrandTheme {
    static let accent = Color(red: 0.42, green: 0.33, blue: 0.67)
    static let accentSoft = Color(red: 0.93, green: 0.91, blue: 0.98)
    static let warm = Color(red: 0.84, green: 0.36, blue: 0.18)
    static let paper = Color(red: 0.99, green: 0.95, blue: 0.86)
    static let canvas = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let surface = Color.white.opacity(0.96)
    static let border = Color(red: 0.81, green: 0.78, blue: 0.72).opacity(0.42)
}

struct StarCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BrandTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func starCard() -> some View {
        modifier(StarCardModifier())
    }
}
