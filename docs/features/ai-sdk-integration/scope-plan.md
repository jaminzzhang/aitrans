# Scope 需求梳理、准入与 TDD 计划

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `TDD_INPUT_READY` |
| 最高风险等级 | [KNOWN] P1 |
| 一句话依据 | [KNOWN] SDK、厂商、平台、tool-call 协议、非执行边界、风险处理和验证切片均已确认或明确排除 |
| 下一步建议 | [KNOWN] 按 S1 至 S9 顺序转 `hicode:tdd`，每个切片独立执行 RED-GREEN-REFACTOR |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| 项目入口与规则 | `AGENTS.md`, `docs/rules/coding_rules.md` | [KNOWN] 是 | [KNOWN] 强制边界校验、timeout、取消、错误脱敏和行为测试 | [KNOWN] 无 |
| 项目上下文 | `docs/PROJ_CONTEXT.md`, `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 是 | [KNOWN] Flutter 客户端、多厂商配置、隐私与缓存风险 | [KNOWN] 负责人待确认 |
| 产品材料 | `aitrans-prd.md` | [KNOWN] 是 | [KNOWN] 翻译、辅助内容、macOS 快捷调用、三平台目标 | [KNOWN] SDK 不是原 PRD 明示项 |
| 当前实现 | `lib/core/ai/`, `lib/core/config/`, translation controller/cache | [KNOWN] 是 | [KNOWN] 手写 Dio Provider、重复流解析、Qwen 缺失、取消与缓存隔离不足 | [KNOWN] 无真实服务兼容测试 |
| 当前测试 | `test/widget_test.dart` | [KNOWN] 是 | [KNOWN] 只有占位断言 | [KNOWN] 无 AI 契约和状态测试 |
| 候选 SDK | 官方仓库与 pub.dev 页面 | [KNOWN] 是 | [KNOWN] 许可证、平台、接口、流式、配置和采用度证据 | [KNOWN] 未执行本地依赖 spike |
| 厂商协议 | DeepSeek、Ollama、阿里云百炼官方文档 | [KNOWN] 是 | [KNOWN] 三家均提供 OpenAI 兼容入口 | [KNOWN] 专有字段的跨 SDK 完整兼容未验证 |
| Tool call 协议 | SDK 与三家厂商官方文档 | [KNOWN] 是 | [KNOWN] `tools`、`tool_choice`、`tool_calls`、tool result 与 streaming 有官方证据 | [KNOWN] 已确认应用只交付调用事件，不自动执行函数 |

### 主要来源

- [KNOWN] [`openai_dart` 官方包页](https://pub.dev/packages/openai_dart) 与 [源码仓库](https://github.com/davidmigloz/ai_clients_dart/tree/main/packages/openai_dart)
- [KNOWN] [`dart_openai` 官方包页](https://pub.dev/packages/dart_openai) 与 [源码仓库](https://github.com/anasfik/openai)
- [KNOWN] [`LangChain.dart` 官方包页](https://pub.dev/packages/langchain) 与 [源码仓库](https://github.com/davidmigloz/langchain_dart)
- [KNOWN] [`ai_sdk_dart` 官方包页](https://pub.dev/packages/ai_sdk_dart) 与 [源码仓库](https://github.com/codenameakshay/ai_sdk_dart)
- [KNOWN] [`ollama_dart` 官方包页](https://pub.dev/packages/ollama_dart)
- [KNOWN] [DeepSeek OpenAI-compatible 文档](https://api-docs.deepseek.com/)
- [KNOWN] [DeepSeek 2026-04-24 变更记录](https://api-docs.deepseek.com/updates/)
- [KNOWN] [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility)
- [KNOWN] [阿里云百炼 OpenAI 兼容调用文档](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope)
- [KNOWN] [`openai_dart` tool calling 示例](https://pub.dev/packages/openai_dart)
- [KNOWN] [DeepSeek Function Calling 文档](https://api-docs.deepseek.com/guides/function_calling/)
- [KNOWN] [Ollama OpenAI Tools 兼容说明](https://docs.ollama.com/api/openai-compatibility)
- [KNOWN] [Qwen Function Calling 文档](https://help.aliyun.com/zh/model-studio/qwen-function-calling)

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | [KNOWN] `TDD_INPUT_READY` |
| 需求目标 | [KNOWN] 清楚：选型并设计一个支持 OpenAI、DeepSeek、Ollama、Qwen 的可靠 AI 请求 SDK 接入 |
| 范围 | [KNOWN] SDK、厂商、标准文本/流式、tool call 协议、macOS Ollama 与非自动执行边界均已确认 |
| 验收标准 | [KNOWN] 已固化为四厂商协议、流式、错误、取消、缓存、tool-call 安全和多轮状态测试 |
| 关键术语 | [KNOWN] “tool call/function call”是模型生成结构化函数调用意图；[KNOWN] 它不表示模型或 SDK 已执行函数 |
| 影响范围 | [KNOWN] 已定位到依赖、AI 抽象、Provider、工厂、配置、Controller、设置、缓存和测试 |
| P0/P1 风险 | [KNOWN] 无 P0；有 DeepSeek 默认模型停用、密钥/隐私、取消、重复计费、缓存串用、工具参数注入与重复副作用等 P1 |

## 4. 候选 SDK 评估

| 候选 | 官方证据 | 优点 | 硬伤/代价 | 结论 |
|---|---|---|---|---|
| `openai_dart` 7.0.1 | [KNOWN] MIT、纯 Dart、全平台、custom base URL、typed API、streaming、tool calling、retry、interceptor、结构化异常；pub.dev 显示 129 likes、160 points、36k downloads | [INFERRED] 与当前翻译和 tool call 请求形状最匹配；依赖少；可保留项目 `AIProvider` seam | [KNOWN] `ChatCompletionCreateRequest` 没有通用 `extraBody`；有 `topK`/`reasoningEffort`，但不能直接证明覆盖 DeepSeek `thinking` 等所有专有字段 | [KNOWN] 已确认采用，限定为标准兼容能力 |
| `dart_openai` 6.1.1 | [KNOWN] MIT、custom base URL、streaming、timeout；pub.dev 显示 575 likes、140 points、21.1k downloads | [INFERRED] 社区采用度高、API 简单 | [KNOWN] 通过全局 `OpenAI.apiKey/baseUrl` 配置；[INFERRED] 多 Provider 并存或并发切换更易出现共享状态污染 | [INFERRED] 不选作多厂商核心 |
| `LangChain.dart` + `langchain_openai`/`langchain_ollama` | [KNOWN] MIT、OpenAI-compatible 与 Ollama 独立集成、streaming；pub.dev 显示 300 likes、160 points、3.13k downloads | [INFERRED] 若未来进入 RAG、Agent、工具链，可直接扩展 | [KNOWN] 引入 chain/model 抽象和更多依赖；[INFERRED] 对当前简单翻译传输明显过重 | [INFERRED] 当前不选，复杂编排时重评 |
| `ai_sdk_dart` 1.2.0 | [KNOWN] MIT、provider registry、OpenAI-compatible 核心、Ollama 包、streaming、typed errors、任意 provider options 透传；pub.dev 显示 150 points | [INFERRED] 功能模型最贴近“统一多 Provider SDK” | [KNOWN] 发布仅 12 天，pub.dev 显示 0 likes、266 downloads | [INFERRED] 架构候选，但成熟度不足以直接成为当前基线 |
| `ollama_dart` 2.4.0 | [KNOWN] MIT、纯 Dart、原生 Ollama chat/streaming/tool/embedding/model management；pub.dev 显示 88 likes、160 points、8.97k downloads | [INFERRED] Ollama 原生能力最完整 | [KNOWN] 只能解决 Ollama；与统一 OpenAI-compatible SDK 并用会形成双协议/双错误模型 | [INFERRED] 仅在明确需要模型管理时追加 |

### 厂商兼容矩阵

| 厂商 | 官方兼容入口 | 标准文本/streaming | 认证 | 专有差异 | 推荐首期处理 |
|---|---|---|---|---|---|
| OpenAI | [KNOWN] `https://api.openai.com/v1` | [KNOWN] 原生支持 | [KNOWN] Bearer API key | [KNOWN] Chat Completions 支持 function tools；Responses API 不属于本次必需能力 | [INFERRED] `openai_dart` 标准 adapter |
| DeepSeek | [KNOWN] `https://api.deepseek.com` | [KNOWN] OpenAI Chat Completions compatible | [KNOWN] Bearer API key | [KNOWN] 支持 function tools、tool choice、tool result 和并行调用；strict mode 需要 beta endpoint；legacy 模型将于 2026-07-24 停用 | [INFERRED] 首期使用非 strict 标准字段，preset 改为 `deepseek-v4-flash` |
| Qwen/百炼 | [KNOWN] `https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1` 等区域 endpoint | [KNOWN] OpenAI compatible | [KNOWN] Bearer API key | [KNOWN] 文本模型支持 function calling，但模型族能力不同；发起调用和回传结果的轮次均需保留 `tools` | [INFERRED] 文本模型 preset + 厂商 fixture 验证 |
| Ollama | [KNOWN] `http://localhost:11434/v1/` | [KNOWN] `/v1/chat/completions` 支持 streaming 与 tools | [KNOWN] SDK 可能要求 key，但 Ollama 本地会忽略占位 key | [KNOWN] OpenAI API 仅部分兼容，且实际工具能力取决于本地模型；localhost 在移动端不是桌面主机 | [INFERRED] macOS 首期走标准 adapter，并校验所选模型 capability |

