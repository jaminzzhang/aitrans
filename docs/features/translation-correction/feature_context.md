# feature_context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] 翻译输入自动纠错提示 |
| feature-id | [KNOWN] `translation-correction` |
| 需求来源 | [KNOWN] 用户要求输入 text 有错误时由大模型更正，在译文区域提示更正结果并同时显示译文 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 当前状态 | [KNOWN] `TDD_INPUT_READY`；feature-id、输入框与主译文行为、纠错范围、enrichment adopted source 已由用户确认 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 识别并提示输入错误 | [KNOWN] 大模型判断输入存在错误时返回更正文本 | [INFERRED] 译文区明确区分更正提示和译文，用户能看到模型实际采用的文本 |
| [KNOWN] 始终提供译文 | [KNOWN] 有纠错时也必须显示译文内容 | [INFERRED] 纠错字段缺失或无错误时仍能显示正常译文 |
| [INFERRED] 控制误改风险 | [INFERRED] 纠错只应修复语言错误，不应静默改变用户意图 | [INFERRED] 无实质变化不显示提示；模型无法确定时保留原文翻译 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] 主翻译请求返回纠错信息 | [INFERRED] 纠错与译文使用同一请求和同一结果契约，避免额外请求造成不一致 | [KNOWN] 用户要求由大模型更正并同时展示译文 |
| [KNOWN] 译文区域展示 | [KNOWN] 有更正时展示更正结果，并保留主译文、词性、读音和多词义层级 | [KNOWN] 用户明确指定译文区域 |
| [INFERRED] Typed 结果模型 | [INFERRED] 将更正文本与译文分字段表达，避免 UI 从任意自然语言猜测 | [KNOWN] 项目规则要求 typed request/result/state |
| [INFERRED] 缓存契约升级 | [INFERRED] 缓存必须区分新旧输出协议，缓存命中也要还原同样的纠错展示 | [KNOWN] 当前 cache key 包含 `outputContractVersion` |
| [INFERRED] 扩展内容输入一致性 | [INFERRED] 场景例句、电影台词和考试真题应基于实际采用的更正文本加载 | [KNOWN] 当前主译文完成后用原始输入触发 enrichment |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [INFERRED] 独立文本校对模式 | [KNOWN] 当前请求是翻译结果中的纠错提示 | [KNOWN] 不新增专门的全文润色页面 |
| [INFERRED] 风格改写、事实核查和内容审核 | [INFERRED] 这些行为会改变语义或引入新的判断责任 | [KNOWN] 只处理翻译前的语言性错误 |
| [INFERRED] 自动学习用户个人词典 | [KNOWN] 用户未要求持久化自定义词典 | [KNOWN] 专有名词误判风险暂由不确定时保留原文控制 |
| [INFERRED] 第二次 AI 纠错请求 | [INFERRED] 会增加延迟、成本和并发状态 | [KNOWN] 推荐方案使用主翻译请求携带可选纠错结果 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户提交待翻译文本 | [INFERRED] 模型同时判断是否需要语言纠错并翻译实际采用文本 | [KNOWN] 译文区显示正常译文；必要时额外显示更正提示 | [KNOWN] 正确输入、错误输入和不确定输入的 UI 行为 | P1 | [KNOWN] 主目标已确认 |
| MAIN-1 | 结果契约 | [KNOWN] Provider 返回主翻译流 | [INFERRED] 使用可验证的结构化结果表达 `correctedSource?` 与 translation presentation | [INFERRED] Controller/UI 不从展示文案反推纠错字段 | [KNOWN] 合法、缺失、重复和畸形字段测试 | P1 | [INFERRED] 推荐方案 |
| MAIN-2 | 纠错展示 | [KNOWN] `correctedSource` 与原输入存在实质差异 | [KNOWN] 保留输入框原文，在主译文上方显示低于主译文层级的“已更正为”提示 | [KNOWN] 更正文本和主译文同时可见，主译文基于更正文本 | [KNOWN] 输入框不变、Widget 层级、选择复制和长文本换行 | P1 | [KNOWN] 用户于 2026-07-16 确认推荐方案 |
| MAIN-3 | 翻译与扩展 | [KNOWN] 模型返回有效更正文本和译文 | [KNOWN] 主译文对应更正文本；后续 enrichment 使用同一 adopted source | [KNOWN] 例句等内容不再围绕错误拼写生成 | [KNOWN] enrichment 参数和一次触发测试 | P1 | [KNOWN] 用户于 2026-07-16 确认 |
| MAIN-4 | 缓存 | [KNOWN] 请求命中新旧翻译缓存 | [INFERRED] 升级 output contract；新缓存可还原纠错和译文，旧 key 不复用 | [KNOWN] 缓存命中与实时请求展示一致 | [KNOWN] key 版本、hit/miss 和写失败测试 | P1 | [INFERRED] 推荐规则 |
| BRANCH-1 | 无错误 | [KNOWN] 模型判定无需更正 | [INFERRED] `correctedSource` 为空，不展示纠错提示 | [KNOWN] 正常译文 UI 与当前体验一致 | [KNOWN] 无多余占位或标签 | P1 | [INFERRED] 推荐规则 |
| BRANCH-2 | 不确定或专有名词 | [KNOWN] 模型不能确定是否为拼写、语法或明显错别字 | [KNOWN] 不纠错，直接翻译原文 | [KNOWN] 不因猜测改写人名、品牌或术语 | [KNOWN] 专有名词与歧义 fixture | P1 | [KNOWN] 用户于 2026-07-16 确认 |
| BRANCH-3 | 纠错字段无效或越界 | [KNOWN] 字段为空、等同原文、部分畸形，或更改数字、URL、代码、标识符及不确定专有名词 | [INFERRED] 不采纳该纠错并隐藏提示；译文字段有效且对应原文时继续展示，否则进入安全错误态 | [KNOWN] 不把协议标记或越界更正显示给用户 | [KNOWN] malformed response 与敏感 token fixture | P1 | [KNOWN] 边界已确认，fallback 细节待 TDD 验证 |
| BRANCH-4 | 并发与旧响应 | [KNOWN] 用户连续提交不同文本 | [KNOWN] 沿用 generation/latest-wins 规则，纠错和译文作为同一结果更新 | [KNOWN] 旧纠错不得覆盖新译文 | [KNOWN] stale cache/stream 回归测试 | P1 | [KNOWN] 既有控制器已有 generation guard |

