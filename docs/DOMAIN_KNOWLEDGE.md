# DOMAIN_KNOWLEDGE

## 1. Evidence boundary

- [KNOWN] `aitrans-prd.md` is the current product brief in this repository.
- [KNOWN] The brief describes intended behavior; it does not prove implementation completeness or product approval.
- [KNOWN] Unknown or unapproved business rules remain marked “待确认”.

## 2. Domain terms

| Term | Definition | Boundary | Evidence |
|---|---|---|---|
| [KNOWN] Source text | Text entered by the user for translation | [KNOWN] Supported languages and size limits are待确认 | `aitrans-prd.md` |
| [KNOWN] Translation result | Translated output shown to the user | [KNOWN] Quality threshold and formatting contract are待确认 | `aitrans-prd.md` |
| [KNOWN] Context example | Example intended to help explain usage | [KNOWN] Source, licensing, ranking, and verification are待确认 | `aitrans-prd.md` |
| [KNOWN] Movie quotation | Movie dialogue shown as supporting material | [KNOWN] Licensing, attribution, and excerpt limits are待确认 | `aitrans-prd.md` |
| [KNOWN] Exam item | Exam material shown as supporting evidence | [KNOWN] Source, copyright status, jurisdiction, and excerpt limits are待确认 | `aitrans-prd.md` |
| [KNOWN] AI provider | Local or remote AI integration used to produce translations | [KNOWN] Supported providers and routing policy are implementation/configuration concerns | `aitrans-prd.md`, `lib/core/ai/` |

## 3. Business domains

| Domain | Core objects | Key flow | High-risk unknowns |
|---|---|---|---|
| [KNOWN] Translation | Source text, result, provider, request state | [KNOWN] Enter text → invoke translation → display result | [KNOWN] Language detection, limits, quality policy, timeout, cancellation are待确认 |
| [KNOWN] Learning context | Context examples, movie quotations, exam items | [KNOWN] Display supporting sections beside the translation | [KNOWN] Provenance, copyright, ranking, and factual verification are待确认 |
| [KNOWN] Quick invocation | Global shortcut, app window, input, Enter action | [KNOWN] On macOS, invoke app via shortcut and translate with Enter | [KNOWN] Shortcut conflict, permission, focus, and accessibility behavior are待确认 |
| [KNOWN] Provider configuration | Provider type and provider settings | [KNOWN] Select/configure an AI provider used by translation | [KNOWN] Credential storage and provider fallback policy are待确认 |
| [KNOWN] Translation cache | Cached translation and cache lookup | [KNOWN] Reuse locally stored translation data | [KNOWN] Cache key, expiry, retention, deletion, and privacy policy are待确认 |

## 4. Reusable business rules

| Rule ID | Rule | Scope | Evidence | Status |
|---|---|---|---|---|
| TR-001 | [KNOWN] The product provides text input and displays a translation result. | Translation | `aitrans-prd.md` | [KNOWN] Confirmed brief |
| TR-002 | [KNOWN] The intended result view includes context examples, movie quotations, and exam items. | Learning context | `aitrans-prd.md` | [KNOWN] Confirmed brief; acceptance details待确认 |
| TR-003 | [KNOWN] On macOS, the intended flow supports global-shortcut invocation and Enter-to-translate. | Quick invocation | `aitrans-prd.md` | [KNOWN] Confirmed brief; shortcut specification待确认 |
| TR-004 | [KNOWN] The intended supported platforms are macOS, iOS, and Android. | Platform scope | `aitrans-prd.md` | [KNOWN] Confirmed brief |
