import SwiftUI

struct HandleRoute: Identifiable, Hashable {
    let id = UUID()
    let handle: String
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.softGradient

            Circle()
                .fill(AppTheme.accent.opacity(0.09))
                .frame(width: 260, height: 260)
                .offset(x: -120, y: -250)

            Circle()
                .fill(AppTheme.warm.opacity(0.11))
                .frame(width: 320, height: 320)
                .offset(x: 150, y: -280)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(AppTheme.accentSecondary.opacity(0.06))
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(18))
                .offset(x: 120, y: 280)
        }
        .ignoresSafeArea()
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appSection)
                .foregroundStyle(AppTheme.text)

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

struct MetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.background)
        )
    }
}

struct InfoBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}
