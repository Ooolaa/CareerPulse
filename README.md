# CareerPulse — retired

> **This project is retired and archived as history. Nothing new is built here.**
>
> The work continues in **[TechPulse](https://github.com/Ooolaa/TechPulse)**,
> which absorbed the runtime pack system this repo was built to prove. Packs are
> runtime data there — a Pack file, validated and installed at launch — and the
> AI Engineer pack is one built-in among others rather than the only possibility.
> So CareerPulse's central idea shipped; what retired is the second app around it.
>
> **Why:** the two projects had converged on the same product, differing only in
> where the map came from, and keeping both meant hand-merging every TechPulse
> feature into this repo indefinitely. The reasoning, including the rejected
> alternative of doing it the other way round, is
> [ADR-0001](https://github.com/Ooolaa/TechPulse/blob/main/docs/adr/0001-one-app-packs-become-runtime-data.md).
>
> **What came across, and what did not**, file by file — the security tests and
> `PRIVACY.md` came over; the draft and generator types are tracked as TechPulse
> #27; the five accent palettes and the onboarding wizard were dropped, with
> reasons —
> [ADR-0005](https://github.com/Ooolaa/TechPulse/blob/main/docs/adr/0005-careerpulse-is-retired-and-what-came-across.md).
>
> This repository is kept deliberately: it is the source the port was taken
> from, and the commit the inventory was taken against is `af8ab0c`. The
> description below is preserved as it stood on that commit.

---

One app, any career, customized on your phone. CareerPulse turns the
[TechPulse](../TechPulse) formula — curated news feed + living knowledge map +
gap detection + habit-forming daily goals — into a **career-agnostic engine**:
the "pack" that defines a profession's skill tree is runtime data, not code, so
one app becomes a learning tool for AI engineering, nursing, or anything else.

Full product & business spec: [CareerPulse-Template.md](CareerPulse-Template.md).
Privacy: [PRIVACY.md](PRIVACY.md). Dev diary: [DEVLOG.md](DEVLOG.md).

## The Lego-blocks idea

On first launch a wizard lets you **build your own app**:
1. **Career** — pick a bundled starter pack (AI Engineer, Registered Nurse),
   import a pack as JSON, or type any career and have it **generated on-device**
   (Apple Intelligence) or with **your own Claude API key**.
2. **Review** — edit the generated/chosen map: delete or rename concepts;
   prerequisites and stages stay consistent automatically.
3. **Style** — five accent palettes (Ocean/Plum/Forest/Sunset/Mono); the whole
   app re-colors live. Personalization without asking anything sensitive.
4. **Sources** — toggle suggested feeds or paste any site/feed URL.
5. **Mark what you know** — green dots from day one.

Everything after that is the TechPulse engine: read the feed → the map lights
up → the gap detector says what to learn next → weekly on-device quizzes.

## Privacy is the product

No accounts, no server, no analytics — all data stays on device. Optional
"bring your own key" AI goes straight to Anthropic with your key (Keychain-
stored), never through us. See [PRIVACY.md](PRIVACY.md).

## Architecture

- **Runtime packs**: `PackFile` (versioned JSON) → `PackValidator` (DAG /
  dangling / limit checks) → `PackInstaller` → `KnowledgePackRecord`. Export
  your live pack back to JSON to share.
- **Generation**: `PackGenerator` (staged Foundation Models, or single-shot via
  `AnthropicClient`) → `sanitize` → validate → probe sources.
- **Engines** (career-agnostic): `KnowledgeEngine` (mastery/decay/links),
  `KnowledgePathEngine` (frontier/gap/recommendations over the active pack),
  `QuizEngine`, `IntelligenceService`, `FeedSyncService`, `FullTextService`.
- SwiftUI + SwiftData, iOS 26, Swift 6 strict concurrency, XcodeGen (edit
  `project.yml`, not the `.xcodeproj`). No third-party dependencies.

## Build

```bash
xcodegen generate
open CareerPulse.xcodeproj      # ⌘R to run
# or: xcodebuild -scheme CareerPulse -destination 'generic/platform=iOS Simulator' build
```

Tests: 36 unit (Swift Testing) + 2 XCUITest journeys that screenshot every
screen to `/tmp/techpulse_uitest`.

## Status

U1 scaffold ✅ · U2 runtime packs ✅ · U3 wizard + themes ✅ · U4 generation +
BYO key ✅ · U5 polish/docs ✅. Built with Claude Code.
