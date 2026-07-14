import Testing
import Foundation
@testable import CareerPulse

@Suite("Pack draft editing")
struct PackDraftTests {

    private func makeDraft() -> PackDraft {
        PackDraft(file: BuiltinPacks.registeredNurse, origin: "builtin")
    }

    @Test("removing a concept scrubs prerequisites and stages — draft stays valid")
    func removePropagates() throws {
        var draft = makeDraft()
        // "Vital Signs" is a prerequisite of several concepts and sits in stage 3.
        draft.removeConcept(named: "Vital Signs")

        #expect(!draft.file.concepts.contains { $0.name == "Vital Signs" })
        #expect(!draft.file.concepts.contains { $0.prerequisites.contains("Vital Signs") })
        #expect(!draft.file.stages.contains { $0.concepts.contains("Vital Signs") })
        try PackValidator.validate(draft.file)
    }

    @Test("renaming propagates through prerequisites and stages — draft stays valid")
    func renamePropagates() throws {
        var draft = makeDraft()
        draft.renameConcept("Vital Signs", to: "Vitals & Obs")

        #expect(draft.file.concepts.contains { $0.name == "Vitals & Obs" })
        #expect(!draft.file.concepts.contains { $0.name == "Vital Signs" })
        #expect(draft.file.concepts.contains { $0.prerequisites.contains("Vitals & Obs") })
        #expect(draft.file.stages.contains { $0.concepts.contains("Vitals & Obs") })
        try PackValidator.validate(draft.file)
    }

    @Test("rename to an existing name or empty string is a no-op")
    func renameGuards() {
        var draft = makeDraft()
        draft.renameConcept("Vital Signs", to: "Wound Care")   // collision
        #expect(draft.file.concepts.contains { $0.name == "Vital Signs" })
        draft.renameConcept("Vital Signs", to: "   ")          // empty
        #expect(draft.file.concepts.contains { $0.name == "Vital Signs" })
    }

    @Test("clusters group in pack order")
    func clusterGrouping() {
        let draft = makeDraft()
        let clusters = draft.conceptsByCluster.map(\.cluster)
        #expect(clusters == draft.file.clusterOrder.filter { cluster in
            draft.file.concepts.contains { $0.cluster == cluster }
        })
    }
}
