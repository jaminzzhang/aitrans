# feature_context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] AI 调用 SDK 选型与多厂商兼容接入评估 |
| feature-id | [KNOWN] `ai-sdk-integration` |
| 需求来源 | [KNOWN] 用户要求搜索优质开源 SDK，并评估 DeepSeek、Ollama、Qwen 与 OpenAI 格式兼容接入 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 当前状态 | [KNOWN] `LOCAL_VERIFIED`；S1-S9 已实现并通过静态分析、29 项本地测试和 macOS 调试构建 |
| 调研日期 | [KNOWN] 2026-07-14 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 统一 AI 请求传输 | [INFERRED] 用一个受控 SDK 适配器替代 OpenAI、DeepSeek 与 Ollama 的重复手写流解析 | [KNOWN] 标准文本生成与流式翻译在四类端点上通过离线契约测试 |
| [KNOWN] 支持目标厂商 | [KNOWN] OpenAI、DeepSeek、Ollama、Qwen | [KNOWN] 每类端点都有可配置 base URL、模型、认证和超时策略 |
| [KNOWN] 保持项目接口稳定 | [INFERRED] SDK 类型不泄漏到 UI/Controller，继续由项目 `AIProvider` 边界承接 | [KNOWN] 上层翻译状态机不直接依赖候选 SDK 类型 |
| [KNOWN] 降低协议缺陷 | [INFERRED] 把 SSE 分帧、UTF-8 跨 chunk、取消、超时和结构化错误交给经过测试的客户端 | [KNOWN] 任意字节分片、取消、超时和错误映射都有自动化测试 |
| [KNOWN] 支持 function/tool call | [KNOWN] 支持声明函数工具、选择策略、非流式与流式 tool call、tool result 回传和多轮闭环 | [KNOWN] 四类端点均需通过脱敏 fixture 契约测试，tool call ID、名称和参数必须完整重组 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] SDK 调研与选型 | [KNOWN] 比较 `openai_dart`、`dart_openai`、`LangChain.dart`、`ai_sdk_dart` 与可选 `ollama_dart` | [KNOWN] 用户需求与官方仓库/包文档 |
| [INFERRED] OpenAI-compatible 统一适配器 | [INFERRED] OpenAI、DeepSeek、Qwen、Ollama 的标准 Chat Completions/streaming 走同一适配器 | [KNOWN] 三家厂商均提供 OpenAI 兼容入口 |
| [KNOWN] Provider preset | [KNOWN] 提供端点、认证、默认模型和能力开关的显式配置 | [KNOWN] 当前 `ProviderFactory` 已承担同类职责 |
| [KNOWN] 流式文本与辅助内容 | [KNOWN] 保留翻译、例句、电影台词、考试条目的既有项目能力 | [KNOWN] `AIProvider` 现有接口 |
| [KNOWN] 失败与取消语义 | [KNOWN] 超时、认证失败、限流、服务错误、协议错误、取消和部分流失败 | [KNOWN] 项目编码规则 |
| [KNOWN] Tool call 协议适配 | [KNOWN] `tools`、`tool_choice`、assistant `tool_calls`、tool-role result、并行 tool calls 与 streaming delta 重组 | [KNOWN] `openai_dart` 与目标厂商官方接口文档 |
| [KNOWN] DeepSeek 默认模型迁移 | [KNOWN] 从即将停用的 `deepseek-chat` 迁移到仍受支持的模型配置 | [KNOWN] DeepSeek 官方 2026-04-24 变更说明 |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [INFERRED] RAG、Agent、MCP 与工具编排 | [KNOWN] 当前业务是翻译请求，不需要 LangChain 级编排 | [INFERRED] 后续新增复杂编排时重新评估 LangChain.dart 或 AI SDK Dart |
| [INFERRED] 厂商专有推理参数全覆盖 | [KNOWN] DeepSeek `thinking`、Qwen `enable_thinking` 等不是标准 OpenAI 字段 | [INFERRED] 首期承诺标准文本、流式与 function tools；专有字段通过后续能力扩展处理 |
| [KNOWN] 任意本地函数自动执行 | [KNOWN] 用户已确认首期只支持 tool-call 协议闭环 | [KNOWN] 首期只交付受控调用事件和显式 tool result 回传，不内置或自动执行文件、Shell、网络、系统函数 |
| [INFERRED] Ollama 模型拉取、删除和管理 | [KNOWN] 当前产品只要求调用模型 | [INFERRED] 如需模型管理，再引入 `ollama_dart`，避免双 SDK |
| [INFERRED] iOS/Android 局域网 Ollama 完整网络权限适配 | [KNOWN] 该边界尚未获得用户确认 | [INFERRED] 推荐首期只承诺 macOS localhost；移动端远程/局域网另立 Scope |
| [KNOWN] API Key 持久化与迁移 | [KNOWN] 当前设置只更新 Riverpod 内存，安全存储方案尚未确认 | [KNOWN] SDK 接入不得顺带把密钥写入普通 Hive |
| [KNOWN] 真实收费端点自动化调用 | [KNOWN] Scope 与默认测试不得使用生产密钥或产生费用 | [KNOWN] 使用本地 mock/fake server 做协议契约测试 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户选择任一目标厂商并提交文本 | [INFERRED] 通过项目适配层调用统一 SDK | [KNOWN] UI 获得稳定流式文本或结构化失败 | [KNOWN] 四厂商契约矩阵 | P1 | 已确认方案 |
| MAIN-1 | 配置 | [KNOWN] provider、base URL、model、认证、timeout | [INFERRED] 解析成不可变 endpoint 配置并做边界校验 | [KNOWN] 合法配置或明确配置错误 | [KNOWN] preset 与自定义端点测试 | P1 | 已确认方案 |
| MAIN-2 | 请求 | [KNOWN] 翻译或辅助内容请求 | [INFERRED] 转为标准 Chat Completions 消息与参数 | [KNOWN] SDK request | [KNOWN] request-body 契约测试 | P1 | 已确认方案 |
| MAIN-3 | 流处理 | [KNOWN] SSE 字节流 | [INFERRED] SDK 解码并映射为项目 `TranslationResult` | [KNOWN] 增量文本、完成或错误事件 | [KNOWN] 任意 UTF-8/SSE 分片测试 | P1 | 已确认方案 |
| MAIN-TOOL-1 | 工具声明 | [KNOWN] 调用方提供函数名、描述、JSON Schema 和选择策略 | [INFERRED] 映射为标准 `tools`/`tool_choice` 请求 | [KNOWN] 可审计的工具请求 | [KNOWN] 四厂商 request fixture | P1 | 已确认需求 |
| MAIN-TOOL-2 | 工具调用解析 | [KNOWN] 模型返回一个或多个非流式/流式 `tool_calls` | [INFERRED] 按 choice/index/tool-call ID 重组为项目工具调用事件 | [KNOWN] 完整 name、arguments、call ID | [KNOWN] 交错分片与并行调用测试 | P1 | 已确认需求 |
| MAIN-TOOL-3 | 工具结果回传 | [KNOWN] 调用方提交对应 call ID 的执行结果 | [INFERRED] 追加 assistant tool-call message 与 tool-role result 后继续对话 | [KNOWN] 最终文本、下一轮 tool call 或错误 | [KNOWN] 多轮闭环 fixture | P1 | 已确认需求 |
| MAIN-4 | 状态闭环 | [KNOWN] 完成、取消、超时或失败 | [INFERRED] 关闭客户端请求并映射为项目错误 | [KNOWN] 无过期响应覆盖新状态 | [KNOWN] 并发与取消测试 | P1 | 已确认方案 |
| BRANCH-1 | 认证 | [KNOWN] 远程厂商缺少或拒绝 API Key | [KNOWN] 请求前拒绝空密钥或映射 401/403 | [KNOWN] 通用安全错误，不回显密钥/响应原文 | [KNOWN] 认证错误测试 | P1 | 已确认方案 |
| BRANCH-2 | 限流/服务失败 | [KNOWN] 429、5xx、断网、timeout | [INFERRED] 有界重试仅限未产生输出的安全阶段；部分流不自动重放 | [KNOWN] 可重试/不可重试错误分类 | [KNOWN] retry 与 partial-stream 测试 | P1 | 已确认方案 |
| BRANCH-3 | 协议差异 | [KNOWN] 端点拒绝标准字段或返回扩展字段 | [INFERRED] 按 capability 开关裁剪请求；未知字段不影响标准文本解析 | [KNOWN] 明确兼容性错误或降级 | [KNOWN] 厂商 fixture 测试 | P2 | 已确认方案 |
| BRANCH-4 | 模型失效 | [KNOWN] 模型名不存在或已停用 | [KNOWN] 不静默回退到另一计费模型；提示重新选择 | [KNOWN] 模型不可用错误 | [KNOWN] 404/model-not-found fixture | P1 | 已确认方案 |
| BRANCH-5 | Ollama 不可达 | [KNOWN] localhost 服务未启动或移动端无法访问局域网 | [KNOWN] 快速失败并显示可操作提示 | [KNOWN] 不无限等待、不泄漏内部异常 | [KNOWN] connection-refused/timeout 测试 | P2 | 已确认方案 |
| BRANCH-TOOL-1 | 非法工具参数 | [KNOWN] arguments 不是合法 JSON 或不符合声明 Schema | [KNOWN] 不产生调用事件并返回结构化校验错误 | [KNOWN] 不进入调用方执行边界 | [KNOWN] malformed/schema mismatch 测试 | P1 | 已确认方案 |
| BRANCH-TOOL-2 | 未声明工具 | [KNOWN] 模型返回当前请求未声明的 function name | [KNOWN] 拒绝产生调用事件，不按字符串反射调用任意函数 | [KNOWN] undeclared-tool error | [KNOWN] allowlist 测试 | P1 | 已确认方案 |
| BRANCH-TOOL-3 | 重复/过期调用 | [KNOWN] 重试、断流或旧请求产生重复 call ID | [INFERRED] 以 request/call ID 做去重和最新请求隔离 | [KNOWN] 每个有效调用事件最多交付一次 | [KNOWN] retry/race tests | P1 | 已确认方案 |

