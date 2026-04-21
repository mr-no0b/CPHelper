import SwiftUI

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

enum CodeforcesRatingPalette {
    static func tint(for rating: Int?) -> Color {
        guard let rating else { return AppTheme.text }

        switch rating {
        case ..<1200:
            return Color(red: 0.50, green: 0.54, blue: 0.60)
        case ..<1400:
            return Color(red: 0.16, green: 0.63, blue: 0.29)
        case ..<1600:
            return Color(red: 0.04, green: 0.67, blue: 0.73)
        case ..<1900:
            return Color(red: 0.18, green: 0.45, blue: 0.92)
        case ..<2100:
            return Color(red: 0.53, green: 0.33, blue: 0.86)
        case ..<2400:
            return Color(red: 0.95, green: 0.57, blue: 0.23)
        default:
            return Color(red: 0.83, green: 0.22, blue: 0.24)
        }
    }

    static func background(for rating: Int?) -> Color {
        tint(for: rating).opacity(rating == nil ? 0.10 : 0.14)
    }
}

struct CodeforcesHandleView: View {
    enum Style {
        case plain
        case badge
    }

    let handle: String
    var rating: Int? = nil
    var style: Style = .plain
    var font: Font = .system(.headline, design: .rounded).weight(.bold)
    var loadRatingIfNeeded = true

    @State private var resolvedRating: Int?

    private var effectiveRating: Int? {
        rating ?? resolvedRating
    }

    private var tint: Color {
        CodeforcesRatingPalette.tint(for: effectiveRating)
    }

    var body: some View {
        Group {
            switch style {
            case .plain:
                handleText
            case .badge:
                handleText
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(CodeforcesRatingPalette.background(for: effectiveRating))
                    )
            }
        }
        .task(id: taskKey) {
            await resolveRatingIfNeeded()
        }
    }

    private var handleText: some View {
        Text(handle)
            .font(font)
            .foregroundStyle(tint)
    }

    private var taskKey: String {
        "\(handle.lowercased())::\(rating.map(String.init) ?? "nil")::\(loadRatingIfNeeded)"
    }

    private func resolveRatingIfNeeded() async {
        guard loadRatingIfNeeded, rating == nil, !handle.isEmpty else {
            await MainActor.run {
                resolvedRating = nil
            }
            return
        }

        do {
            let analysis = try await CodeforcesAnalysisService.shared.loadAnalysis(for: handle)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                resolvedRating = analysis.summary.currentRating
            }
        } catch {
            await MainActor.run {
                resolvedRating = nil
            }
        }
    }
}

struct AvatarView: View {
    let title: String
    let imageURL: URL?
    let size: CGFloat
    var gradient: LinearGradient = AppTheme.heroGradient

    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(gradient)
                Text(String(title.prefix(1)).uppercased())
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 2)
        )
    }
}
