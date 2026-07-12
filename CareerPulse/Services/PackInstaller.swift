import Foundation
import SwiftData

/// Runtime view of the active pack — what the engines read instead of
/// hardcoded arrays.
struct ActivePack {
    let careerName: String
    let clusterOrder: [String]
    let specialtyCluster: String
    let stages: [StageDef]
    let conceptNames: Set<String>

    init(careerName: String, clusterOrder: [String], specialtyCluster: String,
         stages: [StageDef], conceptNames: Set<String>) {
        self.careerName = careerName
        self.clusterOrder = clusterOrder
        self.specialtyCluster = specialtyCluster
        self.stages = stages
        self.conceptNames = conceptNames
    }

    init(record: KnowledgePackRecord) {
        careerName = record.careerName
        clusterOrder = record.clusterOrder
        specialtyCluster = record.specialtyCluster
        stages = record.stages
        conceptNames = Set(record.conceptNames)
    }

    /// Learning-path order: stage concepts first, then specialty extras.
    var pathOrder: [String] { stages.flatMap(\.concepts) }

    @MainActor
    static func load(context: ModelContext) -> ActivePack? {
        let descriptor = FetchDescriptor<KnowledgePackRecord>(predicate: #Predicate { $0.isActive })
        return (try? context.fetch(descriptor))?.first.map(ActivePack.init)
    }
}

/// Installs a validated PackFile into SwiftData; exports the live state back
/// to a PackFile for sharing.
@MainActor
enum PackInstaller {
    @discardableResult
    static func install(_ pack: PackFile, source: String, context: ModelContext) throws -> KnowledgePackRecord {
        try PackValidator.validate(pack)

        // Retire any previous pack (concepts/mastery are kept — knowledge is yours).
        for record in (try? context.fetch(FetchDescriptor<KnowledgePackRecord>())) ?? [] {
            record.isActive = false
        }

        let existing = (try? context.fetch(FetchDescriptor<Concept>())) ?? []
        var byLowerName = Dictionary(existing.map { ($0.name.lowercased(), $0) },
                                     uniquingKeysWith: { first, _ in first })
        var conceptsByName: [String: Concept] = [:]
        for packConcept in pack.concepts {
            let concept: Concept
            if let found = byLowerName[packConcept.name.lowercased()] {
                concept = found                       // keep mastery, adopt cluster
                concept.category = packConcept.cluster
                if concept.conceptDefinition.isEmpty {
                    concept.conceptDefinition = packConcept.definition
                }
            } else {
                concept = Concept(name: packConcept.name, category: packConcept.cluster,
                                  definition: packConcept.definition)
                concept.masteryLevel = 0.0            // dim until the user lights it
                context.insert(concept)
                byLowerName[packConcept.name.lowercased()] = concept
            }
            conceptsByName[packConcept.name] = concept
        }

        let existingDeps = (try? context.fetch(FetchDescriptor<ConceptDependency>())) ?? []
        var depKeys = Set(existingDeps.map { "\($0.prerequisite)→\($0.dependent)" })
        for packConcept in pack.concepts {
            for prerequisite in packConcept.prerequisites {
                let key = "\(prerequisite)→\(packConcept.name)"
                guard !depKeys.contains(key) else { continue }
                context.insert(ConceptDependency(prerequisite: prerequisite,
                                                 dependent: packConcept.name))
                depKeys.insert(key)
                if let a = conceptsByName[prerequisite], let b = conceptsByName[packConcept.name] {
                    KnowledgeEngine.linkCooccurring([a, b], context: context)
                }
            }
        }

        let existingURLs = Set(((try? context.fetch(FetchDescriptor<FeedSource>())) ?? [])
            .map { $0.url.absoluteString })
        for packSource in pack.suggestedSources {
            guard let url = URL(string: packSource.url),
                  !existingURLs.contains(packSource.url) else { continue }
            context.insert(FeedSource(name: packSource.name, url: url,
                                      category: packSource.category))
        }

        let record = KnowledgePackRecord(careerName: pack.career,
                                         specialtyCluster: pack.specialtyCluster,
                                         clusterOrder: pack.clusterOrder,
                                         stages: pack.stages,
                                         source: source)
        record.conceptNames = pack.concepts.map(\.name)
        context.insert(record)
        try context.save()
        return record
    }

    /// Snapshot the active pack (with any deepened/extracted structure left
    /// out — export is the curated pack, portable to another phone).
    static func exportActivePack(context: ModelContext) -> PackFile? {
        guard let record = (try? context.fetch(
            FetchDescriptor<KnowledgePackRecord>(predicate: #Predicate { $0.isActive })
        ))?.first else { return nil }

        let names = Set(record.conceptNames)
        let concepts = ((try? context.fetch(FetchDescriptor<Concept>())) ?? [])
            .filter { names.contains($0.name) }
        let deps = ((try? context.fetch(FetchDescriptor<ConceptDependency>())) ?? [])
            .filter { names.contains($0.dependent) && names.contains($0.prerequisite) }
        let prereqsByDependent = Dictionary(grouping: deps, by: \.dependent)
        let sources = (try? context.fetch(FetchDescriptor<FeedSource>())) ?? []

        return PackFile(
            career: record.careerName,
            specialtyCluster: record.specialtyCluster,
            clusterOrder: record.clusterOrder,
            concepts: concepts.map { concept in
                .init(name: concept.name, cluster: concept.category,
                      definition: concept.conceptDefinition,
                      prerequisites: prereqsByDependent[concept.name]?.map(\.prerequisite) ?? [])
            },
            stages: record.stages,
            suggestedSources: sources.map {
                .init(name: $0.name, url: $0.url.absoluteString, category: $0.category)
            }
        )
    }
}
