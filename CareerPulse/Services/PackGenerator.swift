import Foundation
import FoundationModels

// MARK: - Structured output for the on-device path

@Generable
struct GenClusterPlan {
    @Guide(description: "5 to 7 cluster names for this career, ordered from foundations to advanced")
    var clusters: [String]
    @Guide(description: "One cluster from the list that is the personal specialty lane")
    var specialty: String
}

@Generable
struct GenConcept {
    @Guide(description: "Short canonical concept name")
    var name: String
    @Guide(description: "One-line beginner definition, usable as a quiz question")
    var definition: String
    @Guide(description: "0-3 prerequisite concept names chosen ONLY from concepts listed earlier")
    var prerequisites: [String]
}

@Generable
struct GenClusterConcepts {
    @Guide(description: "5 to 8 concepts for this cluster")
    var concepts: [GenConcept]
}

/// Generates a full career pack from a typed career name.
/// Paths: on-device Foundation Models (staged) → user's own Claude key
/// (single-shot JSON). Output is NEVER trusted: sanitize → validate → and
/// suggested sources are only kept if they actually respond as feeds.
@MainActor
enum PackGenerator {
    enum Availability { case onDevice, byoKey, unavailable }

    static var availability: Availability {
        if IntelligenceService.isModelAvailable { return .onDevice }
        if KeychainStore.hasAnthropicKey { return .byoKey }
        return .unavailable
    }

