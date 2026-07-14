import SwiftUI
import SwiftData

struct RootTabView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(Theme.paletteKey) private var paletteName = "Ocean"
    @Query(filter: #Predicate<Article> { !$0.isRead }) private var unreadArticles: [Article]

    var body: some View {
        TabView {
            Tab("Feed", systemImage: "list.bullet") {
                FeedView()
            }
            .badge(unreadArticles.isEmpty ? 0 : unreadArticles.count)
            Tab("Knowledge", systemImage: "point.3.connected.trianglepath.dotted") {
                KnowledgeMapView()
            }
            Tab("Progress", systemImage: "chart.bar.fill") {
                ProgressTabView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(Theme.stateLearning)
        .id(paletteName)     // re-render the tree when the palette changes
        .fullScreenCover(isPresented: .constant(!hasOnboarded)) {
            OnboardingWizard()
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
