
import SwiftUI

struct TutorialListView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(appData.tutorials) { tutorial in
                        NavigationLink(destination: TutorialDetailView(tutorial: tutorial)) {
                            HStack(spacing: 14) {
                                Image(systemName: "book.pages.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(AppTheme.accent.opacity(0.12))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tutorial.title)
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.text)

                                    Text("Difficulty: \(tutorial.difficulty)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.mutedText)
                                }

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            .appCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Tutorials")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TutorialListView()
            .environmentObject(AppData())
    }
}