## 4. 核心业务规则

| 规则编号 | 业务域 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|---|
| TC-001 | Translation | [KNOWN] 有错误时更正提示和译文必须同时显示 | [KNOWN] 错误源文本 | [KNOWN] 更正文本 + 译文 | [KNOWN] 译文不得被纠错提示替代 | [KNOWN] 用户确认 |
| TC-002 | Correction | [KNOWN] 纠错仅限拼写、语法和明显错别字；无错误或不确定时不展示提示 | [KNOWN] 正常、错误或歧义文本 | [KNOWN] 有效更正 + 译文，或仅译文 | [KNOWN] 排除风格润色和事实修正 | [KNOWN] 用户于 2026-07-16 确认 |
| TC-006 | Correction safety | [KNOWN] 不主动更改数字、URL、代码、标识符和不确定专有名词 | [KNOWN] 含敏感 token 的源文本 | [KNOWN] 保留原文翻译 | [KNOWN] 只有明确的周边拼写或语法错误可更正 | [KNOWN] 用户于 2026-07-16 确认 |
| TC-003 | Intent | [KNOWN] 纠错不得静默改写输入框 | [KNOWN] 原输入与候选更正 | [KNOWN] 输入框保留原文，译文区明确提示更正，主译文基于更正文本 | [KNOWN] 用户可继续编辑或重新提交原文 | [KNOWN] 用户于 2026-07-16 确认 |
| TC-004 | Consistency | [KNOWN] 主译文和 enrichment 使用相同 adopted source | [KNOWN] 原输入、可选更正文本 | [KNOWN] 一致的主译文与辅助内容 | [KNOWN] 纠错无效时 adopted source 回退原文 | [KNOWN] 用户于 2026-07-16 确认 |
| TC-005 | Privacy | [KNOWN] 原文和纠错文本不得进入日志 | [KNOWN] 用户文本 | [KNOWN] 仅进入既有请求、状态和缓存边界 | [KNOWN] 既有缓存隐私风险仍保留 | [KNOWN] 项目规则 |

