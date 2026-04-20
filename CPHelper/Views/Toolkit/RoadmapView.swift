import SwiftUI

struct RoadmapView: View {
    private let targets = [1000, 1200, 1400, 1600, 1800, 2000, 2200]
    @State private var targetRating = 1400

    private var targetStage: RoadmapStage {
        RoadmapStage.stage(for: targetRating)
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Target Rating", subtitle: "Static roadmap")
                        CapsuleChoiceRow(values: targets, title: { "\($0)" }, selection: $targetRating)
                    }
                    .appCard()

                    focusedRoadmapCard

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "All Stages", subtitle: "Progression map")

                        ForEach(RoadmapStage.all) { stage in
                            stageRow(stage)
                        }
                    }
                    .appCard()
                }
                .padding(20)
            }
        }
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var focusedRoadmapCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(targetStage.title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            HStack(spacing: 8) {
                InfoBadge(title: "Target \(targetRating)", tint: AppTheme.accent)
                InfoBadge(title: targetStage.practiceRangeLabel, tint: AppTheme.warm)
                InfoBadge(title: targetStage.nextRangeLabel, tint: AppTheme.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Topics")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(targetStage.topicsToLearn, id: \.self) { topic in
                            Text(topic)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.accentSecondary.opacity(0.12))
                                )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Focus")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                ForEach(targetStage.focusPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        Text(point)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
            }
        }
        .appCard()
    }

    private func stageRow(_ stage: RoadmapStage) -> some View {
        let isSelected = stage.id == targetStage.id

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                Text("\(stage.ratingRange.lowerBound)-\(stage.ratingRange.upperBound)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            if isSelected {
                InfoBadge(title: "Selected", tint: AppTheme.accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.background : Color.white.opacity(0.84))
        )
    }
}

#Preview {
    NavigationStack {
        RoadmapView()
    }
}
