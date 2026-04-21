import Charts
import SwiftUI

struct HandleAnalysisDashboard: View {
    let analysis: HandleAnalysis
    var showsHeader = true

    private let weakPalette: [Color] = [
        AppTheme.warning,
        AppTheme.accent,
        AppTheme.accentSecondary,
        AppTheme.warm,
        AppTheme.success
    ]

    private var weakTopics: [WeakTopic] {
        analysis.topicPerformance
            .filter { $0.attemptedCount >= 3 }
            .map { topic in
                let attemptWeight = Double(topic.attemptedCount)
                let weaknessScore = (1 - topic.acceptanceRate) * attemptWeight
                return WeakTopic(topic: topic, weaknessScore: weaknessScore)
            }
            .sorted { lhs, rhs in
                if lhs.weaknessScore == rhs.weaknessScore {
                    return lhs.topic.attemptedCount > rhs.topic.attemptedCount
                }
                return lhs.weaknessScore > rhs.weaknessScore
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsHeader {
                headerCard
            }

            ratingHistoryCard
            ratingDistributionCard
            pieGrid
            activityCard
            roundTypeCard
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                AvatarView(
                    title: analysis.handle,
                    imageURL: analysis.summary.avatarURL,
                    size: 68
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(analysis.summary.displayName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    CodeforcesHandleView(
                        handle: analysis.handle,
                        rating: analysis.summary.currentRating,
                        font: .system(.subheadline, design: .rounded),
                        loadRatingIfNeeded: false
                    )
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCell(title: "Current", value: analysis.summary.currentRating.map(String.init) ?? "Unrated")
                statCell(title: "Max", value: analysis.summary.maxRating.map(String.init) ?? "Unrated")
                statCell(title: "Solved", value: NumberFormatting.compact(analysis.summary.solvedCount))
                statCell(title: "AC", value: NumberFormatting.percentage(analysis.summary.overallAcceptanceRate))
                statCell(title: "Since", value: analysis.summary.firstActiveDate.map { DateFormatting.mediumDate.string(from: $0) } ?? "N/A")
                statCell(title: "Peak solved", value: analysis.summary.highestSolvedRating.map(String.init) ?? "N/A")
            }
        }
        .appCard()
    }

    private var ratingHistoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Rating", subtitle: "History")

            if analysis.ratingHistory.isEmpty {
                emptyState("No public rating history.")
            } else {
                Chart(analysis.ratingHistory) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.newRating)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.newRating)
                    )
                    .foregroundStyle(AppTheme.accent.opacity(0.12))
                }
                .frame(height: 220)
            }
        }
        .appCard()
    }

    private var ratingDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Solved By Rating", subtitle: "Distribution")

            if analysis.solvedByRating.isEmpty {
                emptyState("No rated solves.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(analysis.solvedByRating) { item in
                        BarMark(
                            x: .value("Rating", item.label),
                            y: .value("Solved", item.solvedCount)
                        )
                        .foregroundStyle(AppTheme.warm.gradient)
                        .cornerRadius(5)
                    }
                    .frame(width: max(CGFloat(analysis.solvedByRating.count) * 62, 320), height: 220)
                }
            }
        }
        .appCard()
    }

    private var pieGrid: some View {
        VStack(spacing: 18) {
            pieCard(
                title: "Verdicts",
                items: analysis.verdicts.map { ($0.verdict.title, max(Double($0.count), 0.01), $0.verdict.tint) },
                details: analysis.verdicts.map { "\($0.count) • \(NumberFormatting.percentage($0.share))" }
            )

            pieCard(
                title: "Weak Tags",
                items: weakTopics.enumerated().map { index, topic in
                    (
                        topic.topic.tag,
                        max(topic.weaknessScore, 0.01),
                        weakPalette[index % weakPalette.count]
                    )
                },
                details: weakTopics.map(\.note)
            )
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Activity", subtitle: "Last 6 months")

            if analysis.monthlyActivity.isEmpty {
                emptyState("No recent activity.")
            } else {
                Chart(analysis.monthlyActivity) { item in
                    BarMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Submissions", item.submissionCount)
                    )
                    .foregroundStyle(AppTheme.accentSecondary.gradient)

                    LineMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Accepted", item.acceptedCount)
                    )
                    .foregroundStyle(AppTheme.success)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .frame(height: 220)
            }
        }
        .appCard()
    }

    private var roundTypeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Round Types", subtitle: "Contest conversion")

            if analysis.roundTypePerformance.isEmpty {
                emptyState("No contest participation data.")
            } else {
                ForEach(analysis.roundTypePerformance) { round in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(round.roundType.rawValue)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)

                            Spacer()

                            Text(NumberFormatting.percentage(round.acceptanceRate))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(round.roundType.tint)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.background)

                                Capsule()
                                    .fill(round.roundType.tint.gradient)
                                    .frame(width: geometry.size.width * max(min(round.acceptanceRate, 1), 0.02))
                            }
                        }
                        .frame(height: 9)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .appCard()
    }

    private func pieCard(
        title: String,
        items: [(title: String, value: Double, tint: Color)],
        details: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, subtitle: "Pie chart")

            if items.isEmpty {
                emptyState("Not enough data.")
            } else {
                Chart(Array(items.enumerated()), id: \.offset) { _, item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(item.tint)
                }
                .frame(height: 240)

                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        ChartLegendRow(
                            title: item.title,
                            detail: details.indices.contains(index) ? details[index] : "",
                            tint: item.tint
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(title)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.background)
        )
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(AppTheme.mutedText)
    }
}
