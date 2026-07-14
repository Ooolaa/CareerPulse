# CareerPulse — Privacy

CareerPulse is built so that **your data never leaves your phone**. This is a
product principle, not a setting.

## What we collect

Nothing. There is **no account, no sign-in, no server, and no analytics SDK**.
The App Store privacy label is "Data Not Collected". Purchasing the app is the
only transaction, handled entirely by Apple.

## Where your data lives

Everything — the career pack you chose or built, which concepts you've marked
known, your reading history, streaks, and quiz results — is stored in a local
database inside the app's private sandbox on your device. It is never uploaded.

## Network traffic

The app makes exactly these outbound connections, all over HTTPS:

1. **Feed downloads** — fetching public RSS/Atom feeds from the sources you
   enabled, and (optionally) the full text of an article from its publisher
   when you open it. Same as any news reader.
2. **Your own AI key (optional)** — if *you* add a Claude API key, pack
   generation and "Go deeper" send the relevant prompt **directly to
   api.anthropic.com using your key**. It never passes through any server of
   ours (there is none). Remove the key anytime in Settings → AI engine.

By default (on-device Apple Intelligence, or the built-in fallback), even the
AI analysis runs locally and no article text or knowledge data is transmitted.

## Your API key

If you provide a Claude API key it is stored in the **iOS Keychain**
(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, this device only, not
synced by us). It is never written to logs, never sent anywhere except
Anthropic's own API on your behalf, and is deleted from the Keychain when you
remove it.

## Security posture

- No third-party dependencies (nothing to compromise in a supply-chain attack).
- Feed XML is parsed with external-entity resolution **disabled** (no XXE /
  billion-laughs) and size caps.
- Untrusted model output (generated or imported packs) is **sanitized and
  validated** — cycle-broken, dangling references scrubbed — before it can
  touch your map. Suggested feed URLs are probed and only kept if they respond.
- AI prompts use system-side instructions and typed/structured output, limiting
  prompt-injection from feed content.

## Generated & imported packs

AI-generated packs are labelled as such and shown for your review before use.
For regulated fields (medicine, law, finance) they are **educational
scaffolding, not professional advice** — a banner says so, and the app never
generates dosage, legal, or financial recommendations.
