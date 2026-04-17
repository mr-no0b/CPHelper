import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let card = Color.white
    static let cardBorder = Color(red: 0.87, green: 0.90, blue: 0.95)
    static let accent = Color(red: 0.09, green: 0.40, blue: 0.74)
    static let accentSecondary = Color(red: 0.06, green: 0.61, blue: 0.66)
    static let warm = Color(red: 0.96, green: 0.56, blue: 0.31)
    static let success = Color(red: 0.16, green: 0.63, blue: 0.38)
    static let warning = Color(red: 0.93, green: 0.59, blue: 0.14)
    static let text = Color(red: 0.10, green: 0.14, blue: 0.21)
    static let mutedText = Color(red: 0.46, green: 0.53, blue: 0.62)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.18, blue: 0.35),
            Color(red: 0.07, green: 0.46, blue: 0.58),
            Color(red: 0.92, green: 0.52, blue: 0.31)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.98, blue: 1.00),
            Color(red: 0.93, green: 0.97, blue: 0.99),
            Color(red: 1.00, green: 0.95, blue: 0.91)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appInputField() -> some View {
        modifier(AppTextFieldModifier())
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.heroGradient)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent.opacity(configuration.isPressed ? 0.08 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
    }
}

extension Font {
    static let appHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let appSection = Font.system(.title3, design: .rounded).weight(.bold)
    static let appBody = Font.system(.body, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded).weight(.medium)
}
