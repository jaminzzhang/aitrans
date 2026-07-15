# TDD 实施报告

## 1. 结论

| 项 | 内容 |
|---|---|
| 实施结论 | [KNOWN] `LOCAL_VERIFIED` |
| 最高风险等级 | [KNOWN] P1 |
| 实施范围 | [KNOWN] Scope S1-S9：Provider preset、统一 OpenAI-compatible SDK 适配、取消与最新请求保护、缓存隔离、Qwen 设置、function/tool-call 协议闭环 |
| 本地证据 | [KNOWN] `flutter analyze` 无问题；绕过 localhost 代理后 `flutter test --no-pub --concurrency=1` 29 项通过；UTF-8 环境下 macOS debug build 成功 |
| 未完成发布证据 | [KNOWN] 未调用真实厂商端点，未构建 iOS/Android，未执行发布、提交或推送 |

## 2. 输入与边界

| 输入 | 结果 |
|---|---|
| `feature_context.md` | [KNOWN] 已读取，feature-id 为 `ai-sdk-integration`，最高风险 P1 |
| `scope-plan.md` | [KNOWN] 已读取，准入状态为 `TDD_INPUT_READY`，包含 S1-S9 |
| 项目规则与上下文 | [KNOWN] 已读取 `AGENTS.md`、`docs/rules/coding_rules.md`、`docs/DOMAIN_KNOWLEDGE.md`、`docs/PROJ_CONTEXT.md` |
| 安全边界 | [KNOWN] 未读取 `.env*`、密钥、生产配置、生产数据或生产日志；所有协议测试使用本地 `HttpServer` 或 fake |
| Tool 执行边界 | [KNOWN] 只实现工具声明、调用事件、结果回传与轮次控制，不执行文件、Shell、网络或系统工具 |

## 3. 可观察行为与公共接口

| 对象 | 可观察行为 |
|---|---|
| `ProviderFactory` | [KNOWN] 提供 OpenAI、DeepSeek、Qwen、Ollama preset；允许自定义 endpoint/model；拒绝空远程密钥和 DeepSeek 旧模型 |
| `OpenAICompatibleProvider` | [KNOWN] 通过 `openai_dart` 发起可配置 Chat Completions 流；支持 timeout、网络 abort、安全错误映射和客户端关闭 |
| `AIProvider` | [KNOWN] 暴露稳定的项目级 chat、取消、关闭和缓存命名空间边界；SDK 类型未进入 UI/Controller |
| `AIChatRequest` | [KNOWN] 支持 function tools、`none/auto/required/named` 选择策略、assistant tool calls、tool-role result 和最大轮次 |
| Tool-call 校验 | [KNOWN] 拒绝未声明工具、重复 call ID、未知 result call ID、非对象 arguments 和不符合受支持 JSON Schema 子集的参数 |
| `TranslateController` | [KNOWN] 新输入、重新翻译、清空与 dispose 会取消旧请求；generation guard 阻止旧缓存或旧流覆盖最新状态 |
| `TranslationCacheIdentity` | [KNOWN] 以 provider namespace、模型、语言、选项和文本生成稳定 SHA-256 key，不包含 API Key |
| 设置界面 | [KNOWN] Qwen 可选择，并显示 factory 提供的 endpoint/model 提示；API Key 未接入普通 Hive 持久化 |

## 4. RED-GREEN-REFACTOR 记录

| 切片 | RED 证据 | GREEN 证据 | 重构结果 |
|---|---|---|---|
| S1 Provider preset | [KNOWN] provider factory 测试因缺少 Qwen、配置解析和 typed exception 失败 | [KNOWN] 5 项 preset/兼容索引/旧模型/覆盖/缺密钥测试通过 | [KNOWN] preset 与校验集中到 `ProviderFactory` |
| S2-S3 SDK seam | [KNOWN] 契约测试因 `OpenAICompatibleProvider` 不存在而失败 | [KNOWN] 本地 HTTP 流测试验证请求映射、UTF-8/SSE 跨分片和取消 | [KNOWN] 四类兼容端点统一使用一个 adapter，Claude 保持独立 |
| S4 取消与竞态 | [KNOWN] 测试因 `cancelActiveRequests` 缺失而失败；随后暴露 `implements` 无法继承默认方法 | [KNOWN] 底层 abort 使客户端流在服务端仍保持响应时结束；旧缓存不能覆盖新请求 | [KNOWN] Provider 改为继承公共默认行为，Controller 使用 generation guard |
| S5 缓存 | [KNOWN] 测试因 `TranslationCacheIdentity` 不存在而失败 | [KNOWN] 跨 provider/model/language/option 不误命中，选项顺序规范化 | [KNOWN] 缓存存储抽象为 `TranslationCacheStore` 以支持确定性测试 |
| S6 设置 | [KNOWN] 旧设置实现对 Qwen 的 switch 不完整；并行设置重写后测试暴露 custom provider 空配置异常 | [KNOWN] Qwen widget 测试通过，custom 展示不再触发完整配置校验 | [KNOWN] 展示名称与连接配置解析分离 |
| S7-S9 Tools | [KNOWN] 初始 tool tests 因 chat 类型和方法不存在而失败 | [KNOWN] 3 个协议场景通过：流式重组、显式 result 多轮回传、非法/未知/超轮次拒绝 | [KNOWN] 项目拥有 SDK 无关的 chat/tool 领域类型和保守 Schema 校验 |

