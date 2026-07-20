# 翻译记忆与趣味复习：Scope 需求梳理、准入与 TDD 计划

本文件是 `hicode:scope` 的单一输出文档，用于承载 `translation-memory-review` 的需求梳理、准入评审、设计树方案和后续 TDD 输入。当前已完成 Scope 收敛；`TDD_INPUT_READY` 不代表负责人批准编码、接受风险或允许发布。

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | `TDD_INPUT_READY` |
| 最高风险等级 | `P1` |
| 一句话依据 | [KNOWN] 目标、范围、验收、分类、身份、加密/删除、调度、AI 权限、媒体、三端入口及调用预算均已闭合；P1 风险已进入 Proposed ADR、九个 TDD 切片及明确停止条件 |
| 下一步建议 | 按 TMR-01 至 TMR-09 顺序使用 `hicode:tdd`；每个任务先写失败测试，触发停止条件时返回 Scope，不得以降级安全要求继续 |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| 用户需求 | 当前会话 | 是 | [KNOWN] 查看并复习翻译过的单词/短语；长句不记录；AI 推荐易忘内容；展示 AI 记忆插图、词性词义、生活常用语和限定为文字的电影内容；隐私、媒体、分类、身份、推荐职责、复习时间表、三端本地范围和调用预算均已确认 | 无待用户确认业务缺口 |
| 项目入口规则 | `AGENTS.md` | 是 | [KNOWN] feature 文档固定路径；持久化文本需隐私边界；不读取敏感数据 | 负责人和版本待确认 |
| 编码规则 | `docs/rules/coding_rules.md` | 是 | [KNOWN] 用户文本持久化必须定义保留/删除；AI 调用需超时、重试和计费防重；UI/状态/持久化需分层 | 已转化为 TMR-03、TMR-06、TMR-08、TMR-09 的验收与停止条件 |
| 领域知识 | `docs/DOMAIN_KNOWLEDGE.md` | 是 | [KNOWN] 学习上下文已有例句、电影台词概念；来源、版权、排序和核验均待确认 | 尚无翻译历史、复习条目、熟练度术语 |
| 项目上下文/Feature 索引 | `docs/PROJ_CONTEXT.md` | 是 | [KNOWN] 无既有匹配 Feature；历史风险指出翻译结果当前存于未加密 Hive | 新 Feature 尚未进入正式索引；需负责人确认后再更新 |
| 产品简述 | `aitrans-prd.md` | 是 | [KNOWN] 基础结果页意图包括场景例句、电影台词和考试真题 | 没有历史与复习需求细节，不证明媒体来源或授权 |
| ADR 索引 | `docs/adr/README.md`, `docs/PROJ_CONTEXT.md`, `docs/adr/ADR-0001-review-data-encryption-key-lifecycle.md` | 是 | [KNOWN] 已创建复习数据加密与密钥生命周期 Proposed ADR；仍需负责人确认 | 不影响 TDD 输入，但 TMR-03 不得在 ADR 被拒绝或平台安全存储不可验证时继续 |
| 现有缓存 | `lib/core/cache/translation_cache.dart`, `lib/main.dart` | 是 | [KNOWN] `CachedTranslation` 只存译文和访问时间；key 是含源文的 SHA-256 身份；最多 100 条；Hive box 未配置加密 | 无可枚举源词、语言、次数、复习状态、删除派生数据和版本化历史模型 |
| 翻译流程 | `lib/features/translate/logic/translate_controller.dart` | 是 | [KNOWN] 最终且 generation 有效的成功结果会写缓存；缓存命中也形成完成态；扩展内容只在 `translateNow` 完成后请求 | 历史写入触发、去重、失败提示和长句判定不存在 |
| 展示与 AI 模型 | `TranslationPresentation`, `AIProvider`, `Prompts`, `ResultDocument` | 是 | [KNOWN] 已支持主词义、词性、读音、补充词义、场景例句和文字电影台词；扩展内容不持久化 | 没有图片、视频、复习队列、遗忘评分或反馈状态 |
| 现有测试 | cache identity、controller、presentation、result document focused tests | 是 | [KNOWN] 已有缓存身份、过期响应、扩展内容和 UI 基础测试点 | 没有历史、删除、调度、媒体降级测试 |

### 输入缺口