## 5. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. `openai_dart` 统一标准兼容层 | [KNOWN] 已确认 | [INFERRED] 一个 `OpenAICompatibleProvider` + provider presets + 项目错误/取消/tool-call 适配 | [INFERRED] capability 开关裁剪字段，专有字段延期；Claude 保持独立 | [KNOWN] 首期 OpenAI/DeepSeek/Qwen/桌面 Ollama 文本、流式与 function tools 协议；不自动执行工具 | [INFERRED] 最小依赖、最少重复代码、可回滚、社区证据较强 | [KNOWN] 不覆盖所有厂商专有字段或任何内置工具执行器 | [KNOWN] 用户已确认 SDK 与执行边界 |
| B. `ai_sdk_dart` 多 Provider 框架 | [INFERRED] 备选 | [INFERRED] provider registry 统一模型调用，Ollama 用专用 provider | [INFERRED] providerOptions 透传专有字段 | [INFERRED] 可更快扩展工具/结构化输出 | [INFERRED] 接口理念最好 | [KNOWN] 发布与采用时间极短，供应链和 API 稳定性证据不足 | [INFERRED] 不作为当前生产基线 |
| C. `LangChain.dart` | [INFERRED] 不推荐 | [INFERRED] 用 ChatModel 抽象接各 Provider | [INFERRED] 使用集成包处理 Ollama/OpenAI-compatible | [INFERRED] 同时引入 chain/agent 能力 | [INFERRED] 未来 RAG/Agent 扩展最强 | [INFERRED] 当前功能过度设计、迁移面更大 | [KNOWN] 与当前业务目标不匹配 |
| D. 保留 Dio 手写实现 | [INFERRED] 不推荐 | [KNOWN] 每个厂商独立 Provider | [KNOWN] 各自维护流解析和错误处理 | [KNOWN] 无新依赖 | [KNOWN] 修改最少 | [KNOWN] 已存在重复、吞异常、UTF-8/SSE 分片和取消风险 | [KNOWN] 不能实现“优质 SDK 接入”目标 |

