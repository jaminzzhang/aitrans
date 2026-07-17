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
| [KNOWN] OpenAI-compatible endpoint | [KNOWN] 接受标准 Chat Completions 请求形状的可配置服务入口 | [KNOWN] 兼容不代表覆盖 OpenAI 全部 API 或厂商专有字段 | `docs/features/ai-sdk-integration/` |
| [KNOWN] Provider preset | [KNOWN] 某 AI 厂商的默认 base URL、认证规则、模型与 capability 配置 | [KNOWN] 用户自定义 endpoint/model 可覆盖 preset，但不得静默更换计费模型 | `docs/features/ai-sdk-integration/` |
| [KNOWN] Settings preferences | [KNOWN] 当前 Provider、可选 Base URL 和模型等非敏感本地偏好 | [KNOWN] 不包含 API Key；损坏或不可读时回退 Ollama 默认配置 | `docs/features/settings-persistence/` |
| [KNOWN] Provider credential | [KNOWN] 按显式稳定 Provider ID 隔离的 API Key | [KNOWN] 只以 AES-256-GCM envelope 进入版本化原子设置记录，不以明文进入 Hive、日志或测试 fixture；主密钥在独立本地文件 | `docs/features/settings-persistence/` |
| [KNOWN] Settings draft | [KNOWN] 设置页中尚未提交的 Provider、凭证和覆盖字段 | [KNOWN] 切换 Provider、编辑和测试连接不改变当前生效配置；保存全部成功后才提交应用状态 | `docs/features/settings-persistence/` |
| [KNOWN] Tool call / function call | [KNOWN] 模型返回的结构化函数调用意图，包含 call ID、函数名和 JSON arguments | [KNOWN] 它不是函数执行；首期应用只交付受控调用事件并接收显式 tool result | `docs/features/ai-sdk-integration/` |
| [KNOWN] Tool result | [KNOWN] 调用方针对既有 call ID 显式提交给模型的函数结果消息 | [KNOWN] 未知、重复或过期 call ID 必须拒绝 | `docs/features/ai-sdk-integration/` |

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
| TR-005 | [KNOWN] macOS 全局快捷键 `⌘⇧T` 从隐藏打开窗口时先读取当前选区、选区不可用时回退剪贴板，并只预填输入框；关闭分支不读取文本。 | Quick invocation | `docs/features/macos-menu-bar-residency/` | [KNOWN] User-confirmed scope |
| TR-004 | [KNOWN] The intended supported platforms are macOS, iOS, and Android. | Platform scope | `aitrans-prd.md` | [KNOWN] Confirmed brief |
| AI-001 | [KNOWN] OpenAI、DeepSeek、Qwen 与 macOS Ollama 的首期标准调用统一封装在项目 `AIProvider` 边界内。 | Provider integration | `docs/features/ai-sdk-integration/` | [KNOWN] User-confirmed scope |
| AI-002 | [KNOWN] 首期支持 function-tool 声明、选择、非流式/流式 tool calls、显式 tool result 和多轮闭环。 | Tool-call protocol | `docs/features/ai-sdk-integration/` | [KNOWN] User-confirmed scope |
| AI-003 | [KNOWN] 首期不内置或自动执行文件、Shell、网络、系统函数；任何工具执行器必须另立 Scope。 | Tool execution boundary | `docs/features/ai-sdk-integration/` | [KNOWN] User-confirmed scope |
| AI-004 | [KNOWN] 模型生成的工具名和 arguments 不可信；只接受当前请求声明的函数，并在产生调用事件前验证 JSON、Schema 和 call ID。 | Tool-call safety | `docs/features/ai-sdk-integration/` | [KNOWN] User-confirmed scope |
| SET-001 | [KNOWN] Provider、Base URL 和模型可以写入非敏感本地偏好；API Key 明文不得写入 Hive，只允许写入已批准的认证密文 envelope。 | Provider configuration | `docs/features/settings-persistence/` | [KNOWN] User-confirmed scope |
| SET-002 | [KNOWN] API Key 必须按稳定 Provider ID 隔离；空值表示删除当前 Provider 凭证。 | Provider credential | `docs/features/settings-persistence/` | [KNOWN] User-confirmed scope |
| SET-003 | [KNOWN] 设置编辑与连接测试只操作 Draft；只有持久化成功后才更新生效配置。 | Settings workflow | `docs/features/settings-persistence/` | [KNOWN] User-confirmed scope |
| SET-004 | [KNOWN] 空 Base URL 或模型表示显式删除自定义覆盖并恢复 Provider preset。 | Provider configuration | `docs/features/settings-persistence/` | [KNOWN] User-confirmed scope |
| SET-005 | [KNOWN] App 的 Hive 与本地主密钥只存放在 Application Support 的 Bundle ID/AITrans 私有目录；不得在启动时探测 Documents，旧数据只由显式脚本手动搬迁。 | Local storage | `docs/features/settings-persistence/` | [KNOWN] User-confirmed scope |