## 5. 测试场景

| Given | When | Then | 证据 |
|---|---|---|---|
| [KNOWN] 本地服务把中文 UTF-8 与 SSE 行拆成任意字节块 | [KNOWN] compatible provider 流式翻译 | [KNOWN] 输出字符完整且顺序正确 | `test/core/ai/openai_compatible_provider_test.dart` |
| [KNOWN] 服务端响应保持打开 | [KNOWN] 调用 `cancelActiveRequests` | [KNOWN] 客户端流结束且不接收后续内容 | `test/core/ai/openai_compatible_provider_test.dart` |
| [KNOWN] 同一文本使用不同 provider/model/language/options | [KNOWN] 生成缓存身份 | [KNOWN] key 隔离；同一语义选项顺序得到相同 key | `test/core/cache/translation_cache_identity_test.dart` |
| [KNOWN] 旧缓存读取晚于新请求 | [KNOWN] 用户连续提交 | [KNOWN] 旧结果不能覆盖最新状态 | `test/features/translate/translate_controller_test.dart` |
| [KNOWN] tool arguments 跨多个 streaming delta | [KNOWN] chat stream 完成 | [KNOWN] call ID、name 与 arguments 被完整组装 | `test/core/ai/tool_call_test.dart` |
| [KNOWN] 调用方回传已知 tool call ID 的结果 | [KNOWN] 发起下一轮请求 | [KNOWN] assistant tool_calls 与 tool result 都保留在标准消息中 | `test/core/ai/tool_call_test.dart` |
| [KNOWN] 参数违反 Schema、result ID 未知或轮次超限 | [KNOWN] 发起 chat | [KNOWN] 在边界处返回 typed validation/configuration error | `test/core/ai/tool_call_test.dart` |

## 6. 实际验证命令

| 命令 | 结果 |
|---|---|
| `dart test test/core/ai test/core/cache` | [KNOWN] 12 项通过 |
| `flutter test --no-pub test/features/settings/settings_page_test.dart` | [KNOWN] 1 项通过 |
| `flutter analyze` | [KNOWN] `No issues found` |
| `NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 flutter test --no-pub --concurrency=1` | [KNOWN] 29 项通过 |
| `flutter build macos --debug` | [KNOWN] 首次因 CocoaPods 使用 `ASCII-8BIT` 失败，属于本机编码环境错误 |
| `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 flutter build macos --debug` | [KNOWN] 成功生成 `build/macos/Build/Products/Debug/aitrans.app` |

## 7. 变更对象

| 类别 | 文件 |
|---|---|
| SDK 与依赖 | [KNOWN] `pubspec.yaml`, `pubspec.lock` |
| AI 领域与适配 | [KNOWN] `lib/core/ai/ai_chat.dart`, `ai_provider.dart`, `openai_compatible_provider.dart`, `provider_factory.dart`, `ai.dart` 及既有 provider 的继承/缓存命名空间适配 |
| 状态与缓存 | [KNOWN] `lib/features/translate/logic/translate_controller.dart`, `lib/core/cache/translation_cache.dart` |
| 设置与必要编译修复 | [KNOWN] `lib/features/settings/ui/settings_page.dart`；并行 UI 变更中的 import、公开 theme token 和重复 import 修复 |
| 测试 | [KNOWN] `test/core/ai/`, `test/core/cache/`, `test/features/settings/`, `test/features/translate/` |
| 上下文 | [KNOWN] `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md`, `docs/features/ai-sdk-integration/` |

## 8. 残余风险与未覆盖项