## 6. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 选择目标 Provider 后提交翻译/辅助请求 | [INFERRED] 项目 adapter 调用统一 SDK | [KNOWN] 可取消的文本流或结构化错误 | [KNOWN] 不直接暴露 SDK 类型 | [KNOWN] 四厂商契约矩阵 | P1 |
| MAIN-1 | Endpoint 配置 | [KNOWN] provider/baseUrl/model/key/timeouts | [INFERRED] preset + 自定义覆盖 + capability 校验 | [KNOWN] 不可变 client config | [KNOWN] 不持久化 key | [KNOWN] 配置 table tests | P1 |
| MAIN-2 | Client 生命周期 | [KNOWN] ProviderFactory 创建 Provider | [INFERRED] 每个配置实例拥有独立 client；配置变化时关闭旧 client | [KNOWN] 无全局可变 SDK 状态 | [KNOWN] Claude 仍走独立协议 | [KNOWN] 多 Provider 并发测试 | P1 |
| MAIN-3 | 请求映射 | [KNOWN] translate/examples/quotes/exams | [INFERRED] 共享 prompt builder 与 Chat Completions request mapper | [KNOWN] 标准请求体 | [KNOWN] 专有字段首期关闭 | [KNOWN] golden request tests | P1 |
| MAIN-4 | 响应映射 | [KNOWN] SDK SSE stream | [INFERRED] 转为项目增量/完成/错误事件 | [KNOWN] 上层状态保持稳定 | [KNOWN] 不把 reasoning 当翻译正文 | [KNOWN] split-stream fixtures | P1 |
| MAIN-5 | 终止闭环 | [KNOWN] complete/cancel/timeout/error | [INFERRED] abort HTTP + close stream + latest-request guard | [KNOWN] 单一终态 | [KNOWN] partial stream 不自动重试 | [KNOWN] race tests | P1 |
| MAIN-6 | 缓存闭环 | [KNOWN] 成功翻译 | [INFERRED] 用 provider/model/language/options/text 构建缓存身份 | [KNOWN] 同配置命中、跨配置隔离 | [KNOWN] key 不含密钥 | [KNOWN] cache tests | P1 |
| MAIN-7 | Tool 声明 | [KNOWN] 调用方提供工具 Schema 与选择策略 | [INFERRED] 映射为标准 `tools`/`tool_choice` | [KNOWN] 可审计请求体 | [KNOWN] 只支持 function 类型 | [KNOWN] 四厂商 golden requests | P1 |
| MAIN-8 | Tool-call 重组 | [KNOWN] 非流式或流式返回一个或多个 tool calls | [INFERRED] 按 index/call ID 累积 name 与 arguments | [KNOWN] 项目 tool-call 事件 | [KNOWN] content 可为空，arguments 可跨 chunk | [KNOWN] interleaved stream fixtures | P1 |
| MAIN-9 | Tool result 闭环 | [KNOWN] 调用方返回 call ID 对应结果 | [INFERRED] 追加 assistant/tool messages 并继续请求 | [KNOWN] 最终文本或下一轮调用 | [KNOWN] 设置最大轮次，防止无限循环 | [KNOWN] multi-turn tests | P1 |
| BRANCH-1 | 无效配置 | [KNOWN] 空 base/model 或远程 key | [KNOWN] 请求前失败 | [KNOWN] typed configuration error | [KNOWN] Ollama key 可使用内部占位值 | [KNOWN] boundary tests | P1 |
| BRANCH-2 | API failure | [KNOWN] 401/403/404/429/5xx/timeout | [INFERRED] 映射为安全错误类别与重试建议 | [KNOWN] UI 可操作错误 | [KNOWN] 不显示响应原文 | [KNOWN] status fixtures | P1 |
| BRANCH-3 | 模型停用 | [KNOWN] DeepSeek legacy model | [KNOWN] preset 不再使用 legacy 名称；自定义旧值明确报错 | [KNOWN] 不静默换模型 | [KNOWN] 用户仍可自定义 | [KNOWN] migration tests | P1 |
| BRANCH-4 | 本地服务不可达 | [KNOWN] Ollama 未启动/地址不可达 | [KNOWN] connect timeout 后给本地服务提示 | [KNOWN] 错误终态 | [KNOWN] 移动 LAN 延期 | [KNOWN] connection tests | P2 |
| BRANCH-5 | 结构化内容失败 | [KNOWN] 模型返回非 JSON 辅助内容 | [INFERRED] 返回解析错误而不是空列表冒充成功 | [KNOWN] UI 显示可重试状态 | [KNOWN] 首期不依赖厂商 JSON Schema 全兼容 | [KNOWN] malformed fixtures | P2 |
| BRANCH-6 | Tool 参数无效 | [KNOWN] arguments 非法或违反 Schema | [KNOWN] 拒绝分派并返回 typed validation error | [KNOWN] 无副作用 | [KNOWN] 模型输出不可信 | [KNOWN] fuzz/schema tests | P1 |
| BRANCH-7 | Tool 未声明/重复 | [KNOWN] name 不在当前请求声明集或 call ID 已处理/已过期 | [KNOWN] 拒绝产生调用事件并返回结构化错误 | [KNOWN] 不反射调用、不重复交付事件 | [KNOWN] 首期无工具执行器 | [KNOWN] allowlist/idempotency tests | P1 |