1. [KNOWN] 无待用户确认的业务输入缺口。
2. `P2`：业务、研发、测试、安全/隐私、版权/内容负责人尚未指定；其复核属于后续 Review 证据，不改变当前已确认规则。
3. [KNOWN] NFKC 必须使用经过审查的 Unicode normalization 实现；80 字符按用户感知的 Unicode grapheme cluster 计数。若 TDD 无法确认维护中的实现，TMR-02 停止，不得手写不完整替代。
4. [KNOWN] AI 图片只对当前 Provider/当前模型显式声明并验证的 capability 生效；没有已核验 live adapter 时，TMR-09 只能交付 capability 契约与主题图标降级，不得声称真实图片生成已完成。

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | `NO_BLOCKING_GAPS` |
| 任务重点 | [KNOWN] 需求评审、范围收敛与任务拆分；本次不实现代码、不进入 TDD |
| 一句话目标 | [KNOWN] 将符合条件的翻译词条沉淀为本地学习记录，并以 AI 辅助的易忘推荐和多媒体卡片形成趣味复习闭环 |
| 目标是否明确 | [KNOWN] 明确；首期验收功能闭环和状态可观察，不以学习效果提升指标作为编码准入条件 |
| 范围是否明确 | [KNOWN] 已闭合；三端本地范围、入口、不做同步/导入导出、每组规模和 AI 调用预算均已确认 |
| 验收是否可测试 | [KNOWN] 可测试；MAIN-1 至 MAIN-6 已量化分类、身份、加密、10/50 分组、反馈时间表、内容构成、渐进加载、降级和再次到期 |
| 规则是否可追溯 | [KNOWN] 用户逐项确认记录可追溯；安全默认来自项目规则和两次只读复核；专业负责人复核不改变当前 Scope 事实 |
| 影响范围是否可定位 | 可定位到缓存/新历史存储、翻译控制器、AI Provider 可选图片 capability、App 导航、新 review feature 与测试；无需外部图库或影视视频系统 |
| 最高阻断 | 无未关闭 P0/P1 业务问题；最高实现风险仍为 P1 隐私加密、并发合并、AI 权限与内容安全，必须由 TDD 任务和 Review 验证 |
| 证据缺口 | 无业务阻断；live 图片 capability、平台安全存储和 Unicode normalization 作为任务内实现证据与停止条件 |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | [KNOWN] 支持用户查看翻译过的单词/短语，并优先复习可能容易忘记的内容 |
| 范围内 | [KNOWN] 合格记录采集、加密历史、删除、确定性调度、AI 排序、三档反馈、三端历史/复习页、AI 记忆插图、词性词义、生活常用语、许可内容源短台词或标注的影视化场景对白，以及完整降级闭环 |
| 范围外 | [KNOWN] 长句和段落记录；账号、跨设备同步、导入、导出、社交排行、影视剧照/海报/视频以及未授权影视分发 |
| 非目标 | [KNOWN] 不改变基础翻译语义；不把原始用户文本写入日志；复习故障不阻塞翻译；不以首期学习效果提升作为验收；不含账号/同步/导入导出、影视剧照/海报/视频或未授权真实台词 |
| 验收标准 | [KNOWN] 合格词条按版本化分类自动加密 upsert，长句不记录；三端可查看/删除历史并完成 10 条一组的到期复习；AI 只排序/解释且稳定降级；卡片即时显示已有词义并按需渐进加载文字/图片；三档反馈按时间表再次到期；单删/清空后任何晚到结果均不得复活数据 |
| `feature_context.md` 更新 | 已创建并收敛 |
| ADR 处理 | 已创建 `Proposed` ADR-0001；需负责人确认，不代表 Accepted |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | 用户产生可学习的翻译记录 | 闭合采集、推荐、复习、反馈与再调度 | 可持续的个性化复习队列 | 长句不记录；AI 图片明确标注；真实电影短台词必须来自应用内批准且有展示权的结构化源 | 端到端完成一次并在到期规则下再次出现 | P1 |
| MAIN-1 | 资格判定 | 最终有效的成功翻译，包括具备新分类契约的缓存命中 | 同一次翻译响应返回版本化五类语义分类；只接受 `word`/`phrase`，并强制排除换行、超过 80 个 Unicode grapheme cluster 或具有多个句子边界的输入 | `eligible` 或 `excluded(reason)`；分类与版本随结果缓存 | `sentence`/`paragraph`/`unknown` 和旧缓存缺失分类时不自动记录 | 80/81 grapheme、换行、多句、缩写标点、无空格语言、纠错文本、旧缓存 | P1 |
| MAIN-2 | 独立历史存储 | MAIN-1 合格、采集开启且实际源语言可用 | 按“规范化纠正词条 + 实际源语言 + 目标语言”在独立加密仓库 upsert；使用经审查的 NFKC、去首尾/合并空白和适用语言大小写折叠；原文作别名；Provider 不参与身份 | 首次新增；重复翻译更新次数、最近时间和最新有效内容并保留复习进度；不同语言方向独立 | 历史及派生缓存使用版本化 AES-256-GCM envelope；密钥进入平台安全存储且不与密文同库；不复用翻译缓存或 Provider 凭证密钥 | Provider 切换、纠错别名、自动语言、NFKC、并发 upsert、密钥缺失/篡改/重启/写失败 | P1 |
| MAIN-3 | 历史入口与管理 | macOS/iOS/Android 用户点击底部带到期数量的“复习”入口 | 打开全屏页；“今日复习”显示到期队列，“历史记录”显示本地词条；首次进入告知采集政策；提供关闭采集、单删和清空 | 历史可见且可管理，关闭后停止新增 | 首期不含账号、同步、导入和导出 | 三端入口/返回、badge、空态、重启、关闭采集、删除后不再推荐 | P1 |
| MAIN-4 | 到期与 AI 排序 | 用户开始一组复习；新词满 24 小时、既有词条达到 `nextReviewAt`，或到期前再次翻译同一词条 | 本地按稳定顺序选最多 50 个候选；每组最多一次 AI 排序并取前 10 个；AI 不修改进度；排序按候选摘要 + Provider/模型 + 契约版本缓存 30 分钟 | 最多 10 个的固定组快照；完成或主动结束即关闭该组；badge 保留总到期数 | 新增/删除/反馈/重复翻译/Provider/模型/契约变化立即使排序缓存失效；失败排序为逾期时长降序 → 忘记次数降序 → 最近复习时间升序 → 学习身份升序 | 离线、超时、非法/未知 ID、缓存命中/失效、平局和调用计数 | P1 |
| MAIN-5 | 内容准备 | 某词条首次成为当前复习卡 | 立即显示已保存词性词义；每个内容身份最多一次文字调用和一次图片调用，不预取；内容加密缓存；手动重试每次只重试用户选择的失败类型 | 卡片从基础内容渐进到完整/部分内容 | 真实台词只接受应用内批准且有展示权的结构化源，包含作品/来源/许可字段；AI 自报来源无效，无批准源时只显示标注的影视化对白且无真实影片名 | 首次展示、缓存命中/淘汰、Provider/契约变化、删除、手动重试和调用计数 | P1 |
| MAIN-6 | 复习交互 | 用户翻卡并选择“忘记 / 模糊 / 记得” | 忘记：10 分钟、清零连续次数、忘记次数加一；模糊：1 天且连续次数不增加；记得：连续次数加一并按 3/7/14/30/60/90 天递进，之后保持 90 天 | 当前卡完成，反馈、计数、`lastReviewedAt`、`nextReviewAt` 和队列更新 | 不以观看时长自动等同掌握；重复点击幂等 | 三档转换、首次 24 小时、间隔上限、时钟边界、重复翻译立即入队但不重置 | P1 |
| BRANCH-1 | 过期响应 | 较早翻译在新请求后才完成 | 沿用 generation 保护，不写入历史 | 仅最新有效完成可写 | 与当前控制器一致 | 并发完成顺序测试 | P1 |
| BRANCH-2 | AI 失败 | 分类、排序、文字或图片调用失败 | 基础翻译不回退；分类无有效值不记录；排序稳定降级；文字使用已有词义；图片使用主题图标；仅手动重试允许新调用 | degraded 状态可观察且进度不变 | 每组排序最多一次，内容不预取/不自动重试，避免重复计费 | 超时、取消、malformed、安全拒绝、Provider 切换、调用计数 | P1 |
| BRANCH-3 | 加密存储不可用 | 平台安全存储不可用、密钥缺失、解密失败、box 损坏或迁移失败 | 不回退明文；历史进入明确 unavailable；基础翻译继续；仅允许用户显式安全清空/重建 | 翻译可用、历史不可用状态明确，不产生新明文或半条记录 | 缺失密钥不隐式生成覆盖旧密文；Provider 凭证重置不影响历史 | 三端密钥拒绝/缺失、篡改、部分迁移和显式重建 | P1 |
| BRANCH-4 | 删除/禁用采集 | 用户单删、清空或关闭采集 | 单删/清空先递增 generation 并取消可取消请求，再删除历史、进度、别名、排序、文字、图片及元数据；关闭只停止新增且不隐式清空 | 已删内容不再推荐，关闭后不新增 | AI 调用按类型只发送必要词条/语言/状态，不发送别名、完整历史、长句或无关数据 | 删除/关闭后重启、缓存失效和远端保留披露 | P1 |
| BRANCH-5 | 媒体失败/无授权 | 当前 Provider/模型不支持图片、生成失败/超时/被安全策略拒绝，或无批准真实台词源 | 图片显示可访问主题图标且不切换 Provider；电影文字使用标注的影视化对白且不显示真实影片名 | `partial` 卡片仍可反馈 | AI 图片必须标注；禁止抓取/分发未授权影视内容，不信任 AI 自报来源 | 离线、超时、安全拒绝、来源/许可缺失、窄屏 | P1 |
| BRANCH-6 | 删除后晚到/上下文失效 | 排序、文字或图片响应到达时记录已删/清空，generation、Provider/模型或契约已变化 | 写前重新校验记录存在与上下文；不匹配即丢弃 | 已删除或失效数据不会复活 | 丢弃结果不得创建历史、缓存、图片文件或元数据 | 单删/清空/切换 Provider/契约升级与不可取消请求竞态 | P1 |