## 5. 高严谨业务系统风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 领域业务逻辑严谨性 | [KNOWN] 是 | [KNOWN] 输入框保留原文，模型纠错仍可能改变实际翻译文本和结果 | [KNOWN] 纠错范围 | P1 |
| 金额与关键数值精度 | [KNOWN] 间接涉及 | [KNOWN] 数字、单位或代码被“纠错”会改变含义 | [KNOWN] 已确认不主动改写数字、URL、代码和标识符 | P1 |
| 交易与数据一致性 | [KNOWN] 否 | [KNOWN] 未发现交易或数据库写入 | [KNOWN] 无 | NONE |
| 状态流转 | [KNOWN] 是 | [KNOWN] loading/streaming/complete/error 与 enrichment 状态已有 | [KNOWN] 纠错何时出现、流式期间如何展示 | P1 |
| 幂等与并发 | [KNOWN] 是 | [KNOWN] 控制器已有 generation guard | [INFERRED] 纠错和译文必须原子归属同一 generation | P1 |
| 权限与审计 | [KNOWN] 否 | [KNOWN] 不新增系统权限 | [KNOWN] 无 | NONE |
| 隐私与适用监管/合规 | [KNOWN] 是 | [KNOWN] 用户文本会进入配置的 AI Provider 和本地缓存 | [KNOWN] 无新增数据类别，但纠错文本同样不得记录日志 | P1 |
| 生产变更与回滚 | [KNOWN] 是 | [INFERRED] 输出协议和缓存版本需要可回退 | [INFERRED] 回滚可恢复旧 prompt/parser 并提升 cache version | P1 |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| [KNOWN] AI 结果契约 | `lib/core/ai/prompts.dart`, `lib/core/ai/ai_provider.dart`, Provider adapters | [INFERRED] 主请求需返回可选纠错文本，并避免把模型协议标记当译文 | P1 |
| [KNOWN] 展示模型 | `lib/features/translate/models/translation_presentation.dart` | [INFERRED] 增加 adopted/corrected source 表达并提升 output contract version | P1 |
| [KNOWN] 控制器状态 | `translate_controller.dart`, `translate_state.dart` | [INFERRED] 缓存、stream complete 和 enrichment 必须携带一致的结构化结果 | P1 |
| [KNOWN] 译文 UI | `result_document.dart` | [KNOWN] 更正提示与主译文同时展示 | P1 |
| [KNOWN] 缓存 | `translation_cache.dart` 或缓存 value contract | [INFERRED] 当前只存 raw String，可能需要结构化序列化或稳定协议字符串 | P1 |
| [KNOWN] 测试 | prompt/provider/controller/model/widget/cache tests | [KNOWN] 覆盖正常、纠错、无纠错、畸形、缓存和并发 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| [KNOWN] 常见拼写错误与正常文本 | contract/widget | P1 | [KNOWN] 核心主路径 |
| [INFERRED] 专有名词、数字、URL、代码和混合语言 | safety boundary | P1 | [INFERRED] 误改会改变用户意图 |
| [KNOWN] 旧响应与缓存命中 | concurrency/cache | P1 | [KNOWN] 当前存在流式与缓存双路径 |
| [KNOWN] Prompt 不遵循和畸形输出 | provider/controller | P1 | [KNOWN] 模型输出属于不可信输入 |
| [KNOWN] 长文本换行和复制 | widget | P2 | [KNOWN] 更正结果位于可选择译文区域 |

## 8. 待确认问题

| 问题 | 风险等级 | 影响 | 建议确认人 | 期望材料 |
|---|---|---|---|---|
| [KNOWN] 更正后是否保留输入框原文？ | NONE | [KNOWN] 已确认输入框保留原文，译文区提示更正，主译文采用更正文本 | [KNOWN] 用户 | [KNOWN] 用户于 2026-07-16 同意推荐方案 |
| [KNOWN] 纠错是否仅限拼写、语法和明显错别字？ | NONE | [KNOWN] 已确认，并排除风格、事实、数字、URL、代码、标识符及不确定专有名词改写 | [KNOWN] 用户 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] enrichment 是否使用更正文本？ | NONE | [KNOWN] 已确认三类扩展内容使用与主译文相同的 adopted source | [KNOWN] 用户 | [KNOWN] 用户于 2026-07-16 确认 |