## 7. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] DeepSeek legacy 默认模型临近停用 | P1 | [KNOWN] 官方公告 2026-07-24 停用；项目仍默认 `deepseek-chat` | [KNOWN] 作为第一 TDD 切片先迁移 preset 并加配置测试 | [KNOWN] 研发/产品 |
| [KNOWN] 用户文本发送到远程厂商 | P1 | [KNOWN] 当前产品直接请求第三方 API | [KNOWN] 在产品层补充数据去向告知；本需求至少不得记录原文日志 | [KNOWN] 产品/隐私负责人 |
| [KNOWN] API Key 安全存储未解决 | P1 | [KNOWN] 当前只在内存；Hive model 包含 apiKey | [KNOWN] 本需求禁止把 key 接入普通 Hive；安全持久化另立 Scope | [KNOWN] 安全/研发负责人 |
| [KNOWN] 取消不等于网络 abort | P1 | [KNOWN] 当前 controller 只取消 StreamSubscription | [KNOWN] 选用并验证 SDK abort 能力，加入 stale-response guard | [KNOWN] 研发负责人 |
| [KNOWN] 重试可能重复计费 | P1 | [KNOWN] AI 请求是计费外部调用 | [KNOWN] 仅在首字节前对明确可重试错误做有界重试 | [KNOWN] 产品/研发负责人 |
| [KNOWN] 缓存跨 Provider/模型串用 | P1 | [KNOWN] 当前 cache key 只依赖源文本 | [KNOWN] SDK 接入同期修复 cache identity | [KNOWN] 研发负责人 |
| [KNOWN] `ai_sdk_dart` 供应链成熟度不足 | P2 | [KNOWN] 发布 12 天、0 likes、266 downloads | [KNOWN] 不作为当前默认；可保留隔离 spike | [KNOWN] 研发负责人 |
| [KNOWN] 模型生成的工具参数不可信 | P1 | [KNOWN] DeepSeek 官方明确要求应用验证 arguments；其他端点同样返回模型生成 JSON | [KNOWN] 强制 JSON/Schema/业务边界校验，未知工具拒绝 | [KNOWN] 研发/安全负责人 |
| [KNOWN] 工具调用事件可能重复交付 | P1 | [INFERRED] 重试、断流、并行 call 和 stale response 可重复生成事件 | [KNOWN] call ID 去重、轮次上限、网络重试与调用事件重放分离；首期不执行工具 | [KNOWN] 研发负责人 |