### 节点证据与测试切入点

- `ROOT/MAIN-1`：来源为用户需求；测试入口为 `TranslateController` 最终态与独立资格判定器。
- `MAIN-2/BRANCH-3/BRANCH-4`：来源为项目持久化规则和当前缓存结构；测试入口为纯 Dart repository/store 合同。
- `MAIN-4/MAIN-6`：来源为“容易忘”和“复习”目标；本地调度与 AI 职责、三档反馈和时间表均已确认；测试入口为注入时钟的纯调度器和状态机。
- `MAIN-5/BRANCH-2/BRANCH-5`：来源为趣味内容要求及现有 enrichment 能力；测试入口为结构化 AI/媒体 adapter 和 partial-state UI。

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| feature-id 是否为 `translation-memory-review` | 已关闭 | 是 | 覆盖历史和复习，不误导为仅单词 | 固定文档目录和需求身份 | 用户 |
| 隐私、保留和 AI 发送边界是什么 | 已关闭 | 本地自动记录、首次告知、可关闭/单删/清空；历史和全部派生缓存加密；密钥进平台安全存储；排序/文字/图片按调用类型发送最小必要字段 | 满足个性化同时最小化泄露，避免复用未加密结果缓存 | [KNOWN] 固定历史/派生数据、密钥、删除、防复活和远端载荷边界 | 用户已确认；安全/隐私负责人复核 |
| “电影片段”指什么 | 已关闭 | 首期为短文字内容；真实台词仅允许应用内批准且具备展示权的结构化源，并包含作品/来源/许可字段；AI 输出不算来源证明；无批准源时显示标注的影视化对白且不显示真实影片名 | 避免引入版权视频、CDN、播放器和伪造来源 | [KNOWN] 电影内容留在文字边界，并固定许可与内容身份字段 | 用户已确认；版权/法务负责人复核批准源 |
| 图片来源是什么 | 已关闭 | 当前配置 Provider 异步生成记忆插图，按词条缓存并标注“AI 生成”；不支持或失败时显示主题图标，不自动切换 Provider | 避免图库版权和静默切换计费 Provider，同时保留明确降级 | [KNOWN] 需要可选 image capability、缓存身份、内容安全状态和 AI 标识 | 用户已确认；安全/内容负责人复核 |
| 如何区分短语与长句 | 已关闭 | 同一次翻译响应返回版本化 `word / phrase / sentence / paragraph / unknown`；只记录前两类；客户端强制排除换行、超过 80 个 Unicode grapheme cluster 或具有多个句子边界的输入；旧缓存不自动补录 | 跨语言语义判断优于纯本地阈值，grapheme 按用户感知字符计数，且不增加独立 AI 请求 | [KNOWN] 固定输出契约、缓存身份、排除原因和边界测试 | 用户已确认；语言内容负责人复核语料 |
| 如何判断容易忘记 | 已关闭 | 确定性间隔重复决定到期；AI 只基于已确认最小摘要排序并给出原因，不修改状态；失败时按逾期时长降序、忘记次数降序、最近复习时间升序 | 可测试、可解释、可离线降级，且保留 AI 个性化价值 | [KNOWN] 固定本地调度与 AI 职责、降级顺序和状态写权限 | 用户已确认；学习体验负责人复核 |
| 复习反馈档位和时间表是什么 | 已关闭 | 新词 24 小时首次到期；忘记为 10 分钟并清零连续次数、增加忘记次数；模糊为 1 天且不增加连续次数；记得按 3/7/14/30/60/90 天递进并以 90 天封顶；重复翻译立即入队但不重置 | 三档适合移动端操作，并形成确定、可测试的首期间隔调度 | [KNOWN] 固定状态字段、反馈语义、首次到期、间隔表、上限和重复翻译行为 | 用户已确认；学习体验负责人复核 |
| 同一词条如何去重 | 已关闭 | 规范化纠正词条 + 实际源语言 + 目标语言组成学习身份；NFKC、去首尾/合并空白和适用语言大小写折叠；原文作别名；Provider 不参与身份；重复翻译更新次数/时间/最新内容并保留进度 | 避免切换 Provider 后产生重复学习卡，同时隔离不同语言方向和同形异语言 | [KNOWN] 固定身份键、合并字段、别名和跨 Provider 行为 | 用户已确认；研发负责人复核 |
| 首期平台、入口和同步范围 | 已关闭 | macOS、iOS、Android 均提供本地历史/复习；底部工具栏显示带到期数量的入口，全屏页包含“今日复习”和“历史记录”；首期不含账号、跨设备同步、导入或导出 | 符合现有产品平台且不引入账号、后端和同步冲突 | [KNOWN] 固定三端验证矩阵、导航结构和范围外能力 | 用户已确认；产品/研发负责人复核 |
| 每组规模与 AI 调用预算是什么 | 已关闭 | 每组 10 个、本地候选最多 50 个、排序每组最多一次且缓存 30 分钟；文字/图片只为当前卡首次展示时生成，不预取、不自动重试；内容按学习身份 + Provider/模型 + 契约版本缓存 | 控制等待和费用，同时保留渐进增强体验 | [KNOWN] 固定调用上限、缓存身份、生成时机和失败重试语义 | 用户已确认；研发负责人复核 |

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| 记录资格 | [KNOWN] 最终成功后使用同次响应版本化分类，只记录 `word`/`phrase`，并应用换行、80 字符和多句强制保护；旧缓存不自动补录 | 用户确认、`TranslateController` | 业务契约已确认；实现和多语言语料待验证 | P1 |
| 历史模型 | [KNOWN] 独立于 LRU 翻译缓存；身份为规范化纠正词条 + 实际源语言 + 目标语言；历史与派生缓存使用版本化 envelope；复习密钥独立于 Provider 凭证并进入平台安全存储 | 用户确认、当前缓存结构、Proposed ADR-0001 | 业务与安全契约已确认；实现待 TDD/安全复核 | P1 |
| 隐私与删除 | [KNOWN] 本地自动记录且加密，首次告知，可关闭/单删/清空；删除覆盖历史、进度、别名、排序、文字、图片及元数据并以 generation 防复活；AI 各调用仅发送必要字段 | 用户确认、coding rules、需求复核 | 业务与安全契约已确认；实现待 TDD/Review | P1 |
| AI 推荐 | [KNOWN] 本地规则生成到期集合；最多 50 个候选、每组一次排序取 10 个、缓存 30 分钟；Provider 只排序/解释，不得修改进度；失败使用稳定本地顺序 | 用户确认、`AIProvider`, `Prompts` | 业务契约和预算已确认；结构化响应待实现 | P1 |
| 复习状态机 | [KNOWN] 新词 24 小时首次到期；三档反馈按 10 分钟、1 天和 3/7/14/30/60/90 天更新；重复翻译立即入队但不重置进度 | 用户确认 | 业务契约已确认；时钟与幂等实现待设计 | P1 |
| 内容模型 | [KNOWN] 已保存词性词义立即显示；每个内容身份最多一次文字和一次图片调用；缓存加密且容量 128 MiB；图片标注 AI；真实台词需批准展示权来源，否则只显示无真实片名的影视化对白 | presentation、result UI、AI models、用户确认、安全复核 | 媒体、许可与调用契约已确认；实现待 TDD | P1 |
| UI 导航 | [KNOWN] 三端底部工具栏新增带到期数量的“复习”入口；全屏页包含“今日复习”和“历史记录” | 用户确认、`lib/app.dart` | 业务导航已确认；响应式实现待设计 | P2 |
| 数据迁移 | 新 Hive type/box 需要版本化与失败策略 | `lib/main.dart`, coding rules | 待设计 | P2 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| 加密、删除或最小化发送实现偏离已确认隐私策略 | P1 | [KNOWN] 自动采集、加密、保留至主动删除、关闭/单删/清空和最小候选摘要已由用户确认 | 在历史基础子需求中建立加密 store、派生数据删除和 Provider 请求字段契约测试 | 研发、安全/隐私负责人 |
| 分类实现偏离已确认契约，或多语言/缩写标点导致误收漏收 | P1 | [KNOWN] 五类 AI 分类、grapheme 本地保护、版本化缓存和旧缓存不补录已确认 | 建立结构化响应契约与中英日韩正反例，覆盖 80/81 grapheme、缩写标点和多句边界 | 研发、语言内容负责人 |
| 实现让 AI 越权修改进度，或失败降级顺序不稳定 | P1 | [KNOWN] 确定性规则拥有状态写权限，AI 仅排序/解释，降级排序已确认 | 分离 scheduler 与 ranker 接口；用固定时钟和相同输入重复验证稳定顺序 | 研发、学习体验负责人 |
| 调度间隔、连续次数或重复翻译行为实现错误 | P1 | [KNOWN] 三档反馈、首次到期、间隔上限和重复翻译规则已确认 | 使用注入时钟和表驱动测试覆盖每次转换、90 天封顶、重复点击和重复翻译 | 研发、学习体验负责人 |
| 规范化或并发 upsert 错误导致跨语言误合并、重复记录或进度丢失 | P1 | [KNOWN] 身份、别名、Provider 合并和保留进度规则已确认 | 用纯 identity value object、原子 repository upsert 和并发/多语言表驱动测试验证 | 研发、语言内容负责人 |
| AI 图片未标注/不安全/重复计费，或 AI 生成对白被误标为真实电影台词 | P1 | [KNOWN] 用户确认图片标注与主题图标降级，以及真实台词来源规则 | 为图片增加 capability、缓存、内容安全和标识契约；为电影内容增加来源/内容身份契约 | 产品、研发、版权/法务、内容安全负责人 |
| 调用上限、按需生成或缓存身份实现错误导致重复费用 | P1 | [KNOWN] 每组 10/候选 50/排序一次/30 分钟缓存，内容仅当前卡生成且不自动重试 | 对 ranker/content cache 注入调用计数器和固定时钟，验证反复进入、缓存命中、失败与手动重试 | 研发、产品负责人 |
| 删除/清空后的晚到响应重新创建历史或派生缓存 | P1 | 异步排序、文字和图片可能不可取消或晚到 | generation + 记录存在/Provider/模型/契约写前校验；竞态测试必须先红后绿 | 研发、安全/隐私负责人 |
| 密钥缺失或平台安全存储失败时回退明文/隐式换钥 | P1 | 用户已确认加密；旧密文若换钥将永久不可读 | Proposed ADR-0001；三端 secure key store 故障测试；仅允许显式安全清空重建 | 研发、安全/隐私负责人 |
| AI 自报影片名或来源被错误当作真实许可内容 | P1 | 当前 `MovieQuote`/prompt 没有可信来源字段 | 首期默认影视化对白；真实台词 adapter 必须接批准结构化源及许可字段 | 产品、版权/法务负责人 |
| 新历史和旧缓存职责混淆 | P2 | 旧 cache 不可枚举源词且 LRU 100 条 | 单独 repository/model，缓存仍只服务结果复用 | 研发负责人 |

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. 分阶段的三端本地混合复习（历史基础 → 确定性调度 + AI 排序 → 文字内容 → AI 插图） | 是且用户已逐项确认 | 独立加密历史仓库；确定性到期；AI 只分类/排序/生成辅助内容；图片由当前 Provider/模型按显式 capability 生成；无批准电影源时仅影视化对白 | AI/图片失败回退本地队列、文字卡和主题图标；删除 generation 防复活 | macOS/iOS/Android 本地使用；不含账号/同步/导入导出、影视剧照/海报/视频；不自动切换 Provider/模型 | 可测试、可解释、可离线降级，各阶段可独立回滚 | 需要平台安全存储、图片 capability、缓存、费用和内容安全验证 | 已选方案，九个 TDD 切片见第 10 节 |
| B. 全 AI 动态复习 | 否 | 每次打开把历史交给 AI，由 AI 选词并生成全部卡片 | AI 失败仅显示历史 | 可快速做演示，不建稳定调度 | 初期代码少、个性化叙事强 | 不稳定、费用和隐私高、难测、无可靠离线体验 | 不满足状态可复核和失败降级要求 |
| C. 一次性全媒体交付 | 否 | 同时建设历史、调度、图片搜索/生成、影视视频源和播放器 | 每个外部源单独降级 | 跨客户端、AI、媒体 API、版权和内容运营 | 体验完整 | 范围过宽、授权与来源未定、难以独立验收和回滚 | 已排除，超出首期范围 |

