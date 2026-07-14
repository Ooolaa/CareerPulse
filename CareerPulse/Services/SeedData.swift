import SwiftData
import Foundation

/// Bootstraps first launch. Until the onboarding wizard (U3) lets users pick
/// or generate their own pack, the AI Engineer starter pack auto-installs so
/// the app is fully usable out of the box.
enum SeedData {
    /// Default AI feed sources — consumed by BuiltinPacks.aiEngineer.
    static let defaultSources: [(name: String, url: String, category: String)] = [
        ("arXiv cs.AI", "https://export.arxiv.org/rss/cs.AI", "Research"),
        ("arXiv cs.LG", "https://export.arxiv.org/rss/cs.LG", "Research"),
        ("arXiv cs.CL", "https://export.arxiv.org/rss/cs.CL", "Research"),
        ("Hugging Face Blog", "https://huggingface.co/blog/feed.xml", "Open Source"),
        ("OpenAI News", "https://openai.com/news/rss.xml", "Frontier Labs"),
        ("Google DeepMind Blog", "https://deepmind.google/blog/rss.xml", "Frontier Labs"),
        ("MIT Technology Review — AI", "https://www.technologyreview.com/topic/artificial-intelligence/feed", "Industry"),
        ("The Verge — AI", "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", "Industry"),
        ("VentureBeat — AI", "https://venturebeat.com/category/ai/feed/", "Industry"),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        // New users choose/build their pack in the onboarding wizard.
        guard UserDefaults.standard.bool(forKey: "hasOnboarded") else { return }
        let active = FetchDescriptor<KnowledgePackRecord>(predicate: #Predicate { $0.isActive })
        let hasPack = ((try? context.fetchCount(active)) ?? 0) > 0
        guard !hasPack else { return }
        try? PackInstaller.install(BuiltinPacks.aiEngineer, source: "builtin", context: context)
    }
}