[KNOWN] P1 阻断状态：无未关闭 P1 阻断问题；DeepSeek 迁移、取消、重试、缓存和 tool-call 校验均已映射到 S1-S9，密钥持久化与工具执行器被明确排除，远程文本不得进入日志或测试 fixture。

## 8. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| [KNOWN] 方案 A 与首期标准文本/流式、macOS localhost Ollama | [KNOWN] 已确认 | [KNOWN] 采用 `openai_dart` 兼容适配层 | [KNOWN] 用户已明确同意 | [KNOWN] SDK 与平台主路径已固定 | [KNOWN] 用户/产品与研发负责人 |
| [KNOWN] function/tool call 是否包含应用自动执行已注册函数 | [KNOWN] 已确认 | [KNOWN] 首期仅提供协议闭环与受控调用事件，不自动执行文件、Shell、网络或系统工具 | [KNOWN] 用户明确确认推荐边界 | [KNOWN] Tool executor、系统权限和副作用审计排除出首期 | [KNOWN] 用户于 2026-07-14 确认 |

## 9. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | [KNOWN] `TDD_INPUT_READY` |
| 下一步路由 | [KNOWN] 按 S1 至 S9 顺序转 `hicode:tdd` |
| 明确排除节点 | [KNOWN] 移动端 Ollama 网络权限、厂商专有推理字段、API Key 安全持久化、任何工具自动执行器 |

### 最终 TDD 切片