### 已确认拆分顺序

1. 子需求 A：历史基础——资格分类、独立持久化、隐私/删除和历史列表。
2. 子需求 B：复习状态机——反馈档位、确定性到期、AI 易忘排序和失败降级。
3. 子需求 C：文字学习卡——词性词义、生活常用语、文字电影台词及内容缓存。
4. 子需求 D：视觉媒体——当前 Provider 的可选 AI 图片 capability、异步生成、缓存、AI 标识、内容安全与主题图标降级；[KNOWN] 影视剧照、海报和视频不属于本 Feature 首期范围。

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | `TDD_INPUT_READY` |
| 下一步路由 | 按 TMR-01 → TMR-09 使用 `hicode:tdd`；每个任务独立记录 RED/GREEN/REFACTOR 证据 |
| 未覆盖设计树节点 | 无；ROOT、MAIN-1 至 MAIN-6、BRANCH-1 至 BRANCH-6 均有任务覆盖 |

### TMR-01：翻译分类契约与本地资格判定

| 字段 | 内容 |
|---|---|
| 目标 | 在同一次翻译响应中可靠获得实际源语言和五类语义分类，并用本地保护规则输出 `eligible` 或明确排除原因 |
| 对应节点 | MAIN-1、BRANCH-1、BRANCH-2 |
| 输入 | TMR-001；`Prompts.translateSystem`；`TranslationPresentation.outputContractVersion`；用户确认的五类分类与 grapheme/multisentence 规则 |
| 范围内 | `word/phrase/sentence/paragraph/unknown`、分类版本、实际源语言、80/81 grapheme、换行、多句、缩写、非法分类、旧缓存不补录；协议元数据不进入译文 UI |
| 范围外 | 不写历史、不创建复习状态 |
| 涉及对象 | `lib/core/ai/prompts.dart`、`lib/features/translate/models/translation_presentation.dart`；新增 `lib/features/review/domain/review_eligibility.dart`；对应 prompts/presentation/review tests |
| TDD 起点 | 先写五类解析和正反例失败测试，再实现 typed classification/eligibility；中英日韩 fixture 不含真实用户数据 |
| 验证方式 | focused tests；分类元数据不显示；只有 `word/phrase` 且本地保护通过时合格；缓存 output contract 升版 |
| 停止条件 | 无法把实际源语言和分类限制为版本化枚举；不得用自由文本猜测或对旧缓存静默补录 |
| 回滚 | 回退输出契约版本并移除纯资格模块，不产生持久化复习数据 |

