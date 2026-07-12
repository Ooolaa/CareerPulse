import Testing
import Foundation
import SwiftData
@testable import CareerPulse

@MainActor
@Suite("Knowledge path engine + packs", .serialized)
struct KnowledgePathTests {

    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: FeedSource.self, Article.self, Concept.self,
            LearningEvent.self, ConceptLink.self, ConceptDependency.self, KnowledgePackRecord.self,
            configurations: config
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = Self.sharedContainer.mainContext
        for a in try context.fetch(FetchDescriptor<Article>()) { context.delete(a) }
        for c in try context.fetch(FetchDescriptor<Concept>()) { context.delete(c) }
        for l in try context.fetch(FetchDescriptor<ConceptLink>()) { context.delete(l) }
        for d in try context.fetch(FetchDescriptor<ConceptDependency>()) { context.delete(d) }
        for s in try context.fetch(FetchDescriptor<FeedSource>()) { context.delete(s) }
        for r in try context.fetch(FetchDescriptor<KnowledgePackRecord>()) { context.delete(r) }
        try context.save()
        return context
    }

    /// Runtime pack equivalent of the old static data, for engine tests.
    private var testPack: ActivePack {
        ActivePack(careerName: "AI Engineer",
                   clusterOrder: KnowledgePack.clusterOrder,
                   specialtyCluster: KnowledgePack.specialtyCluster,
                   stages: KnowledgePack.stages.map {
                       StageDef(title: $0.title, subtitle: $0.subtitle, concepts: $0.conceptNames)
                   },
                   conceptNames: Set(KnowledgePack.concepts.map(\.name)))
    }

    private func concept(_ name: String, _ category: String, lit: Bool) -> Concept {
        let c = Concept(name: name, category: category, definition: "d")
        c.masteryLevel = lit ? 0.5 : 0.0
        return c
    }

    // MARK: Engine over a runtime pack

    @Test("frontier: ready only when every prerequisite is lit, pack concepts only")
    func frontier() {
        let linalg = concept("Linear Algebra", "Foundations", lit: true)
        let embeddings = concept("Embeddings", "Foundations", lit: false)
        let attention = concept("Attention", "Foundations", lit: false)
        let tokenization = concept("Tokenization", "Foundations", lit: false)
        let junk = concept("LiNO", "Open Source", lit: false)
        let deps = [ConceptDependency(prerequisite: "Linear Algebra", dependent: "Embeddings"),
                    ConceptDependency(prerequisite: "Embeddings", dependent: "Attention")]
        let frontier = KnowledgePathEngine.frontier(
            concepts: [linalg, embeddings, attention, tokenization, junk],
            dependencies: deps, pack: testPack)
        #expect(frontier == ["Embeddings", "Tokenization"])
    }

    @Test("no active pack → no frontier, no recommendation")
    func noPack() {
        let c = concept("Embeddings", "Foundations", lit: false)
        #expect(KnowledgePathEngine.frontier(concepts: [c], dependencies: [], pack: nil).isEmpty)
        #expect(KnowledgePathEngine.nextDot(concepts: [c], dependencies: [], articles: [], pack: nil) == nil)
    }

    @Test("gap cluster: lowest completion among pack clusters")
    func gap() {
        let concepts = [
            concept("F1", "Foundations", lit: true), concept("F2", "Foundations", lit: true),
            concept("E1", "Evaluation", lit: false), concept("E2", "Evaluation", lit: false),
            concept("L1", "LLM Engineering", lit: true), concept("L2", "LLM Engineering", lit: false),
        ]
        #expect(KnowledgePathEngine.gapCluster(concepts: concepts, pack: testPack) == "Evaluation")
    }

    @Test("next dot follows learning-path order and finds matching articles")
    func nextDot() {
        let embeddings = concept("Embeddings", "Foundations", lit: false)
        let toolUse = concept("Tool Use", "Agents", lit: false)
        let linalg = concept("Linear Algebra", "Foundations", lit: true)
        let deps = [ConceptDependency(prerequisite: "Linear Algebra", dependent: "Embeddings")]
        let article = Article(guid: "a1", title: "Embeddings in practice", content: "",
                              publishedAt: .now, sourceName: "s")
        article.concepts = [embeddings]
        let rec = KnowledgePathEngine.nextDot(concepts: [embeddings, toolUse, linalg],
                                              dependencies: deps, articles: [article], pack: testPack)
        #expect(rec?.concept.name == "Embeddings")
        #expect(rec?.litPrerequisites == ["Linear Algebra"])
        #expect(rec?.articles.count == 1)
    }

    @Test("stage progress: current stage is first incomplete")
    func stages() {
        var concepts: [Concept] = []
        for name in KnowledgePack.stages[0].conceptNames { concepts.append(concept(name, "Foundations", lit: true)) }
        for name in KnowledgePack.stages[1].conceptNames { concepts.append(concept(name, "Foundations", lit: false)) }
        let progress = KnowledgePathEngine.stageProgress(concepts: concepts, pack: testPack)
        #expect(progress[0].isComplete)
        #expect(!progress[1].isComplete)
    }

    // MARK: Pack validation

    private func tinyPack(concepts: [PackFile.PackConcept]) -> PackFile {
        PackFile(career: "T", specialtyCluster: "A", clusterOrder: ["A"],
                 concepts: concepts, stages: [], suggestedSources: [])
    }

    @Test("validator accepts both builtin packs")
    func builtinsValid() throws {
        try PackValidator.validate(BuiltinPacks.aiEngineer)
        try PackValidator.validate(BuiltinPacks.registeredNurse)
    }

    @Test("validator rejects cycles")
    func cycle() {
        let pack = tinyPack(concepts: [
            .init(name: "X", cluster: "A", definition: "d", prerequisites: ["Y"]),
            .init(name: "Y", cluster: "A", definition: "d", prerequisites: ["X"]),
        ])
        #expect(throws: PackValidationError.dependencyCycle) { try PackValidator.validate(pack) }
    }

    @Test("validator rejects dangling prerequisites and empty definitions")
    func dangling() {
        let dangling = tinyPack(concepts: [.init(name: "X", cluster: "A", definition: "d", prerequisites: ["Ghost"])])
        #expect(throws: PackValidationError.danglingPrerequisite(concept: "X", missing: "Ghost")) {
            try PackValidator.validate(dangling)
        }
        let empty = tinyPack(concepts: [.init(name: "X", cluster: "A", definition: "  ", prerequisites: [])])
        #expect(throws: PackValidationError.emptyDefinition("X")) { try PackValidator.validate(empty) }
    }

    @Test("pack JSON round-trips")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(BuiltinPacks.registeredNurse)
        let decoded = try PackValidator.decodeAndValidate(data)
        #expect(decoded.career == "Registered Nurse")
        #expect(decoded.concepts.count == BuiltinPacks.registeredNurse.concepts.count)
    }

    // MARK: Installer

    @Test("install: concepts, deps, sources, active record; mastery survives reinstall")
    func install() throws {
        let context = try makeContext()

        // Pre-existing known concept must keep mastery and join the pack cluster.
        let known = Concept(name: "Fine-Tuning", category: "Old", definition: "old")
        known.isMarkedKnown = true
        known.masteryLevel = 1.0
        context.insert(known)
        try context.save()

        try PackInstaller.install(BuiltinPacks.aiEngineer, source: "builtin", context: context)

        #expect(try context.fetch(FetchDescriptor<Concept>()).count == KnowledgePack.concepts.count)
        #expect(!(try context.fetch(FetchDescriptor<ConceptDependency>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<FeedSource>())).isEmpty)
        #expect(known.masteryLevel == 1.0)
        #expect(known.category == "Foundations")

        let pack = ActivePack.load(context: context)
        #expect(pack?.careerName == "AI Engineer")
        #expect(pack?.conceptNames.count == KnowledgePack.concepts.count)

        // Installing the nurse pack: previous record deactivates, mastery kept.
        try PackInstaller.install(BuiltinPacks.registeredNurse, source: "builtin", context: context)
        let records = try context.fetch(FetchDescriptor<KnowledgePackRecord>())
        #expect(records.count { $0.isActive } == 1)
        #expect(ActivePack.load(context: context)?.careerName == "Registered Nurse")
        #expect(known.masteryLevel == 1.0)
    }

    @Test("export mirrors the installed pack")
    func exportPack() throws {
        let context = try makeContext()
        try PackInstaller.install(BuiltinPacks.registeredNurse, source: "builtin", context: context)
        let exported = PackInstaller.exportActivePack(context: context)
        #expect(exported?.career == "Registered Nurse")
        #expect(exported?.concepts.count == BuiltinPacks.registeredNurse.concepts.count)
        try PackValidator.validate(exported!)
    }
}
