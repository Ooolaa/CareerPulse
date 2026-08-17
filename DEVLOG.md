# CareerPulse — Development Log

> **Closed 2026-08-17.** This project is retired; the log ends here. Work
> continues in [TechPulse](https://github.com/Ooolaa/TechPulse), whose DEVLOG
> carries it on. What came across and what was dropped is recorded in
> [ADR-0005](https://github.com/Ooolaa/TechPulse/blob/main/docs/adr/0005-careerpulse-is-retired-and-what-came-across.md).
> Everything below stands as written.

> Daily record of the development process. Newest first. CareerPulse is the
> career-agnostic "Lego blocks" evolution of [TechPulse](../TechPulse/DEVLOG.md):
> one app, any career, customized on the phone. Spec: `CareerPulse-Template.md`.

**Product decisions (locked with the owner):** no sign-in of any kind
(App Store purchase = license, zero data collected) · style/theme picker
instead of a gender question · pack generation on-device by default with
optional bring-your-own API key (Keychain) · all data stays local.

**Milestones:** U1 scaffold ✅ · U2 runtime packs ✅ · U3 wizard + themes ✅ ·
U4 AI pack generation + BYO key · U5 polish/share/docs.

---

## 2026-07-31 — The repo leaves the laptop; agent skills configured

**Built**
- **CareerPulse is on GitHub** — private, at `Ooolaa/CareerPulse`. Since the
  U1 scaffold this repo has existed in exactly one place, with no backup and no
  remote; the six commits of U1–U5 have now been pushed. History was scanned
  for key-shaped strings and sensitive files before pushing — the BYO API key
  lives in the Keychain, never in the tree, and nothing turned up.
- **`docs/agents/`** — `issue-tracker.md` (GitHub issues via the `gh` CLI),
  `triage-labels.md`, `domain.md`, with a new root **`CLAUDE.md`** pointing at
  them. The triage roles were created as real labels on the new repo:
  `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, plus
  GitHub's stock `wontfix`.
- **Identical config to TechPulse, on purpose.** The re-sync from TechPulse tip
  is a hand-merge of Swift sources, so root files have never collided — but
  keeping these four byte-identical means they can't start.

**Verified** Remote `main` matches local `main` at `f2b682c`. `gh label list`
returns all five canonical roles on the new repo.

**Learned** Choosing GitHub over local-markdown issues for this repo was
settled by an argument that turned out to be wrong — a feared config collision
during re-sync that the actual re-sync commit disproves (it touched only
`CareerPulse/**/*.swift`, `Tests/`, and `project.pbxproj`). The decision still
holds on its own merits: one workflow across both repos, and this repo finally
has an off-device copy.

---

## 2026-07-14 — U4 generation + BYO key · U5 polish & docs

**Built**
- **AI pack generation** (`PackGenerator`): type any career → on-device
  Foundation Models (staged: clusters → concepts-per-cluster → stages) or,
  without Apple Intelligence, the user's own Claude key. Wizard step 1 shows
  availability and an inline key field; generated maps land in the editable
  review step with a "not professional advice" banner.
- **BYO API key**: `KeychainStore` (Keychain only, this-device, never logged)
  + `AnthropicClient` (plain URLSession, no SDK, direct to api.anthropic.com).
  Added an entitlements file for reliable Keychain access.
- **Security-first output handling**: `sanitize()` dedupes, scrubs self/dangling
  prerequisites, **breaks cycles** (Kahn), synthesizes stages, then the pack
  must pass `PackValidator`; hallucinated feed URLs are probed and dropped if
  dead. XML parser now disables external-entity resolution (XXE guard).
- **U5**: distinct plum-teal app icon; PRIVACY.md; README; DEVLOG.
- **Back-ported to TechPulse**: BYO-key "Go deeper", KeychainStore,
  AnthropicClient, AI-engine settings, XXE hardening — so the feature works on
  John's iPhone 14 Pro (no Apple Intelligence) with his own key.

**Verified** 36 unit tests (Keychain round-trip, Anthropic request shape via
stubbed URLProtocol, sanitizer cycle-breaking/scrubbing, fenced-JSON parsing,
XXE) + both UI journeys. TechPulse 21 tests still green after the back-port.

**Learned** Unsigned simulator test hosts can't touch the Keychain
(errSecMissingEntitlement −34018) — added `saveStatus` so the test recognizes
and skips that specific environment while still validating real logic on a
signed device. Security testing surfaced the right seam.

---

## 2026-07-14 — U3: onboarding wizard + dynamic themes

**Built**
- Re-synced TechPulse's readability round first (semantic zoom, glossary
  strip, full-text fetch, settings headers, streak pill) — merged by hand
  where U2's pack-awareness had diverged (FullMapView, ClusterDetailView,
  ProgressTabView).
- **Dynamic themes**: `Palette` (Ocean/Plum/Forest/Sunset/Mono) with the
  chassis and mastery semantics constant — only the accent hue changes;
  hardcoded accent literals routed through `Theme.accentWash/accentBorder`;
  whole tree re-renders live via `.id(paletteName)`.
- **5-step onboarding wizard**: 1 career (starter packs + JSON import +
  free-text placeholder for U4 generation) → 2 editable review (swipe-delete
  and rename propagate through prerequisites & stages via `PackDraft`, so the
  draft always stays installable) → 3 style picker (live re-theme) →
  4 sources (toggle suggested + paste-a-URL with `FeedDiscovery`: direct feed
  probe, else `<link rel=alternate>` discovery) → install → 5 "mark what you
  know" chips (green dots from day one).
- Settings: Appearance picker · Career pack section (current pack, **Export
  my pack** as shareable JSON via Transferable, **Start a new career** which
  re-runs the wizard while keeping mastery).
- SeedData now only auto-installs for already-onboarded users; new users get
  their pack from the wizard.

**Verified** 29 unit tests (4 new PackDraft propagation tests) + full UI
journey driving the wizard end-to-end with screenshots of every step.

**Learned** The journey test caught a real first-run bug: Feed's sync task
fires before the wizard installs sources, leaving a new user with an empty
feed — fixed by re-syncing when sources first appear. UI tests keep earning
their keep.

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

*Private repo at [Ooolaa/CareerPulse](https://github.com/Ooolaa/CareerPulse).
Built with Claude Code.*