### TMR-02：学习身份与复习领域模型

| 字段 | 内容 |
|---|---|
| 目标 | 建立稳定、跨 Provider 合并且隔离语言方向的学习身份和 typed review entry |
| 对应节点 | MAIN-2、BRANCH-5 |
| 输入 | TMR-007；纠正词条、原始别名、实际源语言、目标语言、翻译内容和复习字段 |
| 范围内 | 经审查的 NFKC、去首尾/合并空白、适用语言大小写折叠、别名、同形异语言、跨 Provider 合并、保留进度 |
| 范围外 | 不接 Hive、不加密、不改控制器 |
| 涉及对象 | 新增 `lib/features/review/models/review_entry.dart`、`lib/features/review/domain/review_identity.dart` 及对应测试；若需要 Unicode normalization 依赖，先验证维护状态并记录依赖证据 |
| TDD 起点 | 先写 NFKC、空白、大小写、纠错别名、语言方向和 Provider 切换表驱动失败测试 |
| 验证方式 | 相同身份稳定相等/哈希；Provider/模型不参与；不同实际语言或方向不合并；identity 序列化不含不稳定字段 |
| 停止条件 | 找不到经过审查且可维护的 NFKC 实现时返回 Scope；不得手写不完整 Unicode normalization |
| 回滚 | 删除纯领域模块，无数据迁移 |

