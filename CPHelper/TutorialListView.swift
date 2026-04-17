
import SwiftUI

struct TutorialListView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
        List(appData.tutorials) { tutorial in
            NavigationLink(destination: TutorialDetailView(tutorial: tutorial)) {
                HStack(spacing: 14) {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 40, height: 40)
                        .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tutorial.title)
                            .font(.headline)

                        Text("Difficulty: \(tutorial.difficulty)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tutorials")
    }
}

#Preview {
    NavigationStack {
        TutorialListView()
            .environmentObject(AppData())
    }
}
