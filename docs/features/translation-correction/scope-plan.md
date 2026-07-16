# Scope 需求梳理、准入与 TDD 计划

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `TDD_INPUT_READY` |
| 最高风险等级 | [KNOWN] P1 |
| 一句话依据 | [KNOWN] feature-id、输入框与主译文行为、纠错安全边界、enrichment adopted source 和回退规则均已确认，主干与关键分支可独立验证 |
| 下一步建议 | [KNOWN] 按 S1 至 S4 顺序转 `hicode:tdd`，每个切片独立执行 RED-GREEN-REFACTOR |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| [KNOWN] 项目规则 | `AGENTS.md`, `docs/rules/coding_rules.md` | [KNOWN] 是 | [KNOWN] 模型输出不可信；结果需 typed；缓存 key 包含输出选项；不得记录原文 | [KNOWN] 无 |
| [KNOWN] 领域与项目上下文 | `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | [KNOWN] 是 | [KNOWN] Translation result 格式契约原本待确认；Feature 索引没有纠错能力 | [KNOWN] 负责人未指派 |
| [KNOWN] 产品简述 | `aitrans-prd.md` | [KNOWN] 是 | [KNOWN] 只要求基础译文和三类扩展内容 | [KNOWN] 没有纠错规则 |
| [KNOWN] 用户输入 | 当前对话 | [KNOWN] 是 | [KNOWN] 错误 text 由大模型更正，在译文区域提示更正结果并显示译文；feature-id、输入框处理、纠错边界和 enrichment adopted source 均已确认 | [KNOWN] 无行为规则缺口 |
| [KNOWN] 当前 AI 契约 | `ai_provider.dart`, `prompts.dart`, Provider adapters | [KNOWN] 是 | [KNOWN] Provider 流式返回 raw translation chunks；prompt 使用行协议 | [KNOWN] 没有 corrected source 字段 |
| [KNOWN] 当前状态与 UI | `translate_controller.dart`, `translate_state.dart`, `translation_presentation.dart`, `result_document.dart` | [KNOWN] 是 | [KNOWN] complete/cache 都保存 raw String；UI 再解析主词义、词性、读音和补充词义 | [KNOWN] 纠错结果无法独立表达 |

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | [KNOWN] `NO_BLOCKING_GAPS` |
| 需求分析输入 | [KNOWN] “输入 text 错误时由大模型更正，在译文区域提示更正结果，同时显示译文内容” |
| 证据缺口 | [KNOWN] 业务、研发和测试负责人未指派；不阻断本地 TDD 输入 |

| 检查项 | 结论 | 证据或缺口 |
|---|---|---|
| [KNOWN] 一句话目标 | [KNOWN] 已明确 | [KNOWN] 自动纠错提示与译文并存 |
| [KNOWN] 范围内/外/非目标 | [KNOWN] 已明确 | [KNOWN] 独立校对、风格改写和事实核查已排除 |
| [KNOWN] 可测试验收标准 | [INFERRED] 主干可测试 | [KNOWN] 输入框保留原文已确认；流式展示时点仍需在实现切片中明确 |
| [KNOWN] 业务规则与异常路径 | [KNOWN] 已闭合 | [KNOWN] 误改边界、无纠错回退、enrichment adopted source 和畸形输出处理均已定义 |
| [KNOWN] 术语冲突 | [KNOWN] 无 | [KNOWN] “更正文本”可作为 Translation 域新术语 |
| [KNOWN] 高严谨风险 | [KNOWN] P1 | [INFERRED] 错误更正可能改变语义、数字或标识符 |
| [KNOWN] 影响范围 | [KNOWN] 已定位 | [KNOWN] prompt/provider、presentation/state/controller/cache/UI/tests |
| [KNOWN] 设计树输入 | [KNOWN] 满足 | [KNOWN] 方案 A 已确认，主干、关键分支和停止条件均可进入 TDD 拆分 |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | [KNOWN] 让用户在译文区看见模型采用的更正文本，并同时得到对应译文 |
| 范围内 | [INFERRED] 主请求纠错判断、typed presentation、纠错提示、缓存一致性、enrichment 输入一致性 |
| 范围外 | [INFERRED] 独立校对页、风格润色、事实核查、个人词典和额外纠错请求 |
| 非目标 | [INFERRED] 不承诺模型纠错绝对正确；不允许无提示地改变用户意图 |
| 验收标准 | [KNOWN] 有错误：更正提示与译文并存；无错误：只显示译文；[INFERRED] 畸形纠错字段不得污染译文 UI |
| feature_context 更新 | [KNOWN] 已创建并更新，状态 `TDD_INPUT_READY` |
| ADR 处理 | [INFERRED] 当前不需要；结果模型和 prompt 协议为局部可回滚修改 |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户提交翻译文本 | [INFERRED] 同一模型请求产生可选纠错和译文 | [KNOWN] 译文区展示结果 | [KNOWN] 不扩展为独立校对工具 | [KNOWN] 错误/正确/歧义输入 | P1 |
| MAIN-1 | 模型契约 | [KNOWN] 主翻译请求 | [INFERRED] 同一请求使用显式纠错字段/分帧协议，应用解析为 typed correction + translation presentation | [INFERRED] UI 不解析任意自然语言提示 | [KNOWN] 不新增第二次请求；保留流式能力 | [KNOWN] prompt、partial frame、parser、malformed response | P1 |
| MAIN-2 | 用户展示 | [KNOWN] 存在有效更正文本 | [KNOWN] 输入框保留原文；译文上方展示低权重更正提示；主译文基于更正文本且保持视觉主角 | [KNOWN] 不自动回写输入框 | [KNOWN] 输入框不变、UI 层级、复制、无纠错回归 | P1 |
| MAIN-3 | adopted source | [KNOWN] 更正有效 | [KNOWN] translation 和 enrichment 绑定同一 adopted source；无有效更正时统一回退原文 | [KNOWN] 不把显示文案当业务字段 | [KNOWN] enrichment 调用参数与一次触发 | P1 |
| MAIN-4 | 缓存与并发 | [KNOWN] cache hit 或并发请求 | [INFERRED] output contract 升级，纠错与译文原子归属 generation | [KNOWN] 不迁移复用旧 raw cache key | [KNOWN] hit/miss/stale/write failure | P1 |
| BRANCH-1 | 无错误/不确定 | [KNOWN] 无有效 correction，或模型不能确定是否为允许的语言错误 | [KNOWN] 隐藏纠错提示并翻译原文 | [KNOWN] 不展示空占位，不做风格或事实修正 | [KNOWN] 专有名词、混合语言 | P1 |
| BRANCH-2 | 畸形响应 | [KNOWN] 模型输出不可信 | [INFERRED] correction 无效则忽略；translation 无效则进入错误态 | [KNOWN] 不泄漏协议和内部错误 | [KNOWN] 缺字段、重复字段、空值 | P1 |
| BRANCH-3 | 误改敏感 token | [KNOWN] 候选更正涉及数字、URL、代码、标识符或不确定专有名词 | [KNOWN] 不采纳纠错，保留原文 | [KNOWN] 不做风格润色或事实核查 | [KNOWN] 数字、URL、code、专有名词 fixtures | P1 |

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| [KNOWN] feature-id 是否为 `translation-correction`？ | [KNOWN] 已关闭 | [KNOWN] 是 | [KNOWN] 独立用户可见能力，不混入 Provider 接入 | [KNOWN] 固定文档目录 | [KNOWN] 用户 |
| [KNOWN] 更正后输入框保留原文还是替换为更正文本？ | [KNOWN] 已关闭 | [KNOWN] 保留原文，只在译文区提示更正；主译文基于更正文本 | [INFERRED] 防止静默篡改，允许用户比较和重新提交 | [KNOWN] 状态、重试、UI、缓存和验收口径已固定 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] 纠错范围是否限于拼写、语法和明显错别字？ | [KNOWN] 已关闭 | [KNOWN] 是；排除风格、事实、数字、URL、代码、标识符和不确定专有名词改写 | [INFERRED] 降低语义漂移 | [KNOWN] prompt、测试边界和误改处理已固定 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] enrichment 是否使用更正文本？ | [KNOWN] 已关闭 | [KNOWN] 是；使用与主译文相同的 adopted source | [INFERRED] 保证译文与学习内容一致 | [KNOWN] controller 参数和缓存已固定 | [KNOWN] 用户于 2026-07-16 确认 |

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| `Prompts.translateSystem` | [INFERRED] 增加已确认的纠错边界和结构化输出协议 | [KNOWN] 当前 prompt | [KNOWN] 纠错范围已确认 | P1 |
| `TranslationResult` / presentation | [INFERRED] 分离 corrected source 与译文 | [KNOWN] 当前 raw String 契约 | [INFERRED] 推荐 | P1 |
| `TranslateController` | [KNOWN] 保持纠错、译文、generation 和 enrichment adopted source 一致 | [KNOWN] 当前 cache/stream flow 与用户确认 | [KNOWN] 已确认 | P1 |
| translation cache | [INFERRED] 输出协议版本升级，避免旧缓存误解析 | [KNOWN] cache identity 已含 contract version | [INFERRED] 推荐 | P1 |
| `HeroTranslation` | [KNOWN] 在译文区域展示更正结果与译文，输入框保留原文 | [KNOWN] 用户要求与后续确认 | [KNOWN] 已确认 | P1 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [INFERRED] 模型误改改变语义 | P1 | [KNOWN] 纠错来自不可信模型输出 | [KNOWN] 保留输入框原文、明确提示；限制为拼写/语法/明显错别字，保护敏感 token | [KNOWN] 研发负责人负责实现证据 |
| [INFERRED] 纠错与译文/enrichment 不一致 | P1 | [KNOWN] 当前 enrichment 使用原始 input | [KNOWN] 建立 adopted source 单一字段并由 controller 一次传递 | [KNOWN] 研发负责人负责实现证据 |
| [INFERRED] 旧缓存被新 parser 误读 | P1 | [KNOWN] 当前缓存 value 是 raw String | [INFERRED] 提升 output contract version，不复用旧 key | [KNOWN] 研发负责人 |
| [INFERRED] 流式输出泄漏协议标记 | P1 | [KNOWN] 当前 UI 直接展示累积 raw chunks | [INFERRED] 在 presentation 边界解析后再展示业务字段 | [KNOWN] 研发负责人 |

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. 单请求 + typed 结果 + 保留原输入 | [KNOWN] 已确认主方案 | [INFERRED] 同一请求返回 optional correction 和 translation；UI 分字段展示 | [INFERRED] 无纠错隐藏提示，畸形 correction 回退，translation 无效报错 | [KNOWN] 不新增请求，不改写输入框，主译文采用更正文本 | [INFERRED] 一致、可缓存、可测试、用户可比较 | [INFERRED] 需要升级 prompt、结果模型和缓存契约 | [KNOWN] 用户于 2026-07-16 同意推荐方案 |
| B. 单请求 + 自动替换输入框 | [INFERRED] 不推荐 | [INFERRED] 更正结果写回输入状态再展示译文 | [INFERRED] 用户撤销或重新输入处理更复杂 | [KNOWN] 不新增请求 | [INFERRED] 输入与 enrichment 表面一致 | [INFERRED] 静默改写、光标和重试状态复杂 | [INFERRED] 用户控制较弱 |
| C. 纠错请求与翻译请求分离 | [INFERRED] 不推荐 | [INFERRED] 先纠错，再用结果发起翻译 | [INFERRED] 纠错失败回退原文 | [KNOWN] 两次模型调用 | [INFERRED] 协议职责简单 | [INFERRED] 延迟、成本、取消和结果不一致风险更高 | [INFERRED] 超出“同时得到更正和译文”的最小闭环 |

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | [KNOWN] `TDD_INPUT_READY` |
| 下一步路由 | [KNOWN] `hicode:tdd` |
| 未覆盖设计树节点 | [KNOWN] 无；业务/研发/测试负责人指派属于管理缺口，不改变行为切片 |

### 最终 TDD 切片

| 任务 | 目标与设计树节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点与测试重点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|---|---|
| S1 纠错结果模型、协议解析与安全校验 | [KNOWN] 把原文、可选更正、adopted source 和译文表达为 typed presentation；MAIN-1、BRANCH-1/2/3 | [KNOWN] TC-001/002/003/006 和现有词义/POS/PRON 行协议 | [KNOWN] 内：单请求分帧协议、partial/complete parse、无纠错、敏感 token 保留、畸形 correction 回退；外：Provider 网络实现、UI、enrichment | [INFERRED] `translation_presentation.dart`、必要的新 outcome/parser/validator 及 model tests | [KNOWN] 先写 `teh → the`、正常文本、数字/URL/code/标识符变化拒绝、相同/空/畸形 correction、主译文/POS/PRON 兼容 RED tests | [KNOWN] focused model tests + `dart format` | [KNOWN] 若必须取消现有流式译文才能形成可靠协议，或无法在不猜测专有名词的前提下定义 deterministic validator，则返回 Scope |
| S2 主翻译 Prompt 与 Provider 契约 | [KNOWN] 让同一 AI 请求按 S1 协议返回可选纠错和译文；MAIN-1、BRANCH-2/3 | [KNOWN] 已确认纠错范围、现有 `Prompts.translateSystem` 和各 Provider 共用边界 | [KNOWN] 内：prompt 规则、同请求、stream chunk 到 typed presentation 的边界；外：第二次 AI 请求、风格/事实校对、Provider SDK 更换 | [INFERRED] `prompts.dart`、`ai_provider.dart` 或解析适配层、Provider contract tests | [KNOWN] 先写 prompt 包含允许/禁止规则、无纠错标记、分帧闭合和 malformed response tests；保护 OpenAI-compatible/Ollama 等现有入口 | [KNOWN] focused prompt/provider tests | [KNOWN] 若任一已支持 Provider 无法表达同一稳定协议，或需要新增依赖/结构化输出专有能力，则返回 Scope |
| S3 Controller、缓存与 enrichment adopted source | [KNOWN] 让实时流和缓存命中产生一致 outcome，并用 adopted source 加载三类扩展；MAIN-3/4、BRANCH-1/4 | [KNOWN] S1 typed outcome、S2 Provider 输出、现有 generation guard 与 output contract cache key | [KNOWN] 内：output contract version 提升、cache hit/miss、write failure、latest-wins、一次 enrichment、有效纠错/回退原文；外：缓存加密/保留策略重构 | [INFERRED] `translate_controller.dart`, `translate_state.dart`, `translation_cache.dart` 或 value codec、controller/cache tests | [KNOWN] 先写有效纠错触发 corrected adopted source、无效纠错回退原文、cache hit 一致、旧 generation 不触发 enrichment、write failure 保留结果 RED tests | [KNOWN] focused controller/cache tests | [KNOWN] 若需要迁移或复用旧 value 而非通过 contract key 隔离，或会重复触发计费 enrichment，则停止并返回 Scope |
| S4 译文区展示与全量回归 | [KNOWN] 保留输入框原文，在译文区同时显示更正提示与主译文；MAIN-2、ROOT | [KNOWN] S3 typed state、现有 HeroTranslation 视觉层级和用户确认 | [KNOWN] 内：低权重“已更正为”提示、主译文/POS/PRON/多词义、流式/complete、复制不泄漏协议标记、长文本；外：自动回写输入框、独立校对页、整体视觉重构 | [INFERRED] `result_document.dart`, command/input state, widget tests | [KNOWN] 先写输入框保持原文、更正与译文并存、无纠错无占位、流式不显示协议标记、复制仅使用业务展示文本 RED tests | [KNOWN] focused widget tests；`dart format --output=none --set-exit-if-changed lib test`；`flutter analyze`；`flutter test`；macOS Debug build | [KNOWN] 若 UI 必须从 raw 模型字符串重新猜测 correction，或输入 controller 被动改写，则返回 S1/S3，不以 UI workaround 收尾 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1/BRANCH-2 | [KNOWN] 有纠错、无纠错、partial、缺失/畸形字段 | contract/parser | P1 | [KNOWN] 虚构拼写错误和安全 fixture | S1/S2 |
| MAIN-2 | [KNOWN] 输入框保留原文，更正提示与基于更正文本的主译文同时显示 | widget | P1 | [KNOWN] 短词、句子、长文本 | S4 |
| MAIN-3 | [KNOWN] enrichment 使用 adopted source；无有效纠错时回退原文 | controller | P1 | [KNOWN] fake AIProvider | S3 |
| MAIN-4 | [KNOWN] cache hit、stream complete、write failure、stale response | state/cache | P1 | [KNOWN] controllable fake streams | S3 |
| BRANCH-3 | [KNOWN] 数字、URL、代码、标识符和不确定专有名词不误改 | safety | P1 | [KNOWN] 完全虚构 fixture | S1/S2 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | [INFERRED] 否 |
| 判断理由 | [INFERRED] 修改局限在翻译结果契约、缓存版本和 UI，可通过恢复旧 contract version 回滚，不满足难逆条件 |
| 涉及决策点 | [KNOWN] 单请求或双请求、输入框保留或替换；记录在 feature Scope 足够，若演变成通用校对平台再重评 ADR |

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 建议更新 | [KNOWN] 增加 corrected source、adopted source、纠错范围和敏感 token 保留规则 | [KNOWN] 负责人未指派，按项目规则暂不写入长期上下文 | [KNOWN] 待负责人确认 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 建议更新 | [KNOWN] 增加 `translation-correction` Feature 索引，状态 `TDD_INPUT_READY` | [KNOWN] 负责人未指派，按项目规则暂不更新 Feature 索引 | [KNOWN] 待负责人确认 |

## 14. 文档处理清单

| 文档 | 处理结果 |
|---|---|
| `docs/features/translation-correction/feature_context.md` | [KNOWN] 已创建并更新；状态 `TDD_INPUT_READY` |
| `docs/features/translation-correction/scope-plan.md` | [KNOWN] 已创建并更新；结论 `TDD_INPUT_READY`，包含 S1-S4 |
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 未更新；稳定规则已确认，但负责人未指派，等待负责人确认长期上下文写入 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 未更新；Scope 已收敛，但负责人未指派，等待负责人确认 Feature 索引写入 |
| `docs/adr/` | [KNOWN] 未创建；当前判断不需要 ADR |