    enum GenerationError: LocalizedError {
        case unavailable
        case modelFailure(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "Pack generation needs Apple Intelligence or your own Claude API key (Settings → AI engine)."
            case .modelFailure(let detail):
                "Generation didn't produce a usable pack: \(detail)"
            }
        }
    }

    static func generate(career rawCareer: String,
                         progress: @escaping (String) -> Void) async throws -> PackFile {
        let career = String(rawCareer.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        var pack: PackFile
        switch availability {
        case .onDevice:
            pack = try await generateOnDevice(career: career, progress: progress)
        case .byoKey:
            pack = try await generateRemote(career: career, progress: progress)
        case .unavailable:
            throw GenerationError.unavailable
        }

        progress("Checking the map for loose ends…")
        pack = sanitize(pack)
        do {
            try PackValidator.validate(pack)
        } catch {
            throw GenerationError.modelFailure(error.localizedDescription)
        }

        progress("Testing news sources…")
        pack.suggestedSources = await probeSources(pack.suggestedSources)
        return pack
    }

    // MARK: On-device (staged — the small model does better in steps)

    private static func generateOnDevice(career: String,
                                         progress: (String) -> Void) async throws -> PackFile {
        progress("Designing the clusters…")
        let planSession = LanguageModelSession(
            instructions: "You design professional learning curricula as skill trees.")
        guard let planResponse = try? await planSession.respond(
            to: "Career: \(career). Produce the cluster plan.",
            generating: GenClusterPlan.self
        ) else { throw GenerationError.modelFailure("cluster planning failed") }
        let plan = planResponse.content

        var concepts: [PackFile.PackConcept] = []
        var stages: [StageDef] = []
        for (index, cluster) in plan.clusters.enumerated() {
            progress("Naming concepts: \(cluster)…")
            let session = LanguageModelSession(
                instructions: "You list the key concepts of one curriculum cluster with beginner definitions. Prerequisites may only reference the earlier concepts provided.")
            let earlier = concepts.map { $0.name }.joined(separator: ", ")
            guard let response = try? await session.respond(
                to: "Career: \(career)\nCluster: \(cluster)\nEarlier concepts: \(earlier)",
                generating: GenClusterConcepts.self
            ) else { continue }

            let clusterConcepts = response.content.concepts.map {
                PackFile.PackConcept(name: $0.name, cluster: cluster,
                                     definition: $0.definition,
                                     prerequisites: $0.prerequisites)
            }
            concepts.append(contentsOf: clusterConcepts)
            stages.append(StageDef(title: "Stage \(index + 1) · \(cluster)",
                                   subtitle: "",
                                   concepts: clusterConcepts.map(\.name)))
        }

        return PackFile(career: career,
                        specialtyCluster: plan.specialty,
                        clusterOrder: plan.clusters,
                        concepts: concepts,
                        stages: stages,
                        suggestedSources: [])
    }

    // MARK: Remote (user's own key — single shot, higher quality)

    private static let remoteSystemPrompt = """
    You design professional learning curricula as skill trees. Reply with ONLY \
    a JSON object (no markdown fences, no commentary) with this exact shape:
    {"version":1,"career":str,"specialtyCluster":str,"clusterOrder":[str],
     "concepts":[{"name":str,"cluster":str,"definition":str,"prerequisites":[str]}],
     "stages":[{"title":str,"subtitle":str,"concepts":[str]}],
     "suggestedSources":[{"name":str,"url":str,"category":str}]}
    Rules: 5-7 clusters (one is the specialty lane, last in clusterOrder); \
    35-55 concepts total; every cluster in clusterOrder; definitions are \
    one-line and beginner-friendly; prerequisites reference existing concept \
    names only and must form no cycles; 4-6 stages in dependency order; \
    suggestedSources are real, well-known RSS/Atom feed URLs for this field.
    """

    private static func generateRemote(career: String,
                                       progress: (String) -> Void) async throws -> PackFile {
        guard let key = KeychainStore.read() else { throw GenerationError.unavailable }
        progress("Asking Claude to design your map…")
        let text = try await AnthropicClient().complete(
            system: remoteSystemPrompt,
            user: "Career: \(career)",
            apiKey: key
        )
        guard let pack = parseRemoteJSON(text) else {
            throw GenerationError.modelFailure("the response wasn't valid pack JSON")
        }
        return pack
    }

    /// Tolerates ```json fences and stray prose around the object.
    nonisolated static func parseRemoteJSON(_ text: String) -> PackFile? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let json = String(text[start...end])
        return try? JSONDecoder().decode(PackFile.self, from: Data(json.utf8))
    }

    // MARK: Sanitizer — make untrusted output installable (or fail loudly)

    nonisolated static func sanitize(_ input: PackFile) -> PackFile {
        var pack = input
        pack.version = 1
        pack.career = String(pack.career.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))

        // Dedupe concepts by lowercase name; trim fields; cap total.
        var seen = Set<String>()
        var concepts: [PackFile.PackConcept] = []
        for var concept in pack.concepts {
            concept.name = concept.name.trimmingCharacters(in: .whitespacesAndNewlines)
            concept.definition = concept.definition.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = concept.name.lowercased()
            guard !concept.name.isEmpty, !concept.definition.isEmpty,
                  !seen.contains(key), concepts.count < 120 else { continue }
            seen.insert(key)
            concepts.append(concept)
        }

        // Rebuild cluster order from surviving concepts (cap 10; drop extras).
        var clusterOrder = pack.clusterOrder.filter { cluster in
            concepts.contains { $0.cluster == cluster }
        }
        for concept in concepts where !clusterOrder.contains(concept.cluster) {
            clusterOrder.append(concept.cluster)
        }
        if clusterOrder.count > 10 {
            let keep = Set(clusterOrder.prefix(10))
            clusterOrder = Array(clusterOrder.prefix(10))
            concepts.removeAll { !keep.contains($0.cluster) }
        }
        if !clusterOrder.contains(pack.specialtyCluster) {
            pack.specialtyCluster = clusterOrder.last ?? pack.specialtyCluster
        }

        // Scrub prerequisites: unknown names, self-references, cap 8.
        let names = Set(concepts.map(\.name))
        for index in concepts.indices {
            concepts[index].prerequisites = Array(
                concepts[index].prerequisites
                    .filter { names.contains($0) && $0 != concepts[index].name }
                    .prefix(8)
            )
        }

        // Break cycles: run Kahn; any concept left unprocessed loses its
        // prerequisites (a flat concept beats a rejected pack).
        while true {
            var incoming = Dictionary(uniqueKeysWithValues: concepts.map { ($0.name, $0.prerequisites.count) })
            var dependents: [String: [String]] = [:]
            for concept in concepts {
                for prerequisite in concept.prerequisites {
                    dependents[prerequisite, default: []].append(concept.name)
                }
            }
            var queue = incoming.filter { $0.value == 0 }.map(\.key)
            var processed = Set<String>()
            while let name = queue.popLast() {
                processed.insert(name)
                for dependent in dependents[name] ?? [] {
                    incoming[dependent]! -= 1
                    if incoming[dependent] == 0 { queue.append(dependent) }
                }
            }
            guard processed.count < concepts.count,
                  let stuck = concepts.firstIndex(where: { !processed.contains($0.name) })
            else { break }
            concepts[stuck].prerequisites = []
        }

        // Stages: scrub unknown names; synthesize per-cluster stages if empty.
        var stages = pack.stages
        for index in stages.indices {
            stages[index].concepts.removeAll { !names.contains($0) }
        }
        stages.removeAll { $0.concepts.isEmpty }
        if stages.isEmpty {
            stages = clusterOrder.enumerated().map { index, cluster in
                StageDef(title: "Stage \(index + 1) · \(cluster)", subtitle: "",
                         concepts: concepts.filter { $0.cluster == cluster }.map(\.name))
            }
        }

        pack.concepts = concepts
        pack.clusterOrder = clusterOrder
        pack.stages = stages
        return pack
    }

    /// Models hallucinate URLs — only feeds that actually answer survive.
    private static func probeSources(_ candidates: [PackFile.PackSource]) async -> [PackFile.PackSource] {
        await withTaskGroup(of: PackFile.PackSource?.self) { group in
            for candidate in candidates.prefix(10) {
                group.addTask {
                    guard await FeedDiscovery.probe(candidate.url) != nil else { return nil }
                    return candidate
                }
            }
            var working: [PackFile.PackSource] = []
            for await source in group {
                if let source { working.append(source) }
            }
            return Array(working.prefix(8))
        }
    }
}
