import SwiftUI

struct TutorialDetailContainerView: View {
    @EnvironmentObject private var tutorialLibrary: TutorialLibraryStore

    let tutorialID: String

    var body: some View {
        Group {
            if let tutorial = tutorialLibrary.tutorial(withID: tutorialID) {
                TutorialDetailView(tutorial: tutorial)
            } else if tutorialLibrary.isLoading || tutorialLibrary.tutorials.isEmpty {
                ZStack {
                    AppBackdrop()
                    ProgressView()
                        .tint(AppTheme.accent)
                }
            } else {
                ZStack {
                    AppBackdrop()
                    InlineMessageCard(
                        icon: "book.closed",
                        title: "Tutorial not found",
                        detail: "The tutorial catalog may still be syncing. Pull to refresh and try again."
                    )
                    .padding(20)
                }
            }
        }
        .task {
            await tutorialLibrary.loadIfNeeded()
        }
    }
}

struct TutorialDetailView: View {
    let tutorial: AlgorithmTutorial

    @State private var detail: AlgorithmTutorialDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var webDestination: WebDestination?

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    overviewSection
                    sectionNavigator
                    resourcesSection
                }
                .padding(20)
            }
        }
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $webDestination) { destination in
            CodeforcesWebPageView(title: destination.title, url: destination.url)
        }
        .task {
            await loadIfNeeded()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tutorial.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            HStack(spacing: 8) {
                InfoBadge(title: tutorial.category, tint: AppTheme.accentSecondary)
                InfoBadge(title: tutorial.difficulty, tint: AppTheme.warm)

                if let readingMinutes = detail?.readingMinutes {
                    InfoBadge(title: "\(readingMinutes) min read", tint: AppTheme.accent)
                }
            }

            Text(detail?.overviewParagraphs.first ?? tutorial.explanation)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.24))
            }

            HStack(spacing: 10) {
                if let sourceURL = tutorial.sourceURL {
                    PracticeActionButton(
                        title: "Open original article",
                        systemImage: "globe",
                        tint: AppTheme.accent,
                        action: {
                            webDestination = WebDestination(title: tutorial.title, url: sourceURL)
                        }
                    )
                }

                PracticeActionButton(
                    title: isLoading ? "Loading detail" : "Refresh detail",
                    systemImage: "arrow.clockwise",
                    tint: AppTheme.accentSecondary,
                    isBusy: isLoading,
                    action: {
                        Task {
                            await load(forceRefresh: true)
                        }
                    }
                )
            }
        }
        .appCard()
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Overview",
                subtitle: "A cleaner first pass before you dive into the full cp-algorithms article."
            )

            if let detail, !detail.overviewParagraphs.isEmpty {
                ForEach(detail.overviewParagraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }
            } else {
                Text(tutorial.explanation)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)

                Text(tutorial.practiceTip)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .appCard()
    }

    private var sectionNavigator: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Section map",
                subtitle: "Skim the article structure before reading deeply."
            )

            if let detail, !detail.sectionHeadings.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(detail.sectionHeadings, id: \.self) { heading in
                        Text(heading)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.90))
                            )
                    }
                }
            } else {
                Text("Detailed section headings will appear after the article detail finishes loading.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .appCard()
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Related practice",
                subtitle: "Direct links pulled from the tutorial when the source article exposes them."
            )

            if let detail {
                if !detail.practiceLinks.isEmpty {
                    resourceGroup(
                        title: "Practice links",
                        icon: "target",
                        links: detail.practiceLinks
                    )
                }

                if !detail.relatedLinks.isEmpty {
                    resourceGroup(
                        title: "Related topics",
                        icon: "point.3.connected.trianglepath.dotted",
                        links: detail.relatedLinks
                    )
                }

                if detail.practiceLinks.isEmpty && detail.relatedLinks.isEmpty {
                    Text("This article does not expose extra links in a way that can be safely extracted, so use the original article button for the full reference.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }
            } else {
                Text("Practice and related links will appear after the detail fetch completes.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .appCard()
    }

    private func resourceGroup(
        title: String,
        icon: String,
        links: [TutorialResourceLink]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            ForEach(links) { link in
                Button {
                    webDestination = WebDestination(title: link.title, url: link.url)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(AppTheme.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(link.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(link.url.absoluteString)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppTheme.mutedText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.90))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadIfNeeded() async {
        guard detail == nil && !isLoading else { return }
        await load(forceRefresh: false)
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await TutorialCatalogService.shared.loadDetail(for: tutorial, forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        TutorialDetailView(tutorial: .sample)
    }
}
