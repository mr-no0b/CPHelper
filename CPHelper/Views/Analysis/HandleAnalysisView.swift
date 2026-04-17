import Charts
import SwiftUI

struct HandleAnalysisView: View {
    @StateObject private var viewModel: HandleAnalysisViewModel

    init(handle: String) {
        _viewModel = StateObject(wrappedValue: HandleAnalysisViewModel(handle: handle))
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            Group {
                if let analysis = viewModel.analysis {
                    analysisContent(analysis)
                } else if viewModel.isLoading {
                    loadingState
                } else if let errorMessage = viewModel.errorMessage {
                    errorState(message: errorMessage)
                } else {
                    loadingState
                }
            }
        }
        .navigationTitle(viewModel.handle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.analysis == nil && !viewModel.isLoading {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load(forceRefresh: true)
        }
    }

    private func analysisContent(_ analysis: HandleAnalysis) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                summaryHero(analysis.summary, handle: analysis.handle)
                verdictCard(analysis)
                solvedByRatingCard(analysis)
                acceptanceRateCard(analysis)
                roundTypeCard(analysis)
                insightsCard(title: "Strong areas", subtitle: "Signals where this handle already converts well.", insights: analysis.strengths)
                insightsCard(title: "Weak areas", subtitle: "The sharpest places to invest focused practice.", insights: analysis.weaknesses)
                topicCard(analysis)
                activityCard(analysis)
            }
            .padding(20)
        }
    }

    private func summaryHero(_ summary: HandleAnalysisSummary, handle: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                AsyncImage(url: summary.avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle().fill(AppTheme.heroGradient)
                        Text(String(handle.prefix(1)).uppercased())
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 74, height: 74)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.displayName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text("@\(handle)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    HStack(spacing: 8) {
                        if let rankTitle = summary.rankTitle {
                            InfoBadge(title: rankTitle.capitalized, tint: AppTheme.accent)
                        }

                        if let lastActive = summary.lastActiveDate {
                            InfoBadge(title: "Active \(DateFormatting.mediumDate.string(from: lastActive))", tint: AppTheme.accentSecondary)
                        }
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricChip(title: "Current rating", value: summary.currentRating.map(String.init) ?? "Unrated")
                MetricChip(title: "Max rating", value: summary.maxRating.map(String.init) ?? "Unrated")
                MetricChip(title: "Solved", value: NumberFormatting.compact(summary.solvedCount))
                MetricChip(title: "Acceptance", value: NumberFormatting.percentage(summary.overallAcceptanceRate))
                MetricChip(title: "Submissions", value: NumberFormatting.compact(summary.totalSubmissions))
                MetricChip(title: "Contests", value: NumberFormatting.compact(summary.contestsParticipated))
            }

            if let highestSolvedRating = summary.highestSolvedRating ?? summary.maxRating,
               let productiveTag = summary.mostProductiveTag {
                Text("Highest solved rating \(highestSolvedRating) with strong activity around \(productiveTag).")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .appCard()
    }

    private func verdictCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Verdict breakdown",
                subtitle: "Submission outcomes across all public submissions on this handle."
            )

            if analysis.verdicts.isEmpty {
                emptyStateText("No verdict data available.")
            } else {
                Chart(analysis.verdicts) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.verdict.tint)
                }
                .frame(height: 260)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(analysis.verdicts) { slice in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(slice.verdict.tint)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(slice.verdict.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)

                                Text("\(slice.count) submissions • \(NumberFormatting.percentage(slice.share))")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(AppTheme.mutedText)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private func solvedByRatingCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Solved by rating",
                subtitle: "Unique accepted problems grouped by problem rating."
            )

            if analysis.solvedByRating.isEmpty {
                emptyStateText("No rated solved problems were found.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(analysis.solvedByRating) { item in
                        BarMark(
                            x: .value("Rating", item.label),
                            y: .value("Solved", item.solvedCount)
                        )
                        .foregroundStyle(AppTheme.accent.gradient)
                        .cornerRadius(6)
                    }
                    .frame(width: max(CGFloat(analysis.solvedByRating.count) * 64, 320), height: 240)
                }
            }
        }
        .appCard()
    }

    private func acceptanceRateCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "AC percentage by rating",
                subtitle: "Where conversion is efficient and where it drops."
            )

            if analysis.acceptanceByRating.isEmpty {
                emptyStateText("No rating-wise acceptance data available.")
            } else {
                ForEach(analysis.acceptanceByRating) { item in
                    PerformanceRow(
                        title: item.label,
                        subtitle: "\(item.acceptedCount) accepted out of \(item.submissionCount) submissions",
                        progress: item.acceptanceRate,
                        tint: AppTheme.accent
                    )
                }
            }
        }
        .appCard()
    }

    private func roundTypeCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Round-type performance",
                subtitle: "Acceptance trends across Div 1, Div 2, Div 1 + 2, Educational, and others."
            )

            if analysis.roundTypePerformance.isEmpty {
                emptyStateText("No contest-participation submissions were found for this handle.")
            } else {
                ForEach(analysis.roundTypePerformance) { round in
                    PerformanceRow(
                        title: round.roundType.rawValue,
                        subtitle: "\(round.acceptedCount) accepted from \(round.submissionCount) submissions in \(round.contestCount) contests",
                        progress: round.acceptanceRate,
                        tint: round.roundType.tint
                    )
                }
            }
        }
        .appCard()
    }

    private func insightsCard(title: String, subtitle: String, insights: [AnalysisInsight]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: title, subtitle: subtitle)

            ForEach(insights) { insight in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(insight.tone.tint)
                            .frame(width: 10, height: 10)

                        Text(insight.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)
                    }

                    Text(insight.detail)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(insight.tone.tint.opacity(0.08))
                )
            }
        }
        .appCard()
    }

    private func topicCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Topic pulse",
                subtitle: "A tag-level view of solved counts, attempts, and conversion."
            )

            if analysis.topicPerformance.isEmpty {
                emptyStateText("No tag data available.")
            } else {
                ForEach(Array(analysis.topicPerformance.prefix(6))) { topic in
                    PerformanceRow(
                        title: topic.tag,
                        subtitle: "\(topic.solvedCount) solved • \(topic.acceptedCount) accepted • \(topic.attemptedCount) attempts",
                        progress: topic.acceptanceRate,
                        tint: AppTheme.accentSecondary
                    )
                }
            }
        }
        .appCard()
    }

    private func activityCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Recent activity",
                subtitle: "Submission volume over the latest six months."
            )

            if analysis.monthlyActivity.isEmpty {
                emptyStateText("Recent activity data is unavailable.")
            } else {
                Chart(analysis.monthlyActivity) { item in
                    BarMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Submissions", item.submissionCount)
                    )
                    .foregroundStyle(AppTheme.warm.gradient)

                    LineMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Accepted", item.acceptedCount)
                    )
                    .foregroundStyle(AppTheme.success)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Accepted", item.acceptedCount)
                    )
                    .foregroundStyle(AppTheme.success)
                }
                .frame(height: 220)
            }
        }
        .appCard()
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.accent)

            Text("Loading live Codeforces analysis...")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)

            Button("Try again") {
                Task {
                    await viewModel.load(forceRefresh: true)
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .frame(maxWidth: 260)
        }
        .padding(24)
    }

    private func emptyStateText(_ message: String) -> some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(AppTheme.mutedText)
    }
}

private struct PerformanceRow: View {
    let title: String
    let subtitle: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Text(NumberFormatting.percentage(progress))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(tint)
            }

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.background)

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: geometry.size.width * max(min(progress, 1), 0.02))
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        HandleAnalysisView(handle: "tourist")
    }
}
