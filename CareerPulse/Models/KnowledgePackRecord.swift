import SwiftData
import Foundation

/// The installed career pack — the "Lego baseplate" everything builds on.
/// Concepts/dependencies/sources live in their own tables; this record holds
/// the pack's identity and structure (cluster order, learning-path stages).
@Model
final class KnowledgePackRecord {
    var careerName: String
    var specialtyCluster: String
    var clusterOrder: [String]
    var stagesData: Data            // encoded [StageDef]
    var source: String              // "builtin" | "generated" | "imported"
    var conceptNames: [String] = []
    var isActive: Bool
    var createdAt: Date

    init(careerName: String, specialtyCluster: String, clusterOrder: [String],
         stages: [StageDef], source: String) {
        self.careerName = careerName
        self.specialtyCluster = specialtyCluster
        self.clusterOrder = clusterOrder
        self.stagesData = (try? JSONEncoder().encode(stages)) ?? Data()
        self.source = source
        self.isActive = true
        self.createdAt = .now
    }

    var stages: [StageDef] {
        (try? JSONDecoder().decode([StageDef].self, from: stagesData)) ?? []
    }
}
