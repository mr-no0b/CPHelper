import SwiftUI

struct RoadmapView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = RoadmapViewModel()
    @State private var selectedHandle = ""

    private var handles: [TrackedHandle] {
        sessionStore.currentUser?.handles ?? []
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HandlePickerCard(
                        title: "Roadmap",
                        subtitle: "Each stage tells you what to learn, what difficulty to drill, and what the next rating jump should look like.",
                        handles: handles,
                        selectedHandle: $selectedHandle
                    )

                    if handles.isEmpty {
                        InlineMessageCard(
                            icon: "map.fill",
                            title: "Add a handle first",
                            detail: "The roadmap highlights the stage that matches a real Codeforces rating, so it needs one attached handle."
                        )
                    } else {
                        headlineCard

                        ForEach(RoadmapStage.all) { stage in
                            roadmapStageCard(stage)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncSelectedHandle()
        }
        .task(id: selectedHandle) {
            guard !selectedHandle.isEmpty else { return }
            await viewModel.load(for: selectedHandle)
        }
    }

    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Current track",
                subtitle: "The highlighted stage is based on the selected handle's current rating, not just its peak."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricChip(
                    title: "Handle",
                    value: selectedHandle.isEmpty ? "None" : "@\(selectedHandle)"
                )
                MetricChip(
                    title: "Current rating",
                    value: viewModel.analysis?.summary.currentRating.map(String.init) ?? "Unrated"
                )
                MetricChip(title: "Stage", value: viewModel.highlightedStage.title)
                MetricChip(title: "Next target", value: viewModel.highlightedStage.nextRangeLabel)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color(red: 0.78, green: 0.23, blue: 0.24))
            } else {
                Text("Recommended practice range: \(viewModel.highlightedStage.practiceRangeLabel)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .appCard()
    }

    private func roadmapStageCard(_ stage: RoadmapStage) -> some View {
        let isHighlighted = stage.id == viewModel.highlightedStage.id

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(stage.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text("Rating band \(stage.ratingRange.lowerBound)-\(stage.ratingRange.upperBound)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }

                Spacer()

                if isHighlighted {
                    InfoBadge(title: "Current stage", tint: AppTheme.accent)
                }
            }

            HStack(spacing: 10) {
                InfoBadge(title: stage.nextRangeLabel, tint: AppTheme.accentSecondary)
                InfoBadge(title: stage.practiceRangeLabel, tint: AppTheme.warm)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Topics to learn")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stage.topicsToLearn, id: \.self) { topic in
                            Text(topic)
                                .font(.system(.caption, design: .rounded).weight(.medium))
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
                Text("What to do next")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                ForEach(stage.focusPoints, id: \.self) { focusPoint in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(isHighlighted ? AppTheme.accent : AppTheme.cardBorder)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        Text(focusPoint)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(isHighlighted ? AppTheme.card : Color.white.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(isHighlighted ? AppTheme.accent.opacity(0.35) : AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isHighlighted ? 0.08 : 0.04), radius: 18, x: 0, y: 10)
        )
    }

    private func syncSelectedHandle() {
        if selectedHandle.isEmpty {
            selectedHandle = sessionStore.currentUser?.primaryHandle ?? handles.first?.handle ?? ""
            return
        }

        if !handles.contains(where: { $0.handle == selectedHandle }) {
            selectedHandle = sessionStore.currentUser?.primaryHandle ?? handles.first?.handle ?? ""
        }
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        handles: [
            TrackedHandle(handle: "tourist", label: "Main", isPrimary: true)
        ]
    ))

    return NavigationStack {
        RoadmapView()
            .environmentObject(session)
    }
}