### TMR-03：平台安全密钥与独立加密仓库

| 字段 | 内容 |
|---|---|
| 目标 | 用独立复习密钥加密历史和所有派生数据，并提供原子 upsert、彻底删除、有限缓存与明确 unavailable 状态 |
| 对应节点 | MAIN-2、BRANCH-3、BRANCH-4、BRANCH-6 |
| 输入 | TMR-004、TMR-009、TMR-010；Proposed ADR-0001；TMR-02 typed model |
| 范围内 | `ReviewKeyStore` 平台安全存储 adapter；AES-256-GCM envelope、schema/AAD/keyId、opaque key；独立 history/content store；128 MiB 派生缓存 LRU；generation；单删/清空/安全重建；iOS backup exclusion |
| 范围外 | 不接翻译、不做 UI、不改变 Provider 凭证生命周期 |
| 涉及对象 | 新增 `lib/features/review/data/review_repository.dart`、`encrypted_review_repository.dart`、`review_store_codec.dart`、secure key adapter；`lib/main.dart`、`lib/core/platform/local_storage_protection.dart`；repository/security tests |
| TDD 起点 | 先写密文无明文、AAD/篡改/错钥、密钥缺失、并发 upsert、写失败、删除级联、晚到写入、128 MiB 淘汰和 Provider reset 隔离测试 |
| 验证方式 | 原始 Hive/文件不含词条、别名、译文或生成内容；密钥不与密文同库；并发不丢次数/进度；删除后查询、到期列表和派生缓存均不可见 |
| 停止条件 | ADR-0001 被拒绝，或任一目标平台安全存储无法验证；不得改用明文、普通密钥文件或复用 `.aitrans.provider.key` |
| 回滚 | 业务主流程接入前可移除新 box/adapter；产生测试数据时只通过 repository 安全清空 |

### TMR-04：翻译成功后的历史采集

| 字段 | 内容 |
|---|---|
| 目标 | 在最终有效翻译完成后按资格和采集开关最多 upsert 一次历史，同时保持基础翻译独立成功 |
| 对应节点 | MAIN-1、MAIN-2、BRANCH-1、BRANCH-3 |
| 输入 | TMR-01 eligibility、TMR-02 identity、TMR-03 repository；当前 controller request generation |
| 范围内 | 缓存命中、即时/防抖翻译、过期响应、重复完成、关闭采集、非法分类、仓库 unavailable/写失败和安全提示状态 |
| 范围外 | 不生成复习队列或学习内容 |
| 涉及对象 | `lib/features/translate/logic/translate_controller.dart`；新增 `lib/features/review/logic/review_capture_service.dart`；controller/capture tests |
| TDD 起点 | 先写缓存命中更新次数、同 generation 只写一次、旧 generation 不写、关闭不写、失败仍 `TranslateComplete` 的测试 |
| 验证方式 | 每个有效完成最多一次 upsert；缓存命中一致；复习写失败不改变有效译文，且只显示脱敏“历史未保存/不可用”状态 |
| 停止条件 | 接入会绕过现有 stale-response protection，或错误信息可能泄露用户文本/密钥/路径 |
| 回滚 | 移除注入的 capture service，基础翻译和 LRU cache 行为不变 |

### TMR-05：确定性调度与反馈幂等

| 字段 | 内容 |
|---|---|
| 目标 | 用纯领域状态机实现首次到期、三档反馈、重复翻译强制到期和 UTC 调度 |
| 对应节点 | MAIN-4、MAIN-6 |
| 输入 | TMR-006；注入 UTC clock；ReviewEntry |
| 范围内 | 24 小时首次到期；忘记 10 分钟；模糊 1 天；记得 3/7/14/30/60/90 天并封顶；重复事件 ID；重译立即到期但不重置；系统时钟回拨不逆转已提交反馈 |
| 范围外 | AI 不参与状态变化，不做 UI |
| 涉及对象 | 新增 `lib/features/review/domain/review_scheduler.dart`、`review_feedback.dart` 及表驱动测试 |
| TDD 起点 | 用固定 UTC 时钟写每档转换、边界瞬间、90 天封顶、重复点击和重译标记失败测试 |
| 验证方式 | 只显式反馈改变连续/忘记次数；重复事件幂等；存储 UTC instant，显示层才转换本地时区 |
| 停止条件 | 实现需要 AI 或 UI 状态才能计算；不得把观看时长等同掌握 |
| 回滚 | 纯领域模块可独立移除，无持久化迁移 |

### TMR-06：候选选择、AI 排序与组快照

| 字段 | 内容 |
|---|---|
| 目标 | 从本地到期集合形成 50 候选/10 卡组快照，并让 AI 只排序解释且有稳定降级和费用缓存 |
| 对应节点 | MAIN-4、BRANCH-2、BRANCH-6 |
| 输入 | TMR-002、TMR-008、TMR-009、TMR-010；scheduler/repository；当前 AI 配置 |
| 范围内 | 稳定本地排序含 identity 平局键；每组一次 AI；候选 ID 子集校验；30 分钟缓存及事件失效；删除 generation；独立生命周期的复习 AI Provider 实例，避免 `cancelActiveRequests()` 与翻译互相取消 |
| 范围外 | AI 不写进度、不返回新词条、不生成卡片内容 |
| 涉及对象 | 新增 `lib/features/review/logic/review_queue_controller.dart`、`lib/features/review/services/review_ranker.dart`、`lib/core/ai/review_ai_models.dart`；修改 `ai_provider.dart` 和 Provider adapters；契约测试 |
| TDD 起点 | 先写 50/10、一次调用、TTL/事件失效、未知/重复 ID、非法 JSON、超时/取消、本地平局和删除晚到测试 |
| 验证方式 | 请求只含批准最小字段；响应只改变顺序/原因；相同输入稳定；反复进入命中缓存；翻译请求不被复习取消 |
| 停止条件 | AI 响应无法限制为候选 ID 子集，或无法隔离翻译/复习请求生命周期；不得信任模型新增词条 |
| 回滚 | 卸下 AI ranker 后保留本地稳定排序和组快照 |

