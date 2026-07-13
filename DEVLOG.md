# CareerPulse — Development Log

> Daily record of the development process. Newest first. CareerPulse is the
> career-agnostic "Lego blocks" evolution of [TechPulse](../TechPulse/DEVLOG.md):
> one app, any career, customized on the phone. Spec: `CareerPulse-Template.md`.

**Product decisions (locked with the owner):** no sign-in of any kind
(App Store purchase = license, zero data collected) · style/theme picker
instead of a gender question · pack generation on-device by default with
optional bring-your-own API key (Keychain) · all data stays local.

**Milestones:** U1 scaffold ✅ · U2 runtime packs ✅ · U3 onboarding wizard +
themes · U4 AI pack generation + BYO key · U5 polish/share/docs.

---

## 2026-07-12 — U2: packs are data, not code (`6b113b3`, `d1786a1`)

**Built**
- Re-synced from TechPulse tip first, inheriting the habit system,
  archipelago map, selectable text, Go deeper, and pulse for free.
- `KnowledgePackRecord` (@Model): the installed pack's identity, cluster
  order, learning-path stages, concept membership.
- **PackFile**: versioned, portable JSON pack format (career / clusters /
  concepts+prereqs / stages / suggested sources) — doubles as the future
  marketplace format.
- **PackValidator**: never trust generated or imported packs — Kahn's
  algorithm for cycle detection, dangling-prerequisite checks, cluster and
  size limits, definition presence.
- **PackInstaller**: installs validated packs (existing concepts keep their
  mastery and adopt the pack's cluster — switch careers without losing what
  you know), deactivates prior packs, exports the live pack back to JSON.
- **BuiltinPacks**: AI Engineer (ported) + **Registered Nurse** (24 concepts,
  Anatomy → Pharmacology → Clinical Skills → Assessment → Ethics; NIH/WHO
  feeds) — first proof the formula generalizes beyond tech.
- Engines and all views now read `ActivePack` at runtime; the old static
  `KnowledgePack` enum survives only as data for the builtin pack.

**Verified** 21 unit tests (validator, JSON round-trip, installer mastery
survival, engine-over-runtime-pack) + both UI journeys, all green.

---

## 2026-07-10 — U1: scaffold (`267e2ec`)

Copied TechPulse sources wholesale, renamed to CareerPulse, own XcodeGen
project + git repo, built clean on first try. Strategy: the engines were
career-agnostic from day one — the fork costs almost nothing, and the
re-sync pattern (see U2) keeps pulling TechPulse improvements forward.

---

*Local repo (not yet on GitHub). Built with Claude Code.*