## 4. 核心规则

| 规则编号 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|
| SDK-001 | [KNOWN] SDK 必须是开源许可证且兼容 Flutter 的 macOS、iOS、Android 目标 | [KNOWN] 候选依赖 | [KNOWN] 可审计依赖结论 | [KNOWN] 不接受只有闭源二进制的客户端 | 已确认 |
| SDK-002 | [KNOWN] 标准兼容路径必须支持可配置 base URL、model、认证、streaming 和 timeout | [KNOWN] endpoint 配置 | [KNOWN] SDK client | [KNOWN] Ollama 认证可为空或使用占位值 | 已确认 |
| SDK-003 | [KNOWN] SDK 类型不得越过 `AIProvider` 边界进入 UI/Controller | [KNOWN] SDK stream/error | [KNOWN] 项目领域事件 | [KNOWN] 适配层内部可直接使用 SDK 类型 | 已确认 |
| SDK-004 | [KNOWN] 取消旧请求必须阻止旧响应更新当前 UI | [KNOWN] 连续提交/清空 | [KNOWN] 仅最新请求可更新状态 | [KNOWN] 单纯取消 Dart StreamSubscription 不足以证明网络请求停止 | 已确认 |
| SDK-005 | [KNOWN] 错误、日志和 UI 不得包含 API Key、原始响应体、堆栈或本地路径 | [KNOWN] SDK exception | [KNOWN] 脱敏错误类别和可操作提示 | [KNOWN] 调试日志默认关闭 | 已确认 |
| SDK-006 | [INFERRED] 厂商专有扩展字段必须使用显式 allowlist，不接受任意 UI Map 直接透传 | [KNOWN] provider options | [KNOWN] 审计可见的请求字段 | [KNOWN] 首期可完全不开放专有字段 | 已确认 |
| SDK-007 | [KNOWN] 缓存键必须加入 provider、base URL 逻辑标识、model、from、to 和请求选项 | [KNOWN] 翻译请求 | [KNOWN] 不跨模型误命中缓存 | [KNOWN] 不把 API Key 放入缓存键 | 已确认 |
| SDK-008 | [KNOWN] “模型请求调用工具”不等于“模型执行工具”；SDK 只负责协议，实际执行必须由应用控制 | [KNOWN] assistant tool call | [KNOWN] 项目工具调用事件或受控执行结果 | [KNOWN] 禁止按模型输出直接反射调用函数 | 已确认 |
| SDK-009 | [KNOWN] 工具名称必须来自当前请求显式声明，arguments 必须先完成 JSON 解析和 Schema/边界校验 | [KNOWN] tool call name/arguments | [KNOWN] 合法的 typed call event 或结构化拒绝 | [KNOWN] 不信任模型生成参数 | 已确认 |
| SDK-010 | [KNOWN] tool call ID 必须与 tool-role result 一一关联；未知、重复和过期 ID 必须拒绝 | [KNOWN] call ID 与执行结果 | [KNOWN] 可追溯多轮对话 | [KNOWN] 并行调用需分别关联 | 已确认 |