| 任务 | 目标与设计树节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点与测试重点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|---|---|
| S1 Provider preset 与模型迁移 | [KNOWN] 固化四厂商 endpoint/model/capability；MAIN-1、BRANCH-3 | [KNOWN] 官方 endpoint、已确认 macOS Ollama、当前 `ProviderFactory` | [KNOWN] 内：OpenAI、DeepSeek V4、Qwen 自定义 Workspace endpoint、Ollama `/v1`；外：移动 LAN、自动发现模型 | `provider_factory.dart`, `ai_config.dart`, config tests | [KNOWN] 先写四厂商 table tests、legacy DeepSeek 拒绝和自定义覆盖测试 | [KNOWN] focused tests + analyze | [KNOWN] Qwen Workspace 规则需要硬编码或官方模型名再次变化时返回 Scope |
| S2 SDK 隔离 spike | [KNOWN] 证明 `openai_dart` 满足请求、stream、timeout、abort 和 typed error；MAIN-2/3 | [KNOWN] 选型证据与本地 fake server | [KNOWN] 内：仅测试适配 seam；外：替换现有 Provider、真实收费端点 | `pubspec.yaml`, `test/core/ai/fixtures/`, spike adapter | [KNOWN] 先写 fake-server RED tests，覆盖任意 UTF-8/SSE 分片和 abort | [KNOWN] focused tests；依赖锁定可重现 | [KNOWN] 任一 P1 能力无法实现时停止并返回 SDK 选型 Scope |
| S3 统一兼容 Provider | [KNOWN] 用一个 adapter 承接标准文本与流式调用；MAIN-3/4、BRANCH-1/2/5 | [KNOWN] S1 配置与 S2 spike 结论 | [KNOWN] 内：OpenAI-compatible Chat Completions；外：Claude、Responses API、专有推理字段 | `ai_provider.dart`, compatible provider, existing provider files | [KNOWN] 先写 Provider 行为契约，覆盖成功、401/403/404/429/5xx、timeout、断流、畸形内容 | [KNOWN] contract tests + existing behavior regression | [KNOWN] SDK 类型必须泄漏到 UI 才能实现时停止并返回 Scope |
| S4 Controller 取消与状态保护 | [KNOWN] 保证网络取消和 latest-request 状态一致；MAIN-5 | [KNOWN] S3 可取消 stream、当前 controller | [KNOWN] 内：连续请求、clear、timeout、partial stream；外：后台任务队列 | `translate_controller.dart`, controller tests | [KNOWN] 先写旧流晚到、取消后无更新、单一终态 race tests | [KNOWN] deterministic fake stream tests | [KNOWN] 无法证明底层 abort 时不得把订阅取消视为完成 |
| S5 缓存身份修复 | [KNOWN] 隔离 provider/model/language/options/text 缓存；MAIN-6 | [KNOWN] 当前只按文本构建 key 的实现 | [KNOWN] 内：新 identity 与旧 key 安全失效；外：缓存加密/保留策略 | `translation_cache.dart`, cache model/tests | [KNOWN] 先写同文本跨配置不命中及同配置命中测试 | [KNOWN] focused cache tests + migration fixture | [KNOWN] 必须误读旧 key 或破坏已有 Hive schema 时停止并明确迁移方案 |
| S6 设置 UI 与回归 | [KNOWN] 暴露 Qwen 与能力校验并保护现有翻译 UX；ROOT、MAIN-1 | [KNOWN] S1/S3 接口与现有设置页面 | [KNOWN] 内：provider/model/base URL 校验、安全错误；外：明文 key 持久化 | `settings_page.dart`, translate UI/widget tests | [KNOWN] 先写 Qwen 选择、字段校验和现有四类内容回归测试 | [KNOWN] widget tests + Flutter analyze/build | [KNOWN] 需要持久化 API Key 时停止并另立安全存储 Scope |
| S7 Tool schema 与请求映射 | [KNOWN] 支持标准 function tool 声明和选择策略；MAIN-7 | [KNOWN] 已确认协议范围与四厂商文档 | [KNOWN] 内：function、JSON Schema、none/auto/required/named；外：厂商 built-in tools、自动执行 | tool domain types, request mapper, contract tests | [KNOWN] 先写四厂商 golden request、非法 Schema 和 capability 拒绝测试 | [KNOWN] 序列化结果与脱敏 fixture 精确比对 | [KNOWN] 必需字段只能通过任意 `extraBody` 透传时返回 Scope 审核 allowlist |
| S8 Tool-call 流重组 | [KNOWN] 安全重组单个及并行 tool calls；MAIN-8、BRANCH-6 | [KNOWN] S7 类型与 SDK streaming events | [KNOWN] 内：非流式、交错 delta、空 content、参数 JSON/Schema 校验；外：调用函数 | tool accumulator/parser, stream fixtures | [KNOWN] 先写 call ID/name/arguments 跨 chunk、非法 JSON、Schema mismatch tests | [KNOWN] property/fixture tests；每个合法事件仅交付一次 | [KNOWN] 任一端点无法稳定保留 call ID/name/arguments 时返回 Scope |
| S9 Tool result 多轮闭环 | [KNOWN] 接收显式 tool result 并继续对话；MAIN-9、BRANCH-7 | [KNOWN] S8 typed call event 与用户确认的非执行边界 | [KNOWN] 内：assistant tool_calls、tool-role result、并行关联、轮次上限；外：ToolRegistry/executor、文件/Shell/网络/系统操作 | conversation state, tool result API, state tests | [KNOWN] 先写未知、重复、过期 call ID、最大轮次和 final-answer tests | [KNOWN] state-machine tests + four-provider fixtures | [KNOWN] 任何需求要求 SDK 自动执行工具时停止并另立 Scope |