| 风险/缺口 | 等级 | 处理建议 |
|---|---|---|
| [KNOWN] 未以真实 OpenAI、DeepSeek、Qwen、Ollama 端点验证当前响应差异 | P1 | [KNOWN] 使用独立脱敏测试账号做人工 smoke test；不得用生产密钥 |
| [KNOWN] iOS/Android 未构建，移动端局域网 Ollama 仍在 Scope 外 | P1 | [KNOWN] 发布前分别执行目标平台构建；移动 LAN 另立 Scope |
| [KNOWN] JSON Schema 校验器只覆盖保守子集，不是完整 Draft 实现 | P2 | [KNOWN] 新增复杂 Schema 前先扩展验证器和失败测试 |
| [KNOWN] DeepSeek/Qwen 默认模型名与厂商兼容行为会变化 | P1 | [KNOWN] 发布前按官方文档复核 preset，禁止静默切换计费模型 |
| [KNOWN] function/tool call 不执行任何工具 | P1 | [KNOWN] 若需要执行器，必须另立安全、权限、幂等与审计 Scope |
| [KNOWN] 并行 UI 变更与本功能同时存在于工作区 | P2 | [KNOWN] 提交前按 ownership 分组审查 diff，避免把无关 UI 改动混入同一提交 |

## 9. TDD 偏差

- [KNOWN] Tool-call 的主路径先取得 RED；部分细分异常路径在校验实现后补测试，没有为每个子路径保留独立 RED。
- [KNOWN] 取消测试最初尝试用服务端 socket flush 错误证明 abort，该信号受操作系统缓冲影响；最终改为验证公共行为：客户端流及时结束且服务端响应仍保持打开。
- [KNOWN] `dart format` 覆盖了含并行用户 UI 变更的若干文件，产生机械格式化；未回退或覆盖这些用户变更。

## 10. 下一步动作

1. [KNOWN] 由负责人审查 AI adapter、tool-call 边界和并行 UI diff。
2. [KNOWN] 使用非生产、脱敏凭证分别做四厂商 smoke test。
3. [KNOWN] 发布前补 iOS/Android 构建证据，并对 DeepSeek/Qwen preset 做时效性复核。
4. [KNOWN] 本报告不构成审批、合并或发布许可。

## 11. 2026-07-15 翻译提交与扩展请求增量

| 对象 | 证据 |
|---|---|
| 提交语义 | [KNOWN] Enter、数字键盘 Enter、软键盘提交和“翻译”按钮都调用 `TranslateController.translateNow`；Shift+Enter 仍可输入换行 |
| 两阶段顺序 | [KNOWN] 显式提交先完成主译文，仅在 complete 事件或主译文缓存命中后调用扩展加载；防抖输入只更新主译文 |
| 单次扩展请求 | [KNOWN] `TranslationEnrichment` 在一个 JSON 对象中承载 `examples`、`movieQuotes`和 `examItems`；`AuxiliaryController` 只订阅一个 `enrichTranslation` 流 |
| OpenAI-compatible 契约 | [COMPUTED] 本地 HTTP 契约测试断言一个扩展请求同时填充三类数据，服务端请求计数为 1 |
| RED | [COMPUTED] 初始聚焦测试因 `enrichTranslation` 和 `onTranslationCompleted` 不存在而编译失败；Enter 测试缺少键盘提交实现 |
| GREEN | [COMPUTED] `env NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test` 最终 89 项全部通过 |
| 静态与构建 | [COMPUTED] `flutter analyze` 返回 `No issues found`；`flutter build macos --debug` 成功生成 Debug App |

## 12. 2026-07-15 macOS Debug 启动故障取证

| 环节 | 证据 |
|---|---|
| 故障复现 | [COMPUTED] 直接执行 bundle 内 `aitrans` 二进制两次会产生两个 PID；第二实例报 `translation_cache.lock` 和 `settings_preferences.lock` 锁冲突 |
| 最小原因 | [INFERRED] 直接运行二进制绕过 macOS LaunchServices 的 App 实例复用，导致多进程争用 Hive 文件锁 |
| 修复 | [KNOWN] `scripts/run_macos_debug.sh` 会正常关闭旧实例、等待锁释放、编译、通过 `open` 启动，并检查单进程与启动存活 |
| 修复验证 | [COMPUTED] 连续两次 `open` 同一 Debug bundle 只保留一个 PID；`zsh scripts/run_macos_debug.sh` 构建成功并报告唯一存活 PID 33648 |
| 流程沉淀 | [KNOWN] `AGENTS.md` 已记录唯一启动命令、禁止方式、成功判定与 Flutter tester 本机代理绕过命令 |