## 5. 高严谨业务系统风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 领域业务逻辑严谨性 | [KNOWN] 是 | [KNOWN] 多厂商返回必须保持翻译语义和辅助内容结构 | [KNOWN] 专有推理能力是否首期需要 | P2 |
| 金额与关键数值精度 | [KNOWN] 间接涉及 | [INFERRED] 重试可能重复产生计费请求 | [KNOWN] 是否展示/限制请求成本待后续产品定义 | P1 |
| 交易与数据一致性 | [KNOWN] 否 | [KNOWN] 无数据库交易 | [KNOWN] 无 | NONE |
| 状态流转 | [KNOWN] 是 | [KNOWN] loading/streaming/complete/error 与取消存在 | [KNOWN] partial stream 的 UI 口径 | P1 |
| 幂等与并发 | [KNOWN] 是 | [KNOWN] 用户连续输入会取消旧订阅 | [KNOWN] SDK 网络级取消必须验证 | P1 |
| 工具副作用与幂等 | [KNOWN] 首期不直接涉及执行 | [KNOWN] SDK 层只产生调用事件，不执行工具 | [KNOWN] 调用方执行器必须另立 Scope | P1 |
| 权限与审计 | [KNOWN] 是 | [KNOWN] API Key 与调试日志受项目规则约束 | [KNOWN] 安全存储另立方案 | P1 |
| 隐私与适用监管/合规 | [KNOWN] 是 | [KNOWN] 用户文本会发送到所选远程厂商 | [KNOWN] 用户告知、同意和数据处理边界待产品确认 | P1 |
| 生产变更与回滚 | [KNOWN] 是 | [INFERRED] SDK 替换影响全部 AI 请求 | [KNOWN] 需要 adapter seam 与按 provider 回滚路径 | P1 |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| 依赖 | `pubspec.yaml`, `pubspec.lock` | [KNOWN] 新增并锁定选定 SDK；保留或移除 Dio 需按全仓使用情况决定 | P2 |
| AI 抽象 | `lib/core/ai/ai_provider.dart` | [INFERRED] 补充结构化错误、取消和 capability 边界 | P1 |
| Tool 抽象 | [KNOWN] 待新增 `lib/core/ai/tools/` 或等价模块 | [INFERRED] 定义工具 Schema、选择策略、调用事件、结果和受控 registry 边界 | P1 |
| Provider | `lib/core/ai/*_provider.dart` | [INFERRED] OpenAI、DeepSeek、Ollama、custom 收敛为兼容适配器；Claude 保持独立 | P1 |
| 工厂 | `lib/core/ai/provider_factory.dart` | [KNOWN] 新增 Qwen preset，更新 DeepSeek 默认模型和 Ollama compatible URL | P1 |
| 配置 | `lib/core/config/ai_config.dart` | [INFERRED] 可能增加 protocol/capabilities/timeouts；Hive schema 迁移需兼容旧字段 | P1 |
| 状态 | `lib/features/translate/logic/translate_controller.dart` | [INFERRED] 接入网络级取消、最新请求保护和结构化错误 | P1 |
| 设置 | `lib/features/settings/ui/settings_page.dart` | [KNOWN] 展示 Qwen 与 endpoint/model 校验；不在本需求中新增普通 Hive 密钥持久化 | P1 |
| 缓存 | `lib/core/cache/translation_cache.dart` | [KNOWN] 当前 key 只使用输入文本，需要避免跨 provider/model 污染 | P1 |
| 测试 | `test/core/ai/`, `test/features/translate/` | [KNOWN] 当前只有占位 widget test，需要新增 mock-server 契约与状态机测试 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| [KNOWN] 四厂商请求 fixture | 契约测试 | P1 | [KNOWN] 不使用真实密钥或收费端点 |
| [KNOWN] UTF-8 与 SSE 任意分片 | 流测试 | P1 | [KNOWN] 当前代码对每个 chunk 独立 `utf8.decode` 并按换行切分 |
| [KNOWN] 网络级取消与 stale response | 并发测试 | P1 | [KNOWN] 当前只取消 StreamSubscription |
| [KNOWN] 认证、限流、超时、5xx、断流 | 错误测试 | P1 | [KNOWN] 当前多处吞异常或把 `$e` 写进结果 |
| [KNOWN] DeepSeek 新模型 preset | 配置测试 | P1 | [KNOWN] `deepseek-chat` 将于 2026-07-24 停用 |
| [KNOWN] 缓存隔离 | 数据测试 | P1 | [KNOWN] 当前缓存 key 未包含 provider/model |
| [KNOWN] macOS/iOS/Android 构建 | 平台验证 | P1 | [KNOWN] 新 SDK 必须为纯 Dart 或声明目标平台兼容 |
| [KNOWN] Tool call 非流式与流式重组 | 协议测试 | P1 | [KNOWN] 覆盖单个、并行、交错 delta、空 content 和 `finish_reason=tool_calls` |
| [KNOWN] 工具参数与分派安全 | 安全测试 | P1 | [KNOWN] 覆盖非法 JSON、Schema mismatch、未知名称、重复/过期 call ID |
| [KNOWN] 工具结果多轮回传 | 状态测试 | P1 | [KNOWN] 覆盖 assistant tool_calls + tool result + final answer 闭环 |

## 8. 已确认事项

| 事项 | 风险等级 | 影响 | 确认结论 | 确认来源 |
|---|---|---|---|---|
| [KNOWN] function/tool call 首期执行边界 | P1 | [KNOWN] 排除执行器、系统权限与工具副作用 | [KNOWN] 只交付 tools 请求、tool_calls 解析、受控调用事件和显式 tool result 回传；不自动执行文件、Shell、网络或系统函数 | [KNOWN] 用户于 2026-07-14 确认 |
