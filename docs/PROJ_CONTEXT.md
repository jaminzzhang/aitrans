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

[KNOWN] The `ai-sdk-integration` feature scope is user-confirmed and has reached `LOCAL_VERIFIED` status; `settings-persistence` has reached `PARTIAL_VERIFICATION` because mobile builds are blocked by the local toolchain. Named business, development, and test owners remain unassigned.

| feature-id | Feature | Status | Modules | Summary | Path | Highest risk | Updated |
|---|---|---|---|---|---|---|---|
| `ai-sdk-integration` | [KNOWN] AI SDK 统一接入与 tool-call 协议 | [KNOWN] `LOCAL_VERIFIED` | `lib/core/ai/`, config, controller, cache, settings, tests | [KNOWN] 采用 `openai_dart` 适配 OpenAI、DeepSeek、Qwen 和 macOS Ollama；支持标准文本、流式及 function tools 协议，不自动执行工具；静态分析、29 项本地测试和 macOS 调试构建已通过 | `docs/features/ai-sdk-integration/` | P1 | [KNOWN] 2026-07-14 |
| `settings-persistence` | [KNOWN] 设置持久化与 Provider 凭证隔离 | [KNOWN] `PARTIAL_VERIFICATION` | `lib/core/config/`, `lib/core/security/`, settings, startup, platform configs, tests | [KNOWN] 偏好与 Provider AES-256-GCM envelopes 使用单记录原子提交；主密钥采用 pending 文件恢复、稳定 ID/keyId 绑定；56 项测试、静态分析、macOS Debug 构建和启动通过 | `docs/features/settings-persistence/` | P1 | [KNOWN] 2026-07-14 |

## 3. Module structure

| Module/path | Responsibility | Entry | Evidence note |
|---|---|---|---|
| `lib/main.dart` | [KNOWN] Process initialization, Hive setup, macOS window setup, hotkey registration | `main()` | [KNOWN] Verified in source |
| `lib/app.dart` | [KNOWN] Application root, theme, navigation | `AITransApp`, `MainPage` | [KNOWN] Verified in source |
| `lib/core/ai/` | [KNOWN] AI provider abstraction and provider implementations | `ai_provider.dart`, `provider_factory.dart` | [KNOWN] Verified by file structure |
| `lib/core/cache/` | [KNOWN] Translation cache model/behavior | `translation_cache.dart` | [KNOWN] Verified by file structure |
| `lib/core/config/` | [KNOWN] Runtime AI configuration, non-secret Hive preferences, and composed settings repository | `ai_config.dart`, `settings_preferences_store.dart`, `settings_repository.dart` | [KNOWN] Verified in source and tests |
| `lib/core/security/` | [KNOWN] Provider-scoped credential boundary, local master-key store, and AES-GCM adapter | `provider_credential_store.dart`, `local_master_key_store.dart`, `encrypted_provider_credential_store.dart` | [KNOWN] Verified in source and tests |
| `lib/core/platform/` | [KNOWN] Platform integration for hotkeys | `hotkey_service.dart` | [KNOWN] Verified by file structure |
| `lib/features/translate/` | [KNOWN] Translation state, controller, and UI | `translate_controller.dart`, `translate_page.dart` | [KNOWN] Verified by file structure |
| `lib/features/settings/` | [KNOWN] Settings UI | `settings_page.dart` | [KNOWN] Verified by file structure |
| `lib/shared/theme/` | [KNOWN] Shared visual theme | `app_theme.dart` | [KNOWN] Verified by file structure |

## 4. Core flows

| Flow | Trigger | Steps | Modules | Open risks |
|---|---|---|---|---|
| [INFERRED] App startup | [KNOWN] Process launch | [KNOWN] Initialize Flutter → initialize/open Hive → configure macOS window/hotkey when applicable → run app | `main.dart`, config, cache, platform | [KNOWN] Initialization errors are currently logged and startup continues; required failure policy is待确认 |
| [INFERRED] Translation | [KNOWN] User submits source text | [INFERRED] Controller selects provider → sends request → updates state → renders result → may use cache | translate, AI, cache | [KNOWN] Exact timeout, cancellation, retry, stale-response, and cache rules are待确认 |
| [KNOWN] Settings | [KNOWN] User opens Settings | [KNOWN] UI copies active configuration into a local Draft → Provider switch loads isolated credential → connection test uses Draft → Save writes credential and preferences → active Riverpod state updates only after success | settings, config, security | [KNOWN] Cross-store persistence has no shared transaction; failure keeps active state unchanged and remains retryable |
| [KNOWN] macOS quick invocation | [KNOWN] Global hotkey | [KNOWN] Registered hotkey interacts with the macOS app; exact focus/submit behavior needs verification | platform, main | [KNOWN] Permission and shortcut-conflict behavior are待确认 |

## 5. External dependencies

| Object | Direction | Purpose | Failure behavior | Open issue |
|---|---|---|---|---|
| [KNOWN] AI provider implementations | Outbound | [KNOWN] Produce translation-related responses | [KNOWN] Requires source verification in focused tasks | [KNOWN] Timeout, retry, schema, privacy, and cost rules are待确认 |
| [KNOWN] OpenAI-compatible SDK adapter | Outbound | [KNOWN] 统一 OpenAI、DeepSeek、Qwen 与 macOS Ollama 的文本、流式和 function-tool 协议 | [KNOWN] 结构化错误、网络取消和 capability 校验由 feature 契约约束 | [KNOWN] 不执行模型请求的工具；执行器必须另立 Scope |
| [KNOWN] Hive translation cache | Local | [KNOWN] Persist translated results and access timestamps | [KNOWN] Initialization exceptions are caught in `main.dart` | [KNOWN] Encryption, retention, deletion, migration, and recovery are待确认 |
| [KNOWN] Hive settings-preferences box | Local | [KNOWN] Persists schema version, Provider ID, Base URL, and model as one non-secret record | [KNOWN] Missing or malformed data falls back to Ollama defaults | [KNOWN] Cross-version migrations beyond schema 1 require a future migration plan |
| [KNOWN] Encrypted settings state | Local | [KNOWN] Atomically persists non-secret preferences and Provider-scoped AES-256-GCM envelopes in one versioned Hive state; 256-bit master key remains a separate local file | [KNOWN] Missing/corrupt keys never trigger implicit replacement; UI exposes a confirmed reset path | [KNOWN] Same-user file readers may obtain both key and ciphertext; this is weaker than OS secure storage |
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
| [KNOWN] Resolved: `AIConfig` previously had a Hive adapter containing `apiKey` and settings only updated Riverpod memory | `settings-persistence` implementation and tests | [KNOWN] Runtime config is now immutable and non-serializable; preferences exclude API Key; credentials are Provider-scoped AES-GCM ciphertext with a separate local master key | [KNOWN] Keep AAD/tamper tests and never reintroduce credentials into ordinary plaintext Hive |

## 8. ADR index

| ADR | Decision | Status | Scope |
|---|---|---|---|

[KNOWN] No qualifying owner-confirmed ADR was identified during initialization.
