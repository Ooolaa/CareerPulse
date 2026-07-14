import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// First-run wizard — the "Lego baseplate" flow:
/// 1 Career (starter pack or import) → 2 Review (edit the map) →
/// 3 Style (palette) → 4 Sources → install → 5 Mark what you know.
struct OnboardingWizard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(Theme.paletteKey) private var paletteName = "Ocean"

    @State private var step = 1
    @State private var draft: PackDraft?
    @State private var careerText = ""
    @State private var showImporter = false
    @State private var importError: String?
    @State private var installError: String?
    @State private var probing = false
    @State private var probeInput = ""
    @State private var probeFailed = false
    @State private var renameTarget: String?
    @State private var generating = false
    @State private var genStatus = ""
    @State private var keyInput = ""
    @State private var keySaved = KeychainStore.hasAnthropicKey
    @State private var renameText = ""

    private let totalSteps = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(1...totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.stateLearning : Theme.cardBorder)
                        .frame(height: 4)
                }
            }
            .padding(.top, 14)
            .animation(.easeOut(duration: 0.2), value: step)

            Group {
                switch step {
                case 1: careerStep
                case 2: reviewStep
                case 3: styleStep
                case 4: sourcesStep
                default: knowStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            continueButton
            Text("Everything is analyzed on your device — nothing leaves it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.background)
        .id(paletteName)     // live re-theme while previewing styles
        .alert("Rename concept", isPresented: .init(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let target = renameTarget { draft?.renameConcept(target, to: renameText) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert("Pack problem", isPresented: .init(
            get: { installError != nil }, set: { if !$0 { installError = nil } }
        )) {
            Button("OK", role: .cancel) { installError = nil }
        } message: {
            Text(installError ?? "")
        }
    }

    // MARK: Step 1 — career

    private var careerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stepTitle("What do you want to master?",
                          subtitle: "Pick a starter pack, or import one built with any AI using the CareerPulse template.")

                ForEach(BuiltinPacks.all, id: \.career) { pack in
                    starterCard(pack)
                        .padding(.top, 10)
                }

                Button { showImporter = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import a pack (.json)")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.stateLearning)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Theme.learningTint, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                    importPack(result)
                }
                if let importError {
                    Text(importError)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xD9534F))
                        .padding(.top, 6)
                }

                TextField("Or type any career…", text: $careerText)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .padding(.top, 14)
                if !careerText.trimmingCharacters(in: .whitespaces).isEmpty {
                    generationHint
                        .padding(.top, 8)
                }
            }
        }
    }

    private func starterCard(_ pack: PackFile) -> some View {
        let isSelected = draft?.file.career == pack.career && draft?.origin == "builtin"
        return Button {
            draft = PackDraft(file: pack, origin: "builtin")
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.career)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(pack.concepts.count) concepts · \(pack.clusterOrder.count) clusters · \(pack.suggestedSources.count) sources")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.stateLearning : Theme.cardBorder)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Theme.stateLearning : Theme.cardBorder,
                              lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("starterPack")
    }

    private func importPack(_ result: Result<URL, Error>) {
        importError = nil
        guard case .success(let url) = result else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let pack = try PackValidator.decodeAndValidate(try Data(contentsOf: url))
            draft = PackDraft(file: pack, origin: "imported")
        } catch {
            importError = "Couldn't import: \(error.localizedDescription)"
        }
    }

    /// Availability + inline key entry for typed-career generation.
    private var generationHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch PackGenerator.availability {
            case .onDevice:
                Label("Will generate “\(typedCareer)” on-device — private, free.",
                      systemImage: "sparkles")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.stateLearning)
            case .byoKey:
                Label("Will generate “\(typedCareer)” with your Claude API key.",
                      systemImage: "sparkles")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.stateLearning)
            case .unavailable:
                Text("Generating “\(typedCareer)” needs Apple Intelligence — or paste your own Claude API key (stored only in your iPhone's Keychain):")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    SecureField("sk-ant-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    Button("Save") {
                        if KeychainStore.save(keyInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            keySaved = true
                            keyInput = ""
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.stateLearning)
                    .disabled(keyInput.isEmpty)
                }
            }
        }
    }

    // MARK: Step 2 — review (edit the map before it exists)

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Your map, your blocks",
                      subtitle: "Swipe to remove concepts you don't want; tap to rename. Everything stays editable later.")
            if draft?.origin == "generated" {
                Text("AI-generated — review names and definitions. For regulated fields this is educational scaffolding, not professional advice.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
            }
            List {
                ForEach(draft?.conceptsByCluster ?? [], id: \.cluster) { group in
                    Section {
                        ForEach(group.concepts, id: \.name) { concept in
                            Button {
                                renameTarget = concept.name
                                renameText = concept.name
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(concept.name)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(concept.definition)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                draft?.removeConcept(named: group.concepts[offset].name)
                            }
                        }
                    } header: {
                        SettingsHeader(group.cluster)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: Step 3 — style

    private var styleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stepTitle("Pick your style",
                          subtitle: "The whole app re-colors live. Change it anytime in Settings.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(Palette.all) { palette in
                        paletteCard(palette)
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func paletteCard(_ palette: Palette) -> some View {
        let isSelected = paletteName == palette.name
        return Button { paletteName = palette.name } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.stateNew).frame(width: 12, height: 12)
                    Circle().fill(palette.accent).frame(width: 16, height: 16)
                    Circle().fill(Theme.stateKnown).frame(width: 12, height: 12)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.accent)
                    }
                }
                Capsule().fill(palette.accent).frame(height: 6)
                Text(palette.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? palette.accent : Theme.cardBorder,
                              lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 4 — sources

    private var sourcesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stepTitle("Where should knowledge come from?",
                          subtitle: "Suggested for \(draft?.file.career ?? "your career") — toggle any off, or paste a site/feed URL to add your own.")

                VStack(spacing: 0) {
                    ForEach((draft?.file.suggestedSources ?? []).indices, id: \.self) { index in
                        if index > 0 { Divider().padding(.leading, 15) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft?.file.suggestedSources[index].name ?? "")
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(draft?.file.suggestedSources[index].category ?? "")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            Button {
                                draft?.file.suggestedSources.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.stateNew)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder, lineWidth: 1))
                .padding(.top, 12)

                HStack(spacing: 8) {
                    TextField("Paste a site or feed URL…", text: $probeInput)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    Button {
                        Task {
                            probing = true
                            probeFailed = false
                            if let source = await FeedDiscovery.probe(probeInput) {
                                draft?.file.suggestedSources.append(source)
                                probeInput = ""
                            } else {
                                probeFailed = true
                            }
                            probing = false
                        }
                    } label: {
                        if probing {
                            ProgressView().controlSize(.small).frame(width: 52)
                        } else {
                            Text("Add")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 42)
                                .background(Theme.stateLearning, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(probing || probeInput.isEmpty)
                }
                .padding(.top, 12)
                if probeFailed {
                    Text("Couldn't find a feed there — try the site's RSS URL directly.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xD9534F))
                        .padding(.top, 6)
                }
            }
        }
    }

    // MARK: Step 5 — mark what you know (runs after install)

    private var knowStep: some View {
        KnowSelectionStep()
    }

    // MARK: Continue

    private var typedCareer: String {
        careerText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var willGenerate: Bool {
        draft == nil && !typedCareer.isEmpty && PackGenerator.availability != .unavailable
    }

    private var continueEnabled: Bool {
        switch step {
        case 1: return (draft != nil || willGenerate) && !generating
        case 2: return (draft?.file.concepts.count ?? 0) > 0
        default: return true
        }
    }

    private var continueButton: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 8) {
                if generating { ProgressView().tint(.white).controlSize(.small) }
                Text(generating ? genStatus
                     : step == 1 && willGenerate ? "Generate my map"
                     : step == 4 ? "Build my app"
                     : step == totalSteps ? "Start learning" : "Continue")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(continueEnabled ? Theme.stateLearning : Theme.stateNew,
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!continueEnabled)
        .accessibilityIdentifier("wizardContinue")
        .padding(.top, 12)
    }

    private func advance() {
        if step == 1, willGenerate {
            generating = true
            genStatus = "Designing your map…"
            Task {
                do {
                    let pack = try await PackGenerator.generate(career: typedCareer) { status in
                        Task { @MainActor in genStatus = status }
                    }
                    draft = PackDraft(file: pack, origin: "generated")
                    step = 2
                } catch {
                    installError = error.localizedDescription
                }
                generating = false
            }
            return
        }
        if step == 4 {
            guard let draft else { return }
            do {
                try PackInstaller.install(draft.file, source: draft.origin, context: modelContext)
            } catch {
                installError = error.localizedDescription
                return
            }
        }
        if step == totalSteps {
            hasOnboarded = true
        } else {
            step += 1
        }
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(.top, 22)
    }
}

/// Step 5 — chips per cluster; tapping marks a concept known (green day one).
private struct KnowSelectionStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var concepts: [Concept]
    @Query private var packRecords: [KnowledgePackRecord]

    private var activePack: ActivePack? {
        packRecords.first(where: \.isActive).map(ActivePack.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mark what you already know")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 22)
                Text("Green dots from day one — nobody starts at zero. Tap everything you could explain to a colleague.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)

                ForEach(activePack?.clusterOrder ?? [], id: \.self) { cluster in
                    let members = concepts.filter { $0.category == cluster }
                    if !members.isEmpty {
                        Text(cluster)
                            .font(.system(size: 12, weight: .bold))
                            .kerning(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 14)
                        FlowLayout(spacing: 8) {
                            ForEach(members) { concept in
                                knowChip(concept)
                            }
                        }
                    }
                }
            }
        }
    }

    private func knowChip(_ concept: Concept) -> some View {
        let known = concept.isMarkedKnown
        return Button {
            if known {
                concept.isMarkedKnown = false
                concept.masteryLevel = 0.0
            } else {
                KnowledgeEngine.markKnown(concept, context: modelContext)
            }
        } label: {
            Text(known ? "✓ \(concept.name)" : concept.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(known ? .white : Color(hex: 0x4B5563))
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(known ? Theme.stateKnown : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(known ? .clear : Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingWizard()
        .modelContainer(PreviewData.container)
}