### TMR-07：三端入口、历史管理与隐私告知

| 字段 | 内容 |
|---|---|
| 目标 | 在 macOS/iOS/Android 提供到期 badge、全屏今日复习/历史页和完整隐私管理入口 |
| 对应节点 | MAIN-3、BRANCH-3、BRANCH-4、BRANCH-6 |
| 输入 | repository/history state、capture preference、due count；已确认导航和删除规则 |
| 范围内 | 首次告知、关闭采集、单删/清空确认、安全重建、unavailable/empty 状态、返回后保持翻译输入/结果、generation 防晚到复活 |
| 范围外 | 不含账号、同步、导入或导出 |
| 涉及对象 | `lib/app.dart`、`lib/features/settings/ui/settings_page.dart`；新增 `lib/features/review/ui/review_page.dart`、`history_view.dart`、`lib/features/review/logic/review_history_controller.dart`；widget tests |
| TDD 起点 | 先写三端 platform override 下的底栏入口/badge、全屏路由、告知、空态、关闭、删除/清空和 unavailable 测试 |
| 验证方式 | 三端响应式 widget tests；关闭不隐式清空；删除立即更新 badge/list；晚到结果不复活；错误不含原始文本 |
| 停止条件 | 删除绕过 repository、清空没有确认、或 UI 在 secure store 失败时允许继续写入 |
| 回滚 | 移除路由和底栏入口；加密历史数据不受影响，可由 repository 管理 |

### TMR-08：文字学习内容与电影内容身份

| 字段 | 内容 |
|---|---|
| 目标 | 为当前卡按需生成一次结构化文字内容，并严格区分已批准真实台词与 AI 影视化对白 |
| 对应节点 | MAIN-5、BRANCH-2、BRANCH-5、BRANCH-6 |
| 输入 | TMR-003、TMR-008 至 TMR-010；已保存词义；当前 Provider/模型；加密 content repository |
| 范围内 | 当前卡首次展示请求、不预取；生活常用语 + 电影字段一次文字调用；缓存身份/加密/删除；超时/非法字段；手动只重试文字；真实内容的作品/来源/许可字段 |
| 范围外 | 首期不接外部真实电影内容源；无批准源时只允许“影视化场景对白”且不显示影片名 |
| 涉及对象 | 新增 `lib/features/review/models/review_content.dart`、`services/review_content_service.dart`、`ui/review_card.dart`；修改 `prompts.dart`、`ai_provider.dart`；model/service/widget/provider tests |
| TDD 起点 | 先写立即显示已有词义、首次展示才调用、无预取、缓存、失败不自动重试、AI 自报影片名被拒绝、删除晚到测试 |
| 验证方式 | 每内容身份自动文字调用最多一次；请求无别名/完整历史/长句；失败降级已有词义；无批准 adapter 时 UI 只显示标注对白 |
| 停止条件 | 实现把 AI 自报来源当许可，或无法为真实内容提供应用批准的结构化 source/rights metadata |
| 回滚 | 卡片退回已保存词义，不影响历史、调度和反馈 |

### TMR-09：AI 图片 capability 与端到端闭环

| 字段 | 内容 |
|---|---|
| 目标 | 为当前卡按 capability 生成并加密缓存 AI 记忆插图，同时完成从翻译到再次调度的端到端闭环 |
| 对应节点 | MAIN-5、BRANCH-5、BRANCH-6、ROOT |
| 输入 | TMR-03 至 TMR-08；当前 Provider/当前模型显式 image capability；内容 generation |
| 范围内 | 默认 unsupported；成功/超时/安全拒绝；每内容身份一次自动图片调用；不预取/不自动重试/不切换 Provider 或模型；AI 标识；128 MiB 派生缓存；删除/Provider/契约变化和晚到结果；手动只重试图片 |
| 范围外 | 不静默选择其他图片模型，不含图库、剧照、海报或视频 |
| 涉及对象 | `lib/core/ai/ai_provider.dart`、`provider_factory.dart`、相应 live adapter；新增 `lib/features/review/services/review_image_service.dart`；`review_card.dart`、加密 content repository；provider/service/widget/integration tests |
| TDD 起点 | 先写 unsupported、假 capability 成功、调用上限、缓存命中、删除/切换/晚到、安全拒绝、主题图标和完整闭环失败测试 |
| 验证方式 | 假 Provider + 内存 repository + 固定时钟走通“翻译 → 历史 → 到期 → 排序 → 卡片 → 反馈 → 再到期”；live adapter 只在 endpoint/返回格式/capability 已核验时启用 |
| 停止条件 | 当前 Provider/当前模型的图片 endpoint、返回格式或 capability 无法核验时，不实现 live adapter，也不得声称 AI 图片已交付；capability 抽象与可访问主题图标降级仍可完成 |
| 回滚 | 关闭 image capability 后卡片稳定使用主题图标，其他闭环不受影响 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 测试优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1 | 五类分类、grapheme 保护、排除原因、契约版本和旧缓存 | 单元/契约 | P0 | 中英日韩、80/81 grapheme、换行、多句、缩写 fixture | TMR-01 |
| MAIN-2/BRANCH-3 | NFKC identity、AES envelope、secure key、并发 upsert、密钥/篡改失败 | identity/repository/security | P0 | 匿名多语言 fixture、内存/故障 secure store | TMR-02、TMR-03 |
| MAIN-1/2/BRANCH-1 | 有效/过期响应、缓存命中、关闭采集、写失败 | controller/service | P0 | 假 Provider、内存/故障 repository | TMR-04 |
| MAIN-4/6 | UTC 到期、三档反馈、重复事件/重译、50/10、AI 一次、稳定排序/缓存 | domain/ranker contract | P0 | 固定时钟、调用计数、结构化 AI fixture | TMR-05、TMR-06 |
| MAIN-3/BRANCH-4/6 | 三端入口、告知、单删/清空、unavailable、晚到防复活 | repository/widget | P0 | 匿名 fixture、platform override、延迟 future | TMR-03、TMR-07 |
| MAIN-5/BRANCH-2/5/6 | 当前卡按需文字/图片、许可身份、加密缓存、失败/手动重试/晚到 | content/provider/widget | P0 | 假文字/图片 Provider、调用计数、许可 metadata | TMR-08、TMR-09 |
| ROOT | 翻译到历史、到期、排序、渐进卡片、反馈和再次到期 | integration/widget | P1 | 假 Provider、内存 repository、固定时钟 | TMR-09 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | 是 |
| 判断理由 | 加密格式和密钥生命周期在产生用户历史后难以无损切换；复用 Provider 凭证密钥会让凭证重置破坏历史；平台安全存储、普通密钥文件和共享密钥存在真实取舍且缺少上下文容易误实现 |
| 涉及决策点 | 独立复习密钥、平台安全存储、AES-256-GCM envelope、Provider reset 隔离、显式安全清空、128 MiB 派生缓存和 generation 防复活 |
| 草稿状态 | 已创建 `docs/adr/ADR-0001-review-data-encryption-key-lifecycle.md`，状态 `Proposed`，待负责人确认 |

