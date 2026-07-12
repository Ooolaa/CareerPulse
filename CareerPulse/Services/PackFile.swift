import Foundation

// MARK: - Portable pack format (JSON) — also the future marketplace format.

struct StageDef: Codable, Hashable {
    var title: String
    var subtitle: String
    var concepts: [String]
}

struct PackFile: Codable {
    struct PackConcept: Codable {
        var name: String
        var cluster: String
        var definition: String
        var prerequisites: [String]
    }
    struct PackSource: Codable {
        var name: String
        var url: String
        var category: String
    }

    var version: Int = 1
    var career: String
    var specialtyCluster: String
    var clusterOrder: [String]
    var concepts: [PackConcept]
    var stages: [StageDef]
    var suggestedSources: [PackSource]
}

// MARK: - Validation (plain code — never trust generated or imported packs)

enum PackValidationError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case noConcepts
    case tooManyConcepts(Int)
    case badClusterCount(Int)
    case emptyDefinition(String)
    case danglingPrerequisite(concept: String, missing: String)
    case tooManyPrerequisites(String)
    case dependencyCycle
    case unknownStageConcept(String)
    case conceptInUnknownCluster(concept: String, cluster: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "Unsupported pack version \(v)."
        case .noConcepts: "The pack has no concepts."
        case .tooManyConcepts(let n): "Too many concepts (\(n) > 120)."
        case .badClusterCount(let n): "Packs need 1–10 clusters (got \(n))."
        case .emptyDefinition(let name): "Concept “\(name)” has no definition."
        case .danglingPrerequisite(let concept, let missing):
            "“\(concept)” requires unknown concept “\(missing)”."
        case .tooManyPrerequisites(let name): "“\(name)” has more than 8 prerequisites."
        case .dependencyCycle: "The prerequisite graph contains a cycle."
        case .unknownStageConcept(let name): "Stage references unknown concept “\(name)”."
        case .conceptInUnknownCluster(let concept, let cluster):
            "“\(concept)” belongs to “\(cluster)”, which is not in clusterOrder."
        }
    }
}

enum PackValidator {
    static func validate(_ pack: PackFile) throws {
        guard pack.version == 1 else { throw PackValidationError.unsupportedVersion(pack.version) }
        guard !pack.concepts.isEmpty else { throw PackValidationError.noConcepts }
        guard pack.concepts.count <= 120 else { throw PackValidationError.tooManyConcepts(pack.concepts.count) }
        guard (1...10).contains(pack.clusterOrder.count) else {
            throw PackValidationError.badClusterCount(pack.clusterOrder.count)
        }

        let names = Set(pack.concepts.map(\.name))
        let clusters = Set(pack.clusterOrder)
        for concept in pack.concepts {
            guard !concept.definition.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw PackValidationError.emptyDefinition(concept.name)
            }
            guard concept.prerequisites.count <= 8 else {
                throw PackValidationError.tooManyPrerequisites(concept.name)
            }
            guard clusters.contains(concept.cluster) else {
                throw PackValidationError.conceptInUnknownCluster(concept: concept.name,
                                                                  cluster: concept.cluster)
            }
            for prerequisite in concept.prerequisites where !names.contains(prerequisite) {
                throw PackValidationError.danglingPrerequisite(concept: concept.name,
                                                               missing: prerequisite)
            }
        }
        for stage in pack.stages {
            for name in stage.concepts where !names.contains(name) {
                throw PackValidationError.unknownStageConcept(name)
            }
        }

        // Kahn's algorithm: the prerequisite graph must be a DAG.
        var incoming = Dictionary(uniqueKeysWithValues: pack.concepts.map { ($0.name, $0.prerequisites.count) })
        var dependents: [String: [String]] = [:]
        for concept in pack.concepts {
            for prerequisite in concept.prerequisites {
                dependents[prerequisite, default: []].append(concept.name)
            }
        }
        var queue = incoming.filter { $0.value == 0 }.map(\.key)
        var visited = 0
        while let name = queue.popLast() {
            visited += 1
            for dependent in dependents[name] ?? [] {
                incoming[dependent]! -= 1
                if incoming[dependent] == 0 { queue.append(dependent) }
            }
        }
        guard visited == pack.concepts.count else { throw PackValidationError.dependencyCycle }
    }

    static func decodeAndValidate(_ data: Data) throws -> PackFile {
        let pack = try JSONDecoder().decode(PackFile.self, from: data)
        try validate(pack)
        return pack
    }
}
