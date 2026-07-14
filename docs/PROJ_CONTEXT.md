# PROJ_CONTEXT

## 1. Project summary

| Field | Content |
|---|---|
| Project name | [KNOWN] AITrans / package `aitrans` |
| Product intent | [KNOWN] AI-assisted translation with supporting usage material |
| Technology | [KNOWN] Flutter, Dart SDK `^3.10.4`, Riverpod, Dio, Hive, `hotkey_manager`, `window_manager` |
| Intended platforms | [KNOWN] macOS, iOS, Android |
| Source of product intent | [KNOWN] `aitrans-prd.md` |
| Owner | [KNOWN] 待确认 |
| Upstream systems | [KNOWN] Local or remote AI providers; exact production providers are待确认 |
| Downstream systems | [KNOWN] 待确认 |

## 2. Feature index

[KNOWN] No owner-confirmed `feature-id` or feature lifecycle document exists yet.

| feature-id | Feature | Status | Modules | Summary | Path | Highest risk | Updated |
|---|---|---|---|---|---|---|---|

## 3. Module structure

| Module/path | Responsibility | Entry | Evidence note |
|---|---|---|---|
| `lib/main.dart` | [KNOWN] Process initialization, Hive setup, macOS window setup, hotkey registration | `main()` | [KNOWN] Verified in source |
| `lib/app.dart` | [KNOWN] Application root, theme, navigation | `AITransApp`, `MainPage` | [KNOWN] Verified in source |
| `lib/core/ai/` | [KNOWN] AI provider abstraction and provider implementations | `ai_provider.dart`, `provider_factory.dart` | [KNOWN] Verified by file structure |
| `lib/core/cache/` | [KNOWN] Translation cache model/behavior | `translation_cache.dart` | [KNOWN] Verified by file structure |
| `lib/core/config/` | [KNOWN] AI provider configuration and generated adapter | `ai_config.dart` | [KNOWN] Verified by file structure |
| `lib/core/platform/` | [KNOWN] Platform integration for hotkeys | `hotkey_service.dart` | [KNOWN] Verified by file structure |
| `lib/features/translate/` | [KNOWN] Translation state, controller, and UI | `translate_controller.dart`, `translate_page.dart` | [KNOWN] Verified by file structure |
| `lib/features/settings/` | [KNOWN] Settings UI | `settings_page.dart` | [KNOWN] Verified by file structure |
| `lib/shared/theme/` | [KNOWN] Shared visual theme | `app_theme.dart` | [KNOWN] Verified by file structure |

## 4. Core flows

| Flow | Trigger | Steps | Modules | Open risks |
|---|---|---|---|---|
| [INFERRED] App startup | [KNOWN] Process launch | [KNOWN] Initialize Flutter → initialize/open Hive → configure macOS window/hotkey when applicable → run app | `main.dart`, config, cache, platform | [KNOWN] Initialization errors are currently logged and startup continues; required failure policy is待确认 |
| [INFERRED] Translation | [KNOWN] User submits source text | [INFERRED] Controller selects provider → sends request → updates state → renders result → may use cache | translate, AI, cache | [KNOWN] Exact timeout, cancellation, retry, stale-response, and cache rules are待确认 |
| [KNOWN] Settings | [KNOWN] User opens Settings | [KNOWN] UI edits provider configuration in Riverpod memory; no settings-to-Hive write was found | settings, config | [KNOWN] Durable credential storage and validation policy are待确认 |
| [KNOWN] macOS quick invocation | [KNOWN] Global hotkey | [KNOWN] Registered hotkey interacts with the macOS app; exact focus/submit behavior needs verification | platform, main | [KNOWN] Permission and shortcut-conflict behavior are待确认 |

## 5. External dependencies

| Object | Direction | Purpose | Failure behavior | Open issue |
|---|---|---|---|---|
| [KNOWN] AI provider implementations | Outbound | [KNOWN] Produce translation-related responses | [KNOWN] Requires source verification in focused tasks | [KNOWN] Timeout, retry, schema, privacy, and cost rules are待确认 |
| [KNOWN] Hive translation cache | Local | [KNOWN] Persist translated results and access timestamps | [KNOWN] Initialization exceptions are caught in `main.dart` | [KNOWN] Encryption, retention, deletion, migration, and recovery are待确认 |
| [KNOWN] Hive AI-config box | Local | [KNOWN] The box and adapter are initialized, but no configuration write was found | [KNOWN] Initialization exceptions are caught in `main.dart` | [KNOWN] Whether persistence is intended and how credentials would be secured are待确认 |
| [KNOWN] macOS hotkey/window plugins | Local platform | [KNOWN] Window behavior and global shortcut | [KNOWN] Initialization exceptions are caught in `main.dart` | [KNOWN] Required permissions and conflict UX are待确认 |

## 6. Local command matrix

| Scope | Test | Build | Analyze/format | Condition |
|---|---|---|---|---|
| Whole Flutter app | `flutter test` | `flutter build <target>` | `flutter analyze`; `dart format --output=none --set-exit-if-changed lib test` | [KNOWN] Select a configured target; do not infer release readiness from a successful local build |
| Focused Dart test | `flutter test test/<file>_test.dart` | [KNOWN] Not applicable | `dart format <changed-dart-files>` | [KNOWN] Use during focused implementation |

## 7. Historical risks

| Risk | Evidence | Impact | Prevention |
|---|---|---|---|
| [KNOWN] Existing widget test is a placeholder assertion | `test/widget_test.dart` | [INFERRED] It does not verify application launch or user behavior | [KNOWN] Replace/add behavior-focused tests when implementing features |
| [KNOWN] Startup catches Hive and macOS initialization errors and continues | `lib/main.dart` | [INFERRED] The app may enter a degraded state without explicit user feedback | [KNOWN] Define and test degraded-mode UX before relying on these services |
| [KNOWN] Translation results are written to a Hive box opened without an encryption cipher | `lib/main.dart`, `lib/core/cache/translation_cache.dart` | [INFERRED] Translated user content may remain readable in local application storage | [KNOWN] Define data classification, encryption, retention, and deletion before release |
| [KNOWN] `AIConfig` is Hive-serializable and contains `apiKey`, while current settings save only updates Riverpod memory | `lib/core/config/ai_config.dart`, `lib/features/settings/ui/settings_page.dart` | [INFERRED] A future persistence hookup could expose credentials if it reuses the unencrypted box design | [KNOWN] Use an approved secure-storage design before persisting credentials |

## 8. ADR index

| ADR | Decision | Status | Scope |
|---|---|---|---|

[KNOWN] No qualifying owner-confirmed ADR was identified during initialization.
