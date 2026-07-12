import Foundation
import SwiftData

/// Skill-tree logic over the ACTIVE pack (runtime data, not hardcoded):
/// what's lit, what's ready to learn next, where the gaps are, and which
/// articles fill them.
@MainActor
enum KnowledgePathEngine {

    /// "Lit" = the user has engaged with it (learning or known).
    static func isLit(_ concept: Concept) -> Bool {
        concept.masteryState != .new
    }

    struct ClusterStats {
        let name: String
        let total: Int
        let lit: Int
        var ratio: Double { total == 0 ? 0 : Double(lit) / Double(total) }
    }

    /// Pack clusters in reading order, then any extra categories (deepened
    /// dots, article extractions).
    static func clusterStats(concepts: [Concept], pack: ActivePack?) -> [ClusterStats] {
        let grouped = Dictionary(grouping: concepts, by: \.category)
        let packNames = pack?.clusterOrder ?? []
        let extraNames = grouped.keys.filter { !packNames.contains($0) }.sorted()
        return (packNames + extraNames).compactMap { name in
            guard let members = grouped[name], !members.isEmpty else { return nil }
            return ClusterStats(name: name, total: members.count,
                                lit: members.filter(isLit).count)
        }
    }

    /// The cluster holding you back: lowest completion among pack clusters.
    static func gapCluster(concepts: [Concept], pack: ActivePack?) -> String? {
        guard let pack else { return nil }
        return clusterStats(concepts: concepts, pack: pack)
            .filter { pack.clusterOrder.contains($0.name) && $0.ratio < 1 }
            .min { $0.ratio < $1.ratio }?.name
    }

    /// Frontier = dim pack concepts whose prerequisites are all lit.
    /// Restricted to pack concepts so stray extractions can't flood
    /// recommendations.
    static func frontier(concepts: [Concept], dependencies: [ConceptDependency],
                         pack: ActivePack?) -> Set<String> {
        guard let pack else { return [] }
        let litNames = Set(concepts.filter(isLit).map(\.name))
        let prereqsByDependent = Dictionary(grouping: dependencies, by: \.dependent)
        var result = Set<String>()
        for concept in concepts where !isLit(concept) && pack.conceptNames.contains(concept.name) {
            let prereqs = prereqsByDependent[concept.name]?.map(\.prerequisite) ?? []
            if prereqs.allSatisfy(litNames.contains) {
                result.insert(concept.name)
            }
        }
        return result
    }

    struct Recommendation {
        let concept: Concept
        let litPrerequisites: [String]
        let articles: [Article]
        let followUpGap: String?
    }

    /// "YOUR NEXT DOT": first frontier concept in learning-path order.
    static func nextDot(concepts: [Concept], dependencies: [ConceptDependency],
                        articles: [Article], pack: ActivePack?) -> Recommendation? {
        guard let pack else { return nil }
        let frontierNames = frontier(concepts: concepts, dependencies: dependencies, pack: pack)
        guard !frontierNames.isEmpty else { return nil }

        let orderedName = pack.pathOrder.first(where: frontierNames.contains)
            ?? frontierNames.sorted().first!
        guard let concept = concepts.first(where: { $0.name == orderedName }) else { return nil }

        let litNames = Set(concepts.filter(isLit).map(\.name))
        let prereqs = dependencies.filter { $0.dependent == concept.name }
            .map(\.prerequisite).filter(litNames.contains)
        let matching = articles.filter { article in
            article.concepts.contains { $0.name == concept.name }
                || article.title.localizedCaseInsensitiveContains(concept.name)
        }
        return Recommendation(concept: concept, litPrerequisites: prereqs,
                              articles: matching.sorted { $0.publishedAt > $1.publishedAt },
                              followUpGap: gapCluster(concepts: concepts, pack: pack))
    }

    /// "Fills your gap: X" tag for an article.
    static func gapTag(for article: Article, frontierNames: Set<String>,
                       gapClusterName: String?) -> String? {
        if let hit = article.concepts.first(where: { frontierNames.contains($0.name) }) {
            return "Fills your gap: \(hit.name)"
        }
        if let gapClusterName,
           let hit = article.concepts.first(where: { $0.category == gapClusterName && $0.masteryState == .new }) {
            return "Fills your gap: \(gapClusterName) → \(hit.name)"
        }
        return nil
    }

    struct StageProgress {
        let title: String
        let subtitle: String
        let total: Int
        let lit: Int
        var isComplete: Bool { lit == total && total > 0 }
    }

    /// Learning path per-stage completion from the pack's stage definitions.
    static func stageProgress(concepts: [Concept], pack: ActivePack?) -> [StageProgress] {
        guard let pack else { return [] }
        let byName = Dictionary(concepts.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        return pack.stages.map { stage in
            let members = stage.concepts.compactMap { byName[$0] }
            return StageProgress(title: stage.title, subtitle: stage.subtitle,
                                 total: stage.concepts.count,
                                 lit: members.filter(isLit).count)
        }
    }

    /// The specialty lane's completion (membership by cluster).
    static func specialtyProgress(concepts: [Concept], pack: ActivePack?) -> (lit: Int, total: Int) {
        guard let pack else { return (0, 0) }
        let members = concepts.filter { $0.category == pack.specialtyCluster }
        return (members.filter(isLit).count, members.count)
    }
}