## 10. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1 | [KNOWN] 四厂商 preset 与自定义覆盖 | table test | P1 | [KNOWN] 无密钥 fixture | S1 |
| MAIN-2/3 | [KNOWN] OpenAI-compatible request body | mock HTTP contract | P1 | [KNOWN] 官方示例的脱敏 fixture | S2/S3 |
| MAIN-4 | [KNOWN] 中文字符跨 byte chunk、SSE 跨 line chunk | stream contract | P1 | [KNOWN] 人工分片 fixture | S2/S3 |
| MAIN-5 | [KNOWN] 连续输入取消旧请求、旧流晚到 | concurrency | P1 | [KNOWN] controllable fake stream | S4 |
| BRANCH-2 | [KNOWN] 401/403/404/429/5xx/timeout/断流 | error mapping | P1 | [KNOWN] 本地 status fixtures | S3 |
| BRANCH-3 | [KNOWN] legacy DeepSeek model | migration | P1 | [KNOWN] 旧/新配置 fixture | S1 |
| MAIN-6 | [KNOWN] 同文本不同 provider/model/language | cache identity | P1 | [KNOWN] 无真实用户文本 | S5 |
| ROOT | [KNOWN] 现有翻译和辅助内容行为 | integration/widget | P1 | [KNOWN] fake `AIProvider` | S6 |
| MAIN-7 | [KNOWN] tools/tool_choice 请求映射与能力检查 | contract | P1 | [KNOWN] 无副作用函数 Schema | S7 |
| MAIN-8 | [KNOWN] 单个/并行 tool calls 的非流式与任意 SSE 分片 | stream contract | P1 | [KNOWN] 人工交错 call fixtures | S8 |
| MAIN-9 | [KNOWN] assistant tool_calls + tool result + final answer | state machine | P1 | [KNOWN] 确定性 fake tool result | S9 |
| BRANCH-6/7 | [KNOWN] 非法参数、未知工具、重复/过期 call ID、轮次上限 | security/concurrency | P1 | [KNOWN] 恶意和异常 fixture | S8/S9 |

## 11. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | [INFERRED] 否，当前阶段 |
| 判断理由 | [INFERRED] 推荐方案把第三方 SDK 封装在现有 `AIProvider` seam 内，替换成本可控，不满足“难逆”条件 |
| 触发 ADR 的条件 | [KNOWN] 若决定让 SDK 类型成为全项目公共接口，或引入 LangChain/AI SDK 作为长期编排平台，则需要 ADR |

## 12. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | 已更新 | [KNOWN] 增加 OpenAI-compatible endpoint、provider preset、tool call/result 与非执行边界 | [KNOWN] 已按用户确认写入 | 已确认 |
| `docs/PROJ_CONTEXT.md` | 已更新 | [KNOWN] Feature 索引增加 `ai-sdk-integration`，记录 SDK、厂商、tool-call 边界与风险 | [KNOWN] 已按用户确认写入 | 已确认 |
| `docs/adr/` | 跳过 | [INFERRED] 当前不满足 ADR 难逆条件 | [KNOWN] 不创建草稿 | 已评估 |

## 13. 文档处理清单

| 文档 | 处理结果 |
|---|---|
| `docs/features/ai-sdk-integration/feature_context.md` | [KNOWN] 已创建 |
| `docs/features/ai-sdk-integration/scope-plan.md` | [KNOWN] 已更新；结论为 `TDD_INPUT_READY` |
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 已更新 tool-call 术语与确认规则 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 已更新 Feature 索引和外部依赖边界 |
| `docs/adr/` | [KNOWN] 未创建 ADR |