[KNOWN] 独立历史仓库、确定性调度/AI 只排序、当前 Provider 图片 capability 与主题图标降级均为可替换模块边界，不另立 ADR。未来引入跨设备同步、独立媒体 Provider 或外部影视内容源时重新评估。

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | 建议新增术语/规则 | Translation history、Review item、Due item、Review group、Mastery feedback、Derived content cache，以及 TMR-001 至 TMR-010 | 当前不更新；长期领域文档需负责人确认 | 待负责人确认 |
| `docs/PROJ_CONTEXT.md` | 建议新增 Feature 索引 | `translation-memory-review`，建议状态 `TDD_INPUT_READY`，模块涉及 review domain/data/logic/ui、translate、AI 和 secure storage | 当前不更新；正式 Feature 索引需负责人确认 | 待负责人确认 |
| `docs/adr/ADR-0001-review-data-encryption-key-lifecycle.md` | 新建 Proposed ADR | 复习域独立平台安全密钥、AES envelope、Provider reset 隔离、删除防复活和派生缓存 | 已创建；保持 Proposed | 待负责人确认 |

## 14. 澄清记录

### 已关闭

- [KNOWN] 用户确认 feature-id 为 `translation-memory-review`。
- [KNOWN] 长句不进入翻译复习记录。
- [KNOWN] 复习内容目标包括图片、词性词义、生活常用语和电影片段。
- [KNOWN] 本地自动记录且加密；首次进入复习时告知；设置中可关闭；保留至用户主动删除；支持单删和清空。
- [KNOWN] 排序、文字和图片调用分别只接收完成该调用所需的词条、语言及必要状态，不发送原始别名、完整历史、长句原文或无关数据。
- [KNOWN] “电影片段”首期只做文字；真实台词必须来自应用内批准且有展示权的结构化源并携带作品/来源/许可字段；AI 自报来源无效；首期无批准源时只显示不带真实片名的影视化对白；不含剧照、海报和视频。
- [KNOWN] 图片由当前配置 Provider 异步生成、按词条缓存并标注“AI 生成”；Provider 不支持或失败时使用主题图标，不自动切换 Provider。
- [KNOWN] 记录资格使用同一次翻译响应的版本化五类语义分类，仅接受 `word`/`phrase`，并由客户端强制排除换行、超过 80 个 Unicode grapheme cluster 或具有多个句子边界的输入；旧缓存不自动补录。
- [KNOWN] 确定性间隔重复生成到期集合，AI 只按最小摘要排序并解释，不修改进度；AI 失败时按逾期时长、忘记次数和最近复习时间稳定降级。
- [KNOWN] 新词 24 小时首次到期；忘记为 10 分钟并清零连续次数、忘记次数加一；模糊为 1 天且连续次数不增加；记得按 3/7/14/30/60/90 天递进并以 90 天封顶；重复翻译立即入队但不重置进度。
- [KNOWN] 学习身份为规范化纠正词条 + 实际源语言 + 目标语言；原文作别名；Provider 不参与身份；重复翻译更新次数/时间/最新有效内容并保留复习进度。
- [KNOWN] macOS、iOS、Android 同时提供本地历史/复习；底部工具栏新增带到期数量的入口，全屏页包含“今日复习”和“历史记录”；首期不含账号、跨设备同步、导入或导出。
- [KNOWN] 每组最多 10 个，本地候选最多 50 个，每组最多一次 AI 排序且缓存 30 分钟；文字/图片只为当前卡首次展示时生成，不预取、不自动重试，并按学习身份 + Provider/模型 + 契约版本缓存。

### 待回答

当前无待用户回答的业务问题。业务、研发、测试、安全/隐私、版权/内容负责人仍待指定，其复核不作为当前 Scope 业务规则阻断；触发任一 TDD 停止条件时必须返回 Scope。

## 15. Feature 文档清单

| 文档 | 本次状态 | 说明 |
|---|---|---|
| `docs/features/translation-memory-review/feature_context.md` | 已创建并收敛 | 记录已确认事实、闭合设计树、安全基线、影响范围和关闭问题 |
| `docs/features/translation-memory-review/scope-plan.md` | 已创建并收敛 | 记录 `TDD_INPUT_READY`、方案取舍、九个 TDD 切片、停止条件与验证重点 |
| `docs/features/translation-memory-review/tdd-report.md` | 跳过 | 本次仅完成 Scope；进入 `hicode:tdd` 后按任务创建/更新 |
| `docs/adr/ADR-0001-review-data-encryption-key-lifecycle.md` | 已创建 | 状态 `Proposed`；需负责人确认，不代表 Accepted |

`TDD_INPUT_READY` 只表示当前证据足以建议按九个切片进入测试先行工作；不代表负责人批准编码、风险已最终接受或允许发布。
