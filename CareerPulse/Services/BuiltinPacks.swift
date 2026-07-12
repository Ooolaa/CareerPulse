import Foundation

/// Starter packs bundled with the app: instant demo content, and the fallback
/// for phones without Apple Intelligence. Same PackFile format as imports.
enum BuiltinPacks {
    static var all: [PackFile] { [aiEngineer, registeredNurse] }

    /// The proven TechPulse pack, rebuilt from `KnowledgePack`'s static data.
    static var aiEngineer: PackFile {
        PackFile(
            career: "AI Engineer",
            specialtyCluster: KnowledgePack.specialtyCluster,
            clusterOrder: KnowledgePack.clusterOrder,
            concepts: KnowledgePack.concepts.map {
                .init(name: $0.name, cluster: $0.cluster,
                      definition: $0.definition, prerequisites: $0.prerequisites)
            },
            stages: KnowledgePack.stages.map {
                StageDef(title: $0.title, subtitle: $0.subtitle, concepts: $0.conceptNames)
            },
            suggestedSources: SeedData.defaultSources.map {
                .init(name: $0.name, url: $0.url, category: $0.category)
            }
        )
    }

    /// A non-tech pack proving the formula generalizes.
    static var registeredNurse: PackFile {
        PackFile(
            career: "Registered Nurse",
            specialtyCluster: "Your Unit",
            clusterOrder: ["Anatomy & Physiology", "Pharmacology", "Clinical Skills",
                           "Patient Assessment", "Ethics & Law", "Your Unit"],
            concepts: [
                .init(name: "Cardiovascular System", cluster: "Anatomy & Physiology",
                      definition: "The heart and blood vessels: how blood moves oxygen through the body.", prerequisites: []),
                .init(name: "Respiratory System", cluster: "Anatomy & Physiology",
                      definition: "Lungs and airways: gas exchange and oxygenation.", prerequisites: []),
                .init(name: "Renal System", cluster: "Anatomy & Physiology",
                      definition: "Kidneys: fluid balance, electrolytes and waste filtration.", prerequisites: []),
                .init(name: "Fluid & Electrolytes", cluster: "Anatomy & Physiology",
                      definition: "Sodium, potassium and water balance — the basis of many acute problems.",
                      prerequisites: ["Renal System"]),
                .init(name: "Pharmacokinetics", cluster: "Pharmacology",
                      definition: "How the body absorbs, distributes, metabolizes and excretes drugs.", prerequisites: []),
                .init(name: "Beta-Blockers", cluster: "Pharmacology",
                      definition: "Drugs that slow heart rate and lower blood pressure.",
                      prerequisites: ["Cardiovascular System", "Pharmacokinetics"]),
                .init(name: "Anticoagulants", cluster: "Pharmacology",
                      definition: "Blood thinners: preventing clots while managing bleeding risk.",
                      prerequisites: ["Cardiovascular System", "Pharmacokinetics"]),
                .init(name: "Antibiotic Stewardship", cluster: "Pharmacology",
                      definition: "Choosing and limiting antibiotics to fight resistance.",
                      prerequisites: ["Pharmacokinetics"]),
                .init(name: "Insulin Management", cluster: "Pharmacology",
                      definition: "Types, timing and titration of insulin in diabetes care.",
                      prerequisites: ["Pharmacokinetics"]),
                .init(name: "Medication Administration", cluster: "Clinical Skills",
                      definition: "The five rights: patient, drug, dose, route, time.",
                      prerequisites: ["Pharmacokinetics"]),
                .init(name: "IV Therapy", cluster: "Clinical Skills",
                      definition: "Starting and maintaining intravenous lines and infusions.",
                      prerequisites: ["Fluid & Electrolytes", "Medication Administration"]),
                .init(name: "Wound Care", cluster: "Clinical Skills",
                      definition: "Assessment, dressing selection and healing stages.", prerequisites: []),
                .init(name: "Infection Control", cluster: "Clinical Skills",
                      definition: "Hand hygiene, PPE and isolation precautions.", prerequisites: []),
                .init(name: "Vital Signs", cluster: "Patient Assessment",
                      definition: "Temperature, pulse, respiration, blood pressure, pain — and what changes mean.",
                      prerequisites: ["Cardiovascular System", "Respiratory System"]),
                .init(name: "Head-to-Toe Assessment", cluster: "Patient Assessment",
                      definition: "The systematic full-body exam every shift starts with.",
                      prerequisites: ["Vital Signs"]),
                .init(name: "Early Warning Scores", cluster: "Patient Assessment",
                      definition: "Scoring systems that flag deteriorating patients before crisis.",
                      prerequisites: ["Vital Signs"]),
                .init(name: "Pain Assessment", cluster: "Patient Assessment",
                      definition: "Scales and cues for measuring pain across ages and consciousness levels.",
                      prerequisites: ["Vital Signs"]),
                .init(name: "Informed Consent", cluster: "Ethics & Law",
                      definition: "Patients must understand and agree to care — the nurse's verification role.", prerequisites: []),
                .init(name: "Documentation Standards", cluster: "Ethics & Law",
                      definition: "If it isn't charted, it didn't happen: legal, timely, objective notes.", prerequisites: []),
                .init(name: "Patient Privacy", cluster: "Ethics & Law",
                      definition: "HIPAA-style confidentiality: what you can share, with whom, when.", prerequisites: []),
                .init(name: "Scope of Practice", cluster: "Ethics & Law",
                      definition: "What a nurse may and may not do — and when to escalate.", prerequisites: []),
                .init(name: "Triage Principles", cluster: "Your Unit",
                      definition: "Sorting patients by urgency when demand exceeds capacity.",
                      prerequisites: ["Early Warning Scores"]),
                .init(name: "Code Response", cluster: "Your Unit",
                      definition: "Roles and rhythm of a resuscitation team during an arrest.",
                      prerequisites: ["Vital Signs", "IV Therapy"]),
                .init(name: "Handoff Communication", cluster: "Your Unit",
                      definition: "SBAR: structured shift-change reporting that prevents errors.",
                      prerequisites: ["Documentation Standards"]),
            ],
            stages: [
                StageDef(title: "Stage 1 · The body", subtitle: "Anatomy & physiology foundations",
                         concepts: ["Cardiovascular System", "Respiratory System", "Renal System", "Fluid & Electrolytes"]),
                StageDef(title: "Stage 2 · Drugs", subtitle: "Pharmacology core",
                         concepts: ["Pharmacokinetics", "Beta-Blockers", "Anticoagulants",
                                    "Antibiotic Stewardship", "Insulin Management"]),
                StageDef(title: "Stage 3 · Hands-on care", subtitle: "Clinical skills + assessment",
                         concepts: ["Medication Administration", "IV Therapy", "Wound Care", "Infection Control",
                                    "Vital Signs", "Head-to-Toe Assessment", "Early Warning Scores", "Pain Assessment"]),
                StageDef(title: "Stage 4 · Professional practice", subtitle: "Ethics, law, unit work",
                         concepts: ["Informed Consent", "Documentation Standards", "Patient Privacy",
                                    "Scope of Practice", "Triage Principles", "Code Response", "Handoff Communication"]),
            ],
            suggestedSources: [
                .init(name: "NIH News Releases", url: "https://www.nih.gov/news-events/news-releases/feed", category: "Research"),
                .init(name: "ScienceDaily — Nursing", url: "https://www.sciencedaily.com/rss/health_medicine/nursing.xml", category: "Research"),
                .init(name: "Medical News Today", url: "https://rss.medicalnewstoday.com/featurednews.xml", category: "Industry"),
                .init(name: "WHO News", url: "https://www.who.int/rss-feeds/news-english.xml", category: "Policy"),
                .init(name: "CDC Newsroom", url: "https://tools.cdc.gov/podcasts/rss.asp", category: "Policy"),
            ]
        )
    }
}
