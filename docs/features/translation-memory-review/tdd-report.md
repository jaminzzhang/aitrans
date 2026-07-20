# 翻译记忆与趣味复习：TDD 实施报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | `LOCAL_VERIFIED`（TMR-01 至 TMR-09） |
| 最高风险等级 | `P1` |
| 模式 | 受控实现；完整留痕 |
| 实施日期 | [KNOWN] 2026-07-18 至 2026-07-20 |
| 结论边界 | [KNOWN] 只表示九个切片的本地行为通过验证，包括图片 capability/加密缓存/主题图标降级、反馈账本持久化和“翻译 → 再次到期”闭环；当前 Provider/模型图片 endpoint、返回格式和 capability 没有可核验证据，因此未实现 live 图片 adapter，也不代表真实 AI 图片、ADR 接受、合并或发布许可 |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 测试目标 | [KNOWN] 在 TMR-01 至 TMR-08 上补齐显式图片 capability、当前卡按需图片缓存与主题图标降级，并把三档反馈事件账本原子写入加密词条，完成从翻译采集、到期排序、卡片、反馈到再次到期的闭环 |
| 公开接口 | [KNOWN] 新增 `ReviewAIImageRequest` / `ReviewAIImageResponse` / `ReviewAIImageCapability`、`AIProvider.generateReviewImage(...)`、`ReviewImageService`、`ReviewRepository.applyFeedback(...)`；扩展 `ReviewEntry` 反馈账本、`ReviewDeck` 反馈回调与 `ReviewHistoryController.submitFeedback(...)` |
| 可观察行为 | [KNOWN] 当前 Provider/模型未显式支持图片时卡片显示可访问主题图标且零图片调用；假 capability 成功时显示“AI 生成插图”；图片失败不自动重试且只提供图片手动重试；三档反馈完成当前卡和本组，固定时钟推进后按 10 分钟/1 天/记忆阶梯再次到期 |
| 不测试的实现细节 | 私有正则拆分、内部循环顺序和临时集合结构 |
| 本轮不覆盖 | [KNOWN] 未经核验的 live 图片 adapter、付费远端图片调用、图库/剧照/海报/视频、真实电影内容源、ADR 接受和发布操作 |

## 3. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| TMR01-S01 | 同次响应携带实际源语言、版本 `1` 和 `word/phrase/sentence/paragraph/unknown` | Prompt/解析契约 | P0 | P1 |
| TMR01-S02 | 旧响应、错误版本、非法/重复/半截元数据不被猜测或暴露 | 解析/流式边界 | P0 | P1 |
| TMR01-S03 | 只有当前版本、已知源语言和 `word`/`phrase` 可通过语义闸门 | 纯领域单元 | P0 | P1 |
| TMR01-S04 | 原文与纠正后源文都执行换行、80/81 grapheme 和多句保护 | 纯领域边界 | P0 | P1 |
| TMR01-S05 | 英文缩写、首字母缩写、小数点以及中日韩无空格短语不被本地规则误杀 | 多语言回归 | P0 | P1 |
| TMR01-S06 | 分类协议字段不进入 Result UI 或复制文本 | Widget | P0 | P1 |
| TMR01-S07 | output contract 从 `4` 升至 `5`，相关控制器和缓存身份行为保持通过 | 回归 | P1 | P2 |
| TMR02-S01 | NFKC 覆盖全半角、组合字符、日文半角片假名，并合并首尾/连续空白 | 纯领域单元 | P0 | P1 |
| TMR02-S02 | 代表性有大小写语言规范化后身份相等且哈希稳定 | 纯领域单元 | P0 | P1 |
| TMR02-S03 | 同形异语言或不同目标语言保持独立；Provider/模型不进入身份序列化 | 纯领域单元 | P0 | P1 |
| TMR02-S04 | 首次翻译建立 typed entry；跨 Provider 重译合并别名/次数/最新内容并保留全部复习进度 | 纯领域单元 | P0 | P1 |
| TMR02-S05 | 较旧完成仍累计翻译和别名，但不能覆盖最新时间与内容；集合为不可变快照 | 并发保护/不可变性 | P1 | P1 |
| TMR02-S06 | 最新内容的源词必须经同一规范化后属于对应学习身份 | 领域不变量 | P0 | P1 |
| TMR03-S01 | AES-256-GCM 信封覆盖 identity、别名、译文、进度和派生内容；opaque Hive key 与原始文件均无明文 | 编解码/真实落盘 | P0 | P1 |
| TMR03-S02 | AAD 绑定数据类型/schema/opaque key；移动、篡改、错误 keyId 或错误密钥均拒绝 | 安全故障注入 | P0 | P1 |
| TMR03-S03 | 平台安全密钥损坏、不可读或密文存在但缺钥时显式不可用且绝不隐式替换 | 密钥生命周期 | P0 | P1 |
| TMR03-S04 | 同 identity 并发 upsert 串行提交，别名和次数不丢；写失败保留旧记录 | 并发/原子性 | P0 | P1 |
| TMR03-S05 | 单删级联历史和全部派生内容；全清先删密文再删密钥；Provider key reset 不影响复习 | 删除/隔离 | P0 | P1 |
| TMR03-S06 | 全局 generation 阻止删除后的迟到派生写挂到重建词条 | 异步一致性 | P0 | P1 |
| TMR03-S07 | 派生缓存按明文字节计入 128 MiB 上限并按最后访问时间 LRU 淘汰 | 容量边界 | P1 | P1 |
| TMR03-S08 | Android API 24、iOS 13、macOS 10.15 编译通过；macOS 系统 Keychain 元数据可见且 Debug App 单进程存活 | 平台集成 | P0 | P1 |
| TMR04-S01 | 合格纠正词条以原文别名、实际源语言、目标语言、译文和词性词义写入仓库 | service/repository contract | P0 | P1 |
| TMR04-S02 | 关闭采集或分类不可复习时不访问仓库；分类排除优先于仓库不可用提示 | service boundary | P0 | P1 |
| TMR04-S03 | 缓存命中、立即翻译和防抖翻译均进入同一采集路径；独立缓存完成各写一次 | controller integration | P0 | P1 |
| TMR04-S04 | 过期 generation 不写；同 generation 重复完成最多写一次 | stale/idempotency | P0 | P1 |
| TMR04-S05 | 仓库 unavailable、写失败或采集边界意外异常不改变 `TranslateComplete`，只返回 typed 脱敏状态 | failure isolation | P0 | P1 |
| TMR04-S06 | Riverpod Provider 图把安全仓库构造成采集服务并暴露最新 typed 结果 | dependency integration | P1 | P1 |
| TMR05-S01 | 新词以 `createdAt + 24h` 首次到期，到期边界包含等于且输出统一为 UTC | 纯领域时间边界 | P0 | P1 |
| TMR05-S02 | 忘记、模糊、记得分别按 10 分钟、1 天和 3/7/14/30/60/90 天更新进度 | 表驱动领域单元 | P0 | P1 |
| TMR05-S03 | 记得间隔在 90 天封顶；只有显式反馈改变连续/忘记计数 | 领域不变量 | P0 | P1 |
| TMR05-S04 | 同一反馈事件 ID 重放不重复更新；恢复的事件 ID 被规范化并保持不可变 | 幂等/不可变性 | P0 | P1 |
| TMR05-S05 | 到期前重译立即到期但不重置进度或反馈账本 | 状态流转 | P0 | P1 |
| TMR05-S06 | 系统时钟早于已提交业务时间时不回退 `lastReviewedAt` 或 `nextReviewAt` | 时钟回拨保护 | P0 | P1 |
| TMR06-S01 | 到期集合按逾期、忘记次数、最近复习时间和学习身份稳定排序，最多取 50 个 | 纯逻辑/表驱动 | P0 | P1 |
| TMR06-S02 | 一次 AI 请求从 50 候选形成最多 10 卡不可变快照，AI 只能改变顺序和原因 | controller/ranker contract | P0 | P1 |
| TMR06-S03 | 请求只含 opaque ID、规范词条、语言、必要计数和相对时间 | 隐私契约 | P0 | P1 |
| TMR06-S04 | 未知、重复、缺失 ID 或非法 JSON 整组稳定降级，不产生新词条或进度写入 | 不可信响应 | P0 | P1 |
| TMR06-S05 | AI 超时、取消或失败不重试，成功/失败结果均缓存 30 分钟 | 费用/可靠性 | P0 | P1 |
| TMR06-S06 | 新增/删除/反馈/重译等事件显式失效缓存并只取消复习 Provider | 生命周期/隔离 | P0 | P1 |
| TMR06-S07 | AI 完成后重读仓库；删除或 generation 改变时丢弃晚到响应 | 并发一致性 | P0 | P1 |
| TMR06-S08 | OpenAI-compatible 与 Claude 分别使用一次结构化请求；Claude 排序可取消 | Provider 契约 | P0 | P1 |
| TMR07-S01 | 底部入口从本地仓库计算到期 badge，不因展示 badge 调用 AI，超过 99 显示 `99+` | Widget/费用边界 | P0 | P1 |
| TMR07-S02 | macOS/iOS/Android 均以全屏页打开“今日复习/历史记录”，返回后翻译输入与结果保持 | 三端导航/状态 | P0 | P1 |
| TMR07-S03 | 复习队列 controller 保持应用生命周期，退出再进入相同候选仍命中组缓存 | Provider 生命周期 | P0 | P1 |
| TMR07-S04 | 首次隐私告知只出现一次；采集偏好以严格 schema 持久化，损坏数据不得静默重新开启 | 隐私/持久化 | P0 | P1 |
| TMR07-S05 | 设置页开关先保存再改变运行时采集；关闭不删除历史，保存失败保持关闭并脱敏提示 | 设置/故障隔离 | P0 | P1 |
| TMR07-S06 | 历史空态、列表、单删和清空可观察；危险操作确认后先失效/取消队列再改仓库 | 历史管理/一致性 | P0 | P1 |
| TMR07-S07 | 加密仓库不可用时暂停采集并只允许确认安全重建；成功恢复偏好，失败不泄露异常 | 安全恢复/降级 | P0 | P1 |
| TMR07-S08 | 删除期间晚到排序不得复活词条；320px 宽度仍无溢出且触控目标不少于 48pt | 并发/UI 边界 | P0 | P1 |
| TMR08-S01 | 文字请求只含规范词条、源/目标语言和已保存主词义；响应严格限于生活用语和虚构对白 | AI 契约/隐私 | P0 | P1 |
| TMR08-S02 | AI 文字内容永远标识为影视化场景对白；批准真实台词必须具备作品、来源和许可字段 | 内容身份/合规 | P0 | P1 |
| TMR08-S03 | 当前卡立即显示保存的主词义、词性、读音和补充词义；未切换的卡不预取 | Widget/调用预算 | P0 | P1 |
| TMR08-S04 | 每个学习身份 + Provider/模型 + 契约内容身份自动调用最多一次；成功缓存命中不再调用 | Service/缓存 | P0 | P1 |
| TMR08-S05 | 失败标记加密持久化且不自动重试；只有显式文字重试产生下一次调用 | 费用/降级 | P0 | P1 |
| TMR08-S06 | 20 秒超时取消独立文字 Provider，不影响翻译和排序 Provider 实例 | Provider 生命周期 | P0 | P1 |
| TMR08-S07 | 删除或 Provider 上下文失效时取消文字请求；不可取消的晚到结果校验 entry/generation 后丢弃 | 并发一致性 | P0 | P1 |
| TMR08-S08 | 文字成功/失败记录只通过加密派生 repository 保存，缓存 ID 不含明文词条，原始 store 无生成明文 | 加密/删除 | P0 | P1 |
| TMR09-S01 | Provider/模型图片 capability 默认 `unsupported`；未显式启用时不调用、不缓存、不切换 Provider/模型 | Provider 契约/费用 | P0 | P1 |
| TMR09-S02 | 支持的假图片 Provider 每内容身份自动调用最多一次；请求仅含词条、语言和主词义，响应限制 PNG/JPEG、8 MiB 和文件签名 | AI 契约/隐私 | P0 | P1 |
| TMR09-S03 | 图片成功/失败按 Provider/模型与契约隔离进入 AES-GCM 派生缓存；超时、安全拒绝和失败均不自动重试，只有图片按钮手动重试 | 缓存/降级/费用 | P0 | P1 |
| TMR09-S04 | 删除、清空或 Provider 上下文失效会取消图片请求；晚到响应经 revision、entry 与 generation 校验后丢弃 | 并发一致性 | P0 | P1 |
| TMR09-S05 | 主题图标具备可访问标签；成功图片明确标注“AI 生成插图”，未支持图片仍可完成反馈 | Widget/可访问性 | P0 | P1 |
| TMR09-S06 | 反馈事件 ID、三档计数和时间原子写入加密 entry；并发/重启后重复事件只应用一次 | 持久化/幂等 | P0 | P1 |
| TMR09-S07 | 当前卡三档反馈后从组中移除；组末可开始下一组，固定时钟边界重新生成到期队列 | 状态流转/UI | P0 | P1 |
| TMR09-S08 | 假 Provider、内存 repository 和固定时钟走通翻译采集、24 小时到期、排序、渐进卡片、反馈和 10 分钟再次到期 | 端到端闭环 | P0 | P1 |

## 4. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| TMR01-GWT-01 | Provider 返回完整版本化协议和译文 | 解析响应 | 返回 typed 源语言/分类；`translationText` 只含译文内容 |
| TMR01-GWT-02 | 响应缺少协议、版本不支持、枚举非法、字段重复或仍在流式输出半截标签 | 解析响应 | 分类为 `unknown` 或译文保持空；不得从自由文本推断或展示协议标签 |
| TMR01-GWT-03 | 分类为当前版本 `word`/`phrase`、源语言已知且两份源文均通过本地保护 | 执行资格判定 | 返回 `isEligible == true` 且无排除原因 |
| TMR01-GWT-04 | 任一源文含换行、超过 80 个 grapheme 或含多个句界 | 执行资格判定 | 分别返回稳定的 typed 排除原因 |
| TMR01-GWT-05 | 旧缓存内容不含分类元数据 | 解析旧响应 | `reviewClassificationVersion == null` 且分类为 `unknown`，不自动补录 |
| TMR02-GWT-01 | 全角/组合/半角字符、不同空白和大小写形式表示同一纠正词条 | 创建 identity | 产生同一规范化词条，相等且哈希一致 |
| TMR02-GWT-02 | 词形相同但实际源语言或目标语言不同 | 创建 identity | 身份不相等，不会跨语言方向合并 |
| TMR02-GWT-03 | 相同身份被另一个 Provider 再次翻译 | `recordTranslation` | 合并原始别名，次数加一，更新最新内容，并原样保留连续次数、忘记次数、复习时间、强制到期和 generation |
| TMR02-GWT-04 | 较早的并发翻译完成较晚到达 | `recordTranslation` | 次数和别名仍合并，但最新时间/内容不回退 |
| TMR02-GWT-05 | 内容源词与 identity 的规范词条不同 | 创建或更新 entry | 拒绝构造，避免后续仓库出现主键与展示内容错配 |
| TMR03-GWT-01 | entry 含虚构原文、别名、译文和全部进度 | 写入真实 Hive 盒并扫描 raw map/文件字节 | 只出现版本化 AES-GCM 信封和 opaque key，所有业务明文均不存在 |
| TMR03-GWT-02 | 已有任意复习密文但安全密钥缺失/损坏 | 查询命中或未命中的 identity | 仓库进入 `unavailable`，不返回伪空结果、不创建替代密钥、不回退明文 |
| TMR03-GWT-03 | 三次同 identity 翻译并发完成 | repository upsert | 返回计数 1/2/3；最终三别名和最新内容完整，原始存储无明文 |
| TMR03-GWT-04 | 写新 envelope 前存储故障 | 更新已有 entry | 抛出脱敏不可用异常；重开仓库仍读取旧次数和别名 |
| TMR03-GWT-05 | 词条删除后又重建，旧 generation 的图片结果迟到 | 写入派生内容 | 返回 `false`；新词条 generation 更大，派生盒保持空 |
| TMR03-GWT-06 | 派生缓存超过配置上限 | 写入第二个内容 | 删除最久未访问的可再生成内容，保留最近内容；单删/全清仍覆盖所有派生数据 |
| TMR04-GWT-01 | 最终有效的纠正短语、实际源语言和目标语言可用 | `ReviewCapture.capture` | 使用纠正词条建 identity、原文作别名，按注入 UTC 时钟写入完整 typed 内容 |
| TMR04-GWT-02 | 采集关闭或语义分类为 sentence | 尝试采集 | 分别返回 `disabled` / `excluded`，仓库调用为零；sentence 不因仓库不可用误报错误 |
| TMR04-GWT-03 | 缓存命中或联网流式最终完成 | 控制器发布 `TranslateComplete` | 异步触发一次采集；即时与防抖路径一致，重复完成不新增调用 |
| TMR04-GWT-04 | 较早缓存查询在新 generation 后返回 | 控制器处理结果 | 旧译文不覆盖当前状态，也不创建历史记录 |
| TMR04-GWT-05 | 仓库不可用、写失败或采集接口意外抛错 | 最终有效翻译完成 | 译文保持 `TranslateComplete`；结果仅为 `unavailable` 或 `failed`，不含异常、路径或用户文本 |
| TMR05-GWT-01 | 未复习词条创建于固定 UTC 时间 | 查询到期时间和边界 | 返回创建时间后 24 小时；早一瞬间未到期，边界时刻到期 |
| TMR05-GWT-02 | 同一词条依次处于不同连续记得次数 | 提交忘记、模糊或记得事件 | 更新对应计数并按 10 分钟、1 天或递进间隔生成 UTC `nextReviewAt`；同时清除强制到期 |
| TMR05-GWT-03 | 已应用反馈事件被再次提交 | 以相同事件 ID 调用调度器 | 返回同一状态对象，计数、时间和账本均不再次变化 |
| TMR05-GWT-04 | 未到期词条再次被翻译 | 标记重译 | `isDue` 立即为真；连续次数、忘记次数和已应用事件 ID 原样保留 |
| TMR05-GWT-05 | 注入时钟早于最近翻译或最近复习时间 | 提交新反馈 | 以已提交业务时间为下界，复习时间和下次到期不会倒退 |
| TMR06-GWT-01 | 本地存在 55 个到期条目 | 开始一组复习 | 按稳定规则只发送前 50 个，返回最多 10 卡，同时保留总到期数 55 |
| TMR06-GWT-02 | AI 请求失败、超时、取消或返回未知/重复/缺失 ID | 构建组快照 | 按逾期降序、忘记次数降序、最近复习时间升序和身份平局键本地降级；进度不变 |
| TMR06-GWT-03 | 相同候选、Provider/模型和契约在 30 分钟内重复进入 | 再次构建组 | 命中成功或失败快照缓存，不再次调用 AI；30 分钟边界重新请求 |
| TMR06-GWT-04 | 排序请求进行中删除词条或用更高 generation 重建 | 旧 AI 响应晚到 | 重读仓库后丢弃旧顺序，返回当前本地组，旧卡不复活也不写缓存 |
| TMR06-GWT-05 | 翻译与复习使用同一配置 | 创建 Provider 图并取消复习 | 两者 cache namespace 一致但实例不同，复习取消不触及翻译实例 |
| TMR07-GWT-01 | 三端任一平台存在本地到期词条 | 点击带 badge 的复习入口并返回 | 全屏页展示两标签；badge 不触发 AI；返回后翻译输入和结果不变 |
| TMR07-GWT-02 | 用户尚未确认隐私告知 | 首次进入复习并确认，随后再次进入 | 说明本地加密、长句排除、可关闭/删除和 AI 最小摘要；确认持久化且第二次不再显示 |
| TMR07-GWT-03 | 历史中存在词条或全部词条 | 确认单删或清空 | 先取消并失效队列，再执行一次仓库删除；列表和 badge 刷新，已删词条不被晚到排序恢复 |
| TMR07-GWT-04 | 加密仓库进入 unavailable | 用户确认安全重建 | 采集保持暂停；只调用安全清空/重建；成功后按已存偏好恢复，失败只显示脱敏错误 |
| TMR07-GWT-05 | 采集已开启且历史存在 | 设置页关闭采集后退出 | 开关值先持久化、运行时停止新增，已有历史保持不变 |
| TMR08-GWT-01 | 当前组有两张卡且第一张带已保存词性词义 | 打开今日复习但尚未收到 AI 响应 | 第一张基础内容立即可见，只发送第一张最小请求；点击下一张后才发送第二张 |
| TMR08-GWT-02 | 文字响应只含生活用语和无来源虚构对白 | 严格解析并写入派生缓存 | UI 显示“生活常用语”和“影视化场景对白”，明确标注 AI 虚构且不显示真实影片名 |
| TMR08-GWT-03 | AI 在虚构对白中附加自报影片名 | 解析响应 | 整体拒绝并降级已有词义，不把自报信息作为来源或许可 |
| TMR08-GWT-04 | 首次文字调用失败且失败标记已加密保存 | 自动重新进入同一卡后再点击手动重试 | 自动进入不再调用；手动重试只新增一次文字调用并可覆盖失败标记 |
| TMR08-GWT-05 | 文字请求进行中删除词条或切换 Provider | 不可取消结果晚到 | 结果为 discarded，不创建缓存、不恢复记录；删除前排序与文字请求均被取消 |
| TMR09-GWT-01 | 当前 Provider/模型未声明图片能力 | 当前卡出现 | 立即显示带可访问标签的主题图标，图片调用与缓存写入均为零，反馈按钮仍可用 |
| TMR09-GWT-02 | 假 Provider 显式支持图片且首次返回合法 PNG/JPEG | 当前卡加载并随后重进 | 首次只发送最小请求并标注“AI 生成插图”；重进从加密缓存读取，不再调用 |
| TMR09-GWT-03 | 图片生成超时、安全拒绝或失败标记已缓存 | 自动重进后点击“重试插图” | 自动重进不调用；只新增一次图片调用，不触发文字重试或切换 Provider/模型 |
| TMR09-GWT-04 | 图片请求进行中删除词条或使 service 失效 | 不可取消结果晚到 | 返回 discarded，不写派生缓存、不恢复记录；删除/清空/重建同时失效图片 service |
| TMR09-GWT-05 | 同一反馈事件在并发调用后重开仓库再次提交 | 原子应用调度 | 忘记次数只增加一次、下次到期不漂移，反馈事件 ID 只存在于加密 payload |
| TMR09-GWT-06 | 当前组只有一张到期卡 | 提交“忘记了”并推进固定时钟 10 分钟 | 展示本组完成/开始下一组；边界前队列为空，边界时相同学习身份再次到期 |
| TMR09-GWT-07 | 合格纠正短语完成翻译 | 依次执行采集、24 小时到期、AI 排序、文字/假图片卡片和反馈 | 完整闭环可观察；文字与图片各调用一次，反馈后 10 分钟再次进入排序 |

## 5. Mock、数据与断言

| 项 | 规则 | 风险 |
|---|---|---|
| 测试数据 | [KNOWN] 只使用虚构的英文词/短语、中日韩短语、复合 emoji、缩写和数字；不含真实用户数据 | NONE |
| AI 边界 | [KNOWN] 不发起付费/真实远端 Provider 请求；以本机 loopback HTTP/SSE 验证 OpenAI-compatible 与 Claude 请求形状、严格 JSON 和取消，以 fake Provider 验证超时 | 真实模型格式遵循仍由严格降级保护；P2 |
| grapheme | [KNOWN] 通过 Flutter 公共 `widgets.dart` 重导出的 `characters` 扩展计数，80 个家庭 emoji 通过、81 个排除 | P1 |
| 多句保护 | [KNOWN] 终止标点簇计数前屏蔽常见缩写、首字母缩写和数字间小数点；作为 AI 分类后的第二道保守保护 | 不是通用 NLP 分句器，后续语言 fixture 仍需扩充；P2 |
| UI 断言 | [KNOWN] 同时断言协议标签不可见、主译文可见以及复制内容不含协议 | P1 |
| Unicode 依赖 | [KNOWN] 使用 `unorm_dart 0.3.2` 的 Unicode 17.0 `nfkc`；[pub.dev 包页](https://pub.dev/packages/unorm_dart)、[changelog](https://pub.dev/packages/unorm_dart/changelog)、MIT 许可证和 [GitHub 仓库](https://github.com/yshrsmz/unorm-dart)测试/CI 已复核；未手写 normalization 表 | P1 停止条件已关闭 |
| identity 序列化 | [KNOWN] schema `1` 只含规范词条、实际源语言和目标语言；Provider/模型不在接口或序列化中 | P1 |
| 领域数据 | [KNOWN] 仅使用虚构词条与固定 UTC 时间；alias/secondary meanings 复制为不可变集合 | NONE |
| 加密算法 | [KNOWN] `cryptography 2.9.0` 的 `AesGcm.with256bits()`；每 envelope 新 nonce，AAD 含数据类型/schema/opaque storage key，keyId 为密钥摘要前缀 | P1 |
| 平台密钥 | [KNOWN] `flutter_secure_storage 10.3.1`；Android 独立 namespace、AES-GCM 且 `resetOnError=false`；iOS 非同步 device-only Keychain；macOS 无开发证书环境使用系统 login Keychain、`usesDataProtectionKeychain=false` | P1；Release 签名能力仍需发布前复核 |
| 真实落盘 | [KNOWN] 测试创建独立 `review_history`/`review_content` Hive 文件，扫描 raw map 与原始文件 UTF-8 字节；未发现虚构 term/alias/translation/content id/bytes | P1 |
| 故障注入 | [KNOWN] 内存 store/key adapter 只模拟读写失败、缺钥和原子写前失败；不读取生产数据、生产日志或用户 Keychain 密钥值 | NONE |
| 采集边界 | [KNOWN] 以 fake `ReviewCapture`、内存 repository、固定 UTC 时钟、延迟缓存和可控流验证调用次数、generation 与错误隔离；不发起真实 AI、网络或生产存储调用 | NONE |
| 调度边界 | [KNOWN] 以虚构词条、注入 UTC 时钟和表驱动反馈事件验证间隔、计数、幂等、重译与回拨；不访问仓库、UI、AI、网络或系统时钟 | NONE |
| 排序边界 | [KNOWN] 只使用虚构词条、内存仓库、注入 UTC 时钟、fake ranker 和本机 loopback Provider；请求断言不含别名、译文、完整历史或绝对复习时间 | NONE |
| TMR-07 UI/偏好边界 | [KNOWN] 使用 fake repository/ranker、platform override、临时 Hive 和固定虚构词条；不调用真实 AI、网络、安全存储或用户数据；断言确认弹窗、调用次数、脱敏错误、路由重入和 320px 布局 | 真机导航与安全存储重启 smoke 仍属发布前验证；P2 |
| TMR-08 文字边界 | [KNOWN] 使用虚构短语、fake generator、loopback OpenAI-compatible/Claude、固定时钟和内存/真实加密 repository；不调用真实远端 AI、外部电影源或用户数据；断言最小请求、一次调用、失败标记、手动重试、许可身份、无预取和明文扫描 | 真实模型格式遵循仍由严格降级保护；P2 |
| TMR-09 图片/闭环边界 | [KNOWN] 仅使用虚构短语、假图片/文字/排序 Provider、内存/加密 repository 和固定 UTC 时钟；验证默认 unsupported、PNG/JPEG 签名、8 MiB 单图上限、128 MiB 派生 LRU、最小请求、超时/安全拒绝、成功/失败缓存、手动图片重试、晚到丢弃、反馈重启幂等和端到端再次到期 | [KNOWN] 当前 live Provider 的图片 endpoint/格式/capability 无本地核验证据，按停止条件未实现 live adapter；P1 边界清晰 |

## 6. RED-GREEN-REFACTOR 记录

| 步骤 | 行为 | 文件/命令 | 结果 |
|---|---|---|---|
| RED-1 | 先要求解析 typed 源语言、版本与分类 | `flutter test test/features/translate/models/translation_presentation_test.dart` | [KNOWN] 失败：枚举、字段和 getter 尚不存在 |
| GREEN-1 | 增加受限枚举、版本 `1`、元数据解析/剥离，并把 output contract 升至 `5` | `translation_presentation.dart`；同一测试 | [KNOWN] 7 项通过 |
| RED-2 | Prompt 必须在同次响应输出三条分类协议 | `flutter test test/core/ai/prompts_test.dart` | [KNOWN] 失败：Prompt 不含 `SOURCE_LANGUAGE:` |
| GREEN-2 | 固定第 2 至 4 行协议和五类允许值，译文从第 5 行开始 | `prompts.dart`；同一测试 | [KNOWN] 3 项通过 |
| RED-3 | 通过公开接口判定当前契约 `word` | `flutter test test/features/review/domain/review_eligibility_test.dart` | [KNOWN] 失败：资格模块不存在 |
| GREEN-3 | 建立 typed 结果、排除原因及版本/语言/语义基本闸门 | `review_eligibility.dart`；同一测试 | [KNOWN] 主路径通过 |
| RED-4 | 原文/纠正后源文必须执行 80/81 grapheme、换行和多句保护 | 同一资格测试 | [KNOWN] 失败：第 81 个复合 emoji 仍返回 eligible |
| GREEN-4 | 使用 grapheme 扩展计数，并实现双源文与句界保护 | `review_eligibility.dart`；同一测试 | [KNOWN] 边界与多语言表通过 |
| RED-5 | 非法/重复元数据与半截流式前缀不得被接受或展示 | presentation 聚焦测试 | [KNOWN] 失败：非法源语言仍保留 `word`；`SOURCE_` 进入主译文 |
| GREEN-5 | 将三字段作为严格协议包校验；malformed/partial 只降级、不猜测 | `translation_presentation.dart`；同一测试 | [KNOWN] 9 项通过 |
| REFACTOR | 移除无用的 `Characters` shown name；保留 Flutter 公共重导出，未新增依赖 | eligibility 文件、格式化和静态分析 | [KNOWN] 资格测试 3 项通过；本轮生产文件单文件分析均为零问题 |
| FINAL | 聚合 Prompt、解析、资格、UI、控制器和缓存身份回归 | `flutter test --no-pub ...` | [KNOWN] 39 项全部通过 |
| TMR02-DEPENDENCY | 先审查可维护 NFKC 实现；镜像解析造成 104 项锁版本漂移后全部收敛回原集合 | `unorm_dart 0.3.2`；`pubspec.yaml/lock` | [KNOWN] 最终依赖 diff 仅 3 行声明与 8 行精确锁项；未留下生成文件漂移 |
| RED-6 | 表驱动要求 NFKC、空白、大小写、语言方向、稳定相等/哈希和版本化序列化 | `flutter test --no-pub test/features/review/domain/review_identity_test.dart` | [KNOWN] 失败：`review_identity.dart` 不存在，9 个引用无法编译 |
| GREEN-6 | 增加纯 `ReviewIdentity`，使用审查后的 NFKC、空白合并、大小写规范化、语言方向和 schema `1` | `review_identity.dart`；同一测试 | [KNOWN] 9 项通过 |
| RED-7 | 要求首次 typed entry、纠错别名、跨 Provider 重译、进度保留、旧完成保护和不可变快照 | `flutter test --no-pub test/features/review/models/review_entry_test.dart` | [KNOWN] 失败：`review_entry.dart`、`ReviewEntry`、`ReviewEntryContent` 不存在 |
| GREEN-7 | 增加不可变 entry/content；重译只更新别名、次数及真正最新的时间/内容，保留全部复习进度 | `review_entry.dart`；同一测试 | [KNOWN] 4 项通过 |
| RED-8 | 内容源词必须属于 entry 的学习身份 | 同一 entry 测试 | [KNOWN] 失败：`banana` 内容可被挂到 `the` identity，未抛出错误 |
| GREEN-8 | 用相同 NFKC/空白/大小写/语言方向规则重建内容身份并校验相等 | `review_entry.dart`；同一测试 | [KNOWN] 5 项通过 |
| REFACTOR-2 | 复制集合、拒绝非法计数/空内容，移除可能把用户词条带入日志的 `toString` 和异常 value | 两个生产文件、格式化与聚焦分析 | [KNOWN] 行为测试保持通过；两个新增生产文件 `No issues found` |
| FINAL-2 | 聚合 TMR-01 与 TMR-02 的 Prompt、缓存、解析、资格、身份、entry、UI 和 controller 回归 | `flutter test --no-pub ...` 八个测试文件 | [KNOWN] 53 项全部通过 |
| TMR03-DEPENDENCY | 核对三端最低版本与官方实现；镜像解析引起 113 项漂移后收敛为原锁 + `unorm_dart` + 安全存储必需锁项 | `flutter_secure_storage 10.3.1`；`pubspec.yaml/lock` | [KNOWN] Android 实际 minSdk 24、iOS 13、macOS 10.15 均满足；未保留无关依赖版本漂移 |
| RED-9 / GREEN-9 | 先要求 entry 全字段密文往返、AAD 移动保护、篡改和错误密钥拒绝；再实现版本化 AES-256-GCM codec | `review_store_codec_test.dart`；`review_store_codec.dart` | [KNOWN] RED 因模块不存在失败；GREEN 4 项通过 |
| RED-10 / GREEN-10 | 先要求 256-bit 独立密钥、并发单创建、损坏/读取失败不替换和安全平台参数；再实现平台 adapter | `review_key_store_test.dart`；`review_key_store.dart` | [KNOWN] RED 因模块不存在失败；GREEN 6 项通过；macOS Data Protection 配置另经历 1 次签名失败 RED 后改为 login Keychain GREEN |
| RED-11 / GREEN-11 | 先要求并发 upsert、缺钥、原子写失败和篡改状态；再实现串行 encrypted repository | `encrypted_review_repository_test.dart`；repository 文件 | [KNOWN] 基础 4 项通过；新增“其他密文缺钥时 miss 不得伪空”先失败后通过 |
| RED-12 / GREEN-12 | 先要求级联删除、重建 generation、迟到写拒绝、LRU 和密文优先清理顺序 | 同一 repository 测试 | [KNOWN] 新增 4 项通过；旧篡改测试只因新增 meta 记录定位过宽失败，收紧到 `entry:` 后通过 |
| RED-13 / GREEN-13 | 先要求真实 Hive 文件无明文、可重开及 Provider key reset 隔离；再实现 Hive store adapter | `hive_review_ciphertext_store_test.dart`；`hive_review_ciphertext_store.dart` | [KNOWN] RED 因 adapter 不存在失败；GREEN 2 项通过 |
| RED-14 / GREEN-14 | 先要求默认不可用 Provider 和启动时安全预置/回读独立 key；已有密文缺钥不得补建 | provider/bootstrap 测试与实现 | [KNOWN] RED 均因模块不存在失败；GREEN 共 3 项通过 |
| FINAL-3 | 完整复习模块、全仓回归、三端编译和 macOS 规定脚本启动 | `flutter test test/features/review`、`flutter test`、三端 build、`scripts/run_macos_debug.sh` | [KNOWN] 复习模块 41 项、全仓 169 项通过；Android/iOS/macOS Debug 编译通过；App PID 12735 单进程存活，Keychain 仅元数据查询确认独立 generic-password 条目存在 |
| RED-15 / GREEN-15 | 先要求合格纠正短语通过公开采集服务写 typed repository；再实现资格、identity、内容和 UTC 写入 | `review_capture_service_test.dart`；`review_capture_service.dart` | [KNOWN] RED 因模块不存在失败；GREEN 主路径通过 |
| RED-16 / GREEN-16 | 先要求关闭采集不访问仓库 | 同一 service 测试 | [KNOWN] RED 实际返回 `captured`；GREEN 返回 `disabled` 且调用为零 |
| RED-17 / GREEN-17 | 先要求仓库预检不可用返回脱敏状态 | 同一 service 测试 | [KNOWN] RED 实际返回 `captured`；GREEN 返回 `unavailable` 且不写入 |
| RED-18 / GREEN-18 | 先要求写失败被采集边界吸收 | 同一 service 测试 | [KNOWN] RED 原始 `StateError` 冒泡；GREEN 返回不含异常内容的 `failed` |
| RED-19 / GREEN-19 | 先要求不可复习 sentence 在仓库预检前排除 | 同一 service 测试 | [KNOWN] RED 误报 `unavailable`；GREEN 返回 typed exclusion 且仓库调用为零 |
| RED-20 / GREEN-20 | 先要求缓存命中注入采集接口并传递原文/目标语言/typed presentation | `translate_controller_test.dart`；`translate_controller.dart` | [KNOWN] RED 控制器无 `reviewCapture` 参数；GREEN 缓存命中采集一次 |
| RED-21 / GREEN-21 | 先要求联网重复完成只采集一次 | 同一 controller 测试 | [KNOWN] RED 采集调用为 0；GREEN 将联网完成接入既有 `didComplete` 防线后调用为 1 |
| RED-22 / GREEN-22 | 先要求 Riverpod 图注入采集并暴露结果 | controller/provider 测试；`review_providers.dart` | [KNOWN] RED 缺少 capture/result Provider；GREEN 默认开启、动态读取开关并保存 typed 结果 |
| REFACTOR-4 | 缓存与联网完成共用一个发布函数，顺序固定为成功状态、异步采集、可选扩展内容 | `translate_controller.dart`；两份聚焦测试 | [KNOWN] 24 项行为测试保持通过 |
| FINAL-4 | 聚合 TMR-01 至 TMR-04、格式、聚焦/全仓分析与测试 | `flutter test --no-pub ...`、`dart format --set-exit-if-changed ...`、`flutter analyze --no-pub` | [KNOWN] 聚焦 88 项、全仓 182 项通过；5 个改动文件静态分析零问题；全仓仅既存 `state_view.dart:74` info |
| RED-23 / GREEN-23 | 先要求新词 24 小时首次到期且边界包含等于；再实现注入时钟的纯调度器 | `review_scheduler_test.dart`；`review_scheduler.dart` | [KNOWN] RED 因调度模块/类型不存在失败；GREEN 1 项通过 |
| RED-24 / GREEN-24 | 先要求忘记清零连续次数、增加忘记次数并于 10 分钟后到期 | 同一测试；`review_feedback.dart`、调度状态与反馈应用 | [KNOWN] RED 因反馈模块、状态和方法不存在失败；GREEN 累计 2 项通过 |
| RED-25 / GREEN-25 | 先要求模糊保留计数并于 1 天后到期 | 同一测试 | [KNOWN] RED 为未支持操作；GREEN 累计 3 项通过 |
| RED-26 / GREEN-26 | 先用表驱动要求记得按 3/7/14/30/60/90 天递进并封顶 | 同一测试 | [KNOWN] RED 为未支持操作；GREEN 累计 4 项通过 |
| RED-27 / GREEN-27 | 先要求重复事件返回同一状态且计数只更新一次 | 同一测试 | [KNOWN] RED 实际创建新状态；GREEN 以不可变事件 ID 集合幂等短路，累计 5 项通过 |
| RED-28 / GREEN-28 | 先要求重译立即到期且进度/事件账本不重置 | 同一测试 | [KNOWN] RED 因 `markRetranslated` 不存在失败；GREEN 累计 6 项通过 |
| RED-29 / GREEN-29 | 先要求系统时钟回拨不把已提交复习时间从 14:00Z 回退到 13:00Z | 同一测试 | [KNOWN] RED 实际回退到 13:00Z；GREEN 以当前、最近翻译和最近复习时间最大值为提交下界，累计 7 项通过 |
| RED-30 / GREEN-30 | 先要求恢复的事件 ID 去空白、拒绝空 ID 且账本不可变 | 同一测试 | [KNOWN] RED 保留了带空白 ID；GREEN 规范化并冻结集合，补充 UTC/非法事件覆盖后 10 项通过 |
| REFACTOR-5 | 合并 `ReviewEntry` 调度字段重建，集中保持非调度字段和 generation 不变 | `review_scheduler.dart`；聚焦格式、测试和分析 | [KNOWN] 10 项保持通过；3 个新增 Dart 文件格式检查无差异、静态分析零问题 |
| FINAL-5 | 聚合 TMR-01 至 TMR-05 复习模块与全仓回归 | `flutter test --no-pub test/features/review`、`flutter test --no-pub`、`flutter analyze --no-pub` | [KNOWN] 复习模块 56 项、全仓 192 项通过；全仓仅既存 `state_view.dart:74` info |
| RED-31 / GREEN-31 | 先要求 55 个到期条目只发送 50 个并按 AI 顺序形成 10 卡快照 | `review_queue_controller_test.dart`；新增 AI models/ranker/controller | [KNOWN] RED 因三个模块/公开类型不存在失败；GREEN 首个 tracer bullet 通过 |
| RED-32 / GREEN-32 | 先要求 AI 失败按逾期、忘记次数、最近复习时间和 identity 稳定降级 | 同一队列测试 | [KNOWN] RED 原始 `StateError` 冒泡；GREEN 累计 2 项通过 |
| RED-33 / GREEN-33 | 先要求可序列化的最小候选摘要且不含别名/译文/完整历史 | 同一队列测试；`review_ai_models.dart` | [KNOWN] RED 缺少 `toJson`；GREEN 累计 3 项通过 |
| RED-34 / GREEN-34 | 先要求未知、重复或缺失候选 ID 整组降级 | 同一队列测试 | [KNOWN] RED 未知 ID 触发 null assertion；GREEN 子集/唯一性/数量校验后累计 4 项通过 |
| RED-35 / GREEN-35 | 先要求版本化、限长、无附加状态字段的严格 AI JSON 响应 | `review_ai_models_test.dart`；models 文件 | [KNOWN] RED 缺少 `fromJson`；GREEN models/queue 共 5 项通过 |
| RED-36 / GREEN-36 | 先要求排序超时取消专用 Provider 并返回 typed 脱敏失败 | `review_ranker_test.dart`；`review_ranker.dart`、`ai_provider.dart` | [KNOWN] RED 缺少 AI ranker/异常类型；GREEN timeout/cancel 通过 |
| RED-37 / GREEN-37 | 先要求同候选 30 分钟内命中缓存，边界时刻过期 | 队列测试 | [KNOWN] RED 第二次仍返回 AI 并再次调用；GREEN 成功快照缓存后累计 5 项通过 |
| RED-38 / GREEN-38 | 先要求失败降级也缓存，避免反复进入重复计费 | 队列测试 | [KNOWN] RED 第二次仍重新调用并返回 local fallback；GREEN 累计 6 项通过 |
| RED-39 / GREEN-39 | 先要求反馈/历史事件清缓存并取消复习 AI | 队列测试 | [KNOWN] RED 缺少 `invalidate`；GREEN 累计 7 项通过 |
| RED-40 / GREEN-40 | 先要求排序期间删除词条后晚到响应不得复活旧卡 | 队列测试 | [KNOWN] RED 仍返回包含已删词条的 AI 快照；GREEN AI 后重读仓库/摘要后累计 8 项通过 |
| RED-41 / GREEN-41 | 先要求 OpenAI-compatible 用一次严格 JSON 请求排序 | `openai_compatible_provider_test.dart`；Prompt/provider | [KNOWN] RED 缺少 `Prompts.reviewRanking`；GREEN loopback SSE 契约通过 |
| RED-42 / GREEN-42 | 先要求复习与翻译使用相同配置但不同 Provider 实例 | `review_providers_test.dart`；`review_providers.dart` | [KNOWN] RED 缺少专用 Provider/ranker family；GREEN 与 timeout 测试共 3 项通过 |
| RED-43 / GREEN-43 | 先要求 Claude messages endpoint 支持相同排序契约 | `claude_provider_test.dart`；`claude_provider.dart` | [KNOWN] RED 返回 unsupported capability；GREEN loopback 排序通过 |
| RED-44 / GREEN-44 | 先要求取消进行中的 Claude 排序 | 同一 Claude 测试 | [KNOWN] RED 1 秒后超时仍未结束；GREEN 以独立 `CancelToken` 返回 typed cancelled，共 2 项通过 |
| RED-45 / GREEN-45 | 先要求未知 ID 等非法响应的本地降级也进入费用缓存 | 队列测试 | [KNOWN] RED 第二次仍重新调用；GREEN 累计 9 项通过 |
| RED-46 / GREEN-46 | 先要求系统时钟回拨时 AI 相对复习年龄不为负数 | 队列测试 | [KNOWN] RED 候选构造抛出非负计数错误；GREEN 夹紧为 0，补 generation/空队列后队列 12 项通过 |
| REFACTOR-6 | 统一不可变快照、opaque SHA-256 候选/缓存键、成功/失败缓存项、仓库二次校验和 typed Provider 失败边界 | 16 个生产/测试文件；格式、聚焦分析与回归 | [KNOWN] `dart format` 无剩余修改；16 文件 `No issues found`；26 项相关契约测试通过 |
| FINAL-6 | 聚合 TMR-01 至 TMR-06 Review 模块与全仓回归 | `flutter test --no-pub test/features/review`、`flutter test --no-pub`、`flutter analyze --no-pub` | [KNOWN] Review 模块 70 项、全仓 211 项通过；全仓仅既存 `state_view.dart:74` info |
| RED-47 / GREEN-47 | 先要求翻译页存在复习入口并以全屏页展示今日/历史标签 | `review_entry_point_test.dart`；`app.dart`、`review_page.dart` | [KNOWN] RED 找不到 `review-button`；GREEN 三端共用全屏路由与返回行为通过 |
| RED-48 / GREEN-48 | 先要求入口显示本地到期 badge 且不得调用 AI | 同一 widget 测试；history controller/provider | [KNOWN] RED 找不到 `review-badge`；GREEN 本地计算到期数并支持 `99+` |
| RED-49 / GREEN-49 | 先要求退出再进入仍展示相同组且 AI 调用保持一次 | 同一 widget 测试；app-lifetime queue provider | [KNOWN] RED 今日页不显示测试词条；GREEN 将队列 controller 提升为非 auto-dispose 生命周期，重入命中缓存 |
| RED-50 / GREEN-50 | 先要求首次告知且确认后不再出现 | widget/Hive 偏好测试；preferences store 与 dialog | [KNOWN] RED 未出现隐私告知；GREEN 严格 schema 偏好持久化并验证损坏数据不静默启用 |
| RED-51 / GREEN-51 | 先要求设置页关闭采集先持久化且不清空历史 | `settings_page_test.dart`；settings/providers | [KNOWN] RED 缺少采集开关；GREEN 保存成功后才切换，保存失败保持关闭并脱敏提示 |
| RED-52 / GREEN-52 | 先要求确认单删后列表/badge 同步且排序晚到不复活 | widget 测试；history controller/view | [KNOWN] RED 缺少删除按钮；GREEN 先失效/取消队列，再调用仓库单删并刷新 |
| RED-53 / GREEN-53 | 先要求清空取消为零副作用、确认只调用一次安全清空 | 同一 widget 测试 | [KNOWN] RED 缺少清空入口；GREEN 确认路径只调用一次 `clearAndReset` |
| RED-54 / GREEN-54 | 先要求 unavailable 状态只允许确认安全重建，失败脱敏 | 同一 widget 测试 | [KNOWN] RED 缺少重建入口；GREEN 重建成功后重载仓库/偏好，失败不暴露注入异常 |
| RED-55 / GREEN-55 | 先要求 320px 宽度加入复习入口后无溢出且保留 48pt 触控区 | `widget_test.dart`；`app.dart` | [KNOWN] RED 顶部工具栏右侧溢出 33px；GREEN 小于 360px 改为双行布局 |
| RED-56 / GREEN-56 | 首次全仓回归要求既有独立 `SettingsSheet` host 仍可渲染/点击 | `settings_sheet_test.dart`；`settings_page.dart` | [KNOWN] RED 10 项因新增 `Switch` 缺少 Material 祖先而失败；GREEN 以透明 Material 保持既有 host contract，10 项恢复通过 |
| REFACTOR-7 | 将历史空态/列表/不可用与管理操作拆入 `history_view.dart`，保持 page 只协调标签和告知 | 11 个 TMR-07 生产/测试文件；格式、分析与回归 | [KNOWN] 格式检查 0 修改；聚焦分析 `No issues found`；行为测试保持通过 |
| FINAL-7 | 聚合 TMR-01 至 TMR-07 Review 模块、相关 UI 与全仓回归 | review 模块、widget/settings、全仓 test/analyze | [KNOWN] Review 模块 84 项、相关 UI 15 项、既有 SettingsSheet 10 项、全仓 227 项通过；全仓仅既存 `state_view.dart:74` info |
| RED-57 / GREEN-57 | 先要求最小文字请求和严格、限长、版本化响应；AI 附加影片名必须拒绝 | `review_ai_models_test.dart`；`review_ai_models.dart` | [KNOWN] RED 请求/响应类型不存在；GREEN 请求仅四个业务字段，严格响应及影片名拒绝共 2 项通过 |
| RED-58 / GREEN-58 | 先要求 AI 内容只能成为虚构对白，批准真实台词必须有作品/来源/许可 | `review_content_test.dart`；`review_content.dart` | [KNOWN] RED feature 内容模型不存在；GREEN 虚构/批准身份及严格缓存序列化 2 项通过 |
| RED-59 / GREEN-59 | 先要求首次生成后从派生缓存读取且请求不含别名/完整历史 | `review_content_service_test.dart`；`review_content_service.dart` | [KNOWN] RED 服务/生成器接口不存在；GREEN 一次生成、opaque 内容 ID 和缓存命中通过 |
| RED-60 / GREEN-60 | 先要求失败后自动重入不再次调用，只有手动重试允许第二次 | 同一 service 测试 | [KNOWN] RED 自动重入实际返回 AI success 并调用两次；GREEN 将脱敏失败标记写入加密派生缓存，手动重试覆盖 |
| RED-61 / GREEN-61 | 先要求 Prompt 只生成生活常用语和无真实来源的影视化对白 | `prompts_test.dart`；`prompts.dart` | [KNOWN] RED 缺少 `reviewTextContent`；GREEN 固定最小输入、严格 JSON 和不得自报影片/来源/许可 |
| RED-62 / GREEN-62 | 先要求 OpenAI-compatible 以一次严格 JSON 请求生成文字 | `openai_compatible_provider_test.dart`；AIProvider/OpenAI adapter | [KNOWN] RED Provider 缺少方法；GREEN loopback 请求与严格解析通过 |
| RED-63 / GREEN-63 | 先要求 Claude messages endpoint 支持相同文字契约 | `claude_provider_test.dart`；Claude adapter | [KNOWN] RED 返回 unsupported capability；GREEN 一次 loopback messages 请求通过 |
| RED-64 / GREEN-64 | 先要求文字调用 20 秒边界可超时并只取消专用 Provider | service 测试；AI generator adapter | [KNOWN] RED 缺少 generator/typed 失败；GREEN timeout 映射和独立取消通过 |
| RED-65 / GREEN-65 | 先要求文字 Provider 与翻译、排序实例相互隔离 | `review_providers_test.dart`；provider 图 | [KNOWN] RED 缺少文字 Provider/service Provider；GREEN 三实例独立且 cache namespace 一致 |
| RED-66 / GREEN-66 | 先要求卡片同步显示保存词义且只加载当前卡，失败显式手动重试 | `review_card_test.dart`；`review_card.dart` | [KNOWN] RED 卡片模块不存在；GREEN 基础内容、生活用语、虚构标识、下一张按需调用和降级重试 2 项通过 |
| RED-67 / GREEN-67 | 先要求今日复习真实使用渐进卡片而非旧列表 tile | `review_entry_point_test.dart`；`review_page.dart` | [KNOWN] RED 找不到词性 `idiom`；GREEN 页面接入 `ReviewDeck` 并显示生成内容 |
| RED-68 / GREEN-68 | 先要求单删前同时取消排序和文字请求 | 同一入口测试；history controller/provider | [KNOWN] RED 文字 cancel count 为 0；GREEN 删除/清空/重建均先失效文字 service 再改仓库 |
| REFACTOR-8 | 将 AI 严格契约、feature 内容身份、生成/缓存服务和卡片 UI 分层；统一内容身份 hash、成功/失败缓存记录和 typed 脱敏状态 | 20 个生产/测试文件；格式、聚焦分析与回归 | [KNOWN] 20 文件格式检查 0 修改；聚焦分析 `No issues found`；删除/Provider 上下文晚到与真实加密 store 明文扫描保持通过 |
| FINAL-8 | 聚合 TMR-01 至 TMR-08 Review 模块与全仓回归 | review 模块、TMR-08 契约范围、全仓 test/analyze | [KNOWN] Review 模块 96 项、全仓 243 项通过；全仓仅既存 `state_view.dart:74` info |
| RED-69 / GREEN-69 | 先要求图片 capability 默认 unsupported，方法返回 typed unsupported，图片响应受媒体类型/大小约束 | `ai_provider_review_image_test.dart`；AIProvider/AI models | [KNOWN] RED 图片类型与方法不存在；GREEN 默认零能力且 PNG/JPEG、8 MiB 边界通过 |
| RED-70 / GREEN-70 | 先要求图片服务支持 unsupported、成功一次/缓存命中、失败标记/手动重试、Provider 隔离、删除与 invalidate 晚到 | `review_image_service_test.dart`；`review_image_service.dart` | [KNOWN] RED 服务文件不存在；GREEN 6 项主链通过，复用加密派生 repository 与 generation 防线 |
| RED-71 / GREEN-71 | 先要求反馈事件账本进入加密 entry，并发和重开仓库后重复提交幂等 | codec/encrypted repository 测试；entry/repository/scheduler | [KNOWN] RED entry 无账本且仓库无 applyFeedback；GREEN 串行原子调度、可选字段兼容读取和密文无事件明文通过 |
| RED-72 / GREEN-72 | 先要求主题图标可访问、假图片带 AI 标识、三档反馈按钮可提交 | `review_card_test.dart`；`review_card.dart` | [KNOWN] RED 卡片无 image service/反馈接口；GREEN 主题降级、成功图片和三个反馈动作共 4 项通过 |
| RED-73 / GREEN-73 | 先要求图片拥有独立 Provider 实例且实际配置默认 unsupported | `review_providers_test.dart`；provider 图 | [KNOWN] RED 缺少图片 Provider/service；GREEN 与翻译/排序/文字实例隔离，不静默选择其他模型 |
| RED-74 / GREEN-74 | 先要求图片超时取消专用 Provider、安全拒绝保持 typed 脱敏状态 | image service/provider 测试 | [KNOWN] RED 缺少 safety error code；GREEN timeout cancel 与 safetyRejected 映射通过 |
| RED-75 / GREEN-75 | 先要求声明 PNG/JPEG 的响应必须具有对应文件签名 | image model 测试 | [KNOWN] RED 任意字节被接受；GREEN PNG 8 字节/JPEG 3 字节签名校验通过 |
| RED-76 / GREEN-76 | 先要求从 entry 构造调度状态时默认恢复已持久化反馈账本 | scheduler 测试 | [KNOWN] RED 重复事件被再次应用；GREEN 默认读取 entry ledger 并返回同一状态 |
| INTEGRATION-9 | 固定时钟走通翻译 → 历史 → 24 小时到期 → AI 排序 → 文字/假图片卡片 → 忘记反馈 → 10 分钟再次到期 | `review_closed_loop_test.dart` | [KNOWN] 端到端 1 项通过；文字/图片各一次、反馈账本和再次排序均有断言 |
| REFACTOR-9 | 复用既有 AES-GCM 派生 repository、128 MiB LRU、generation 与取消边界；图片、文字、排序 Provider 实例隔离；反馈账本成为 entry 不变量 | TMR-09 生产/测试文件；格式、分析与回归 | [KNOWN] 未增加依赖、原生配置或 live 图片 adapter；默认关闭 capability 即回退主题图标，其他复习闭环继续工作 |
| FINAL-9 | 聚合 TMR-01 至 TMR-09 Review 模块与全仓回归 | review 模块、TMR-09 聚焦范围、全仓 test/analyze | [KNOWN] Review 模块 111 项、全仓 260 项通过；35 个 TMR-09 Dart 文件格式门禁 0 修改；全仓 analyze 仅既存 `state_view.dart:74` info |

## 7. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/core/ai/prompts.dart` | 修改 | 同次响应增加源语言、分类版本和五类枚举协议 |
| `lib/features/translate/models/translation_presentation.dart` | 修改 | 增加 typed 协议字段、严格解析、malformed/streaming 降级，并升版缓存输出契约 |
| `lib/features/review/domain/review_eligibility.dart` | 新增 | 纯资格判定、typed 排除原因、grapheme/换行/多句保护 |
| `test/core/ai/prompts_test.dart` | 修改 | Prompt 分类契约测试 |
| `test/features/translate/models/translation_presentation_test.dart` | 修改 | typed/旧版/非法/重复/流式解析测试 |
| `test/features/review/domain/review_eligibility_test.dart` | 新增 | 五类、版本、语言、80/81 grapheme、换行、多句和多语言边界测试 |
| `test/features/translate/ui/result_document_test.dart` | 修改 | 协议元数据不显示、不复制的 widget 测试 |
| `lib/features/review/domain/review_identity.dart` | 新增 | NFKC/空白/大小写规范化、语言方向、相等/哈希和 schema `1` 序列化 |
| `lib/features/review/models/review_entry.dart` | 新增 | typed 内容与不可变复习条目、别名合并、最新完成保护和进度保留 |
| `test/features/review/domain/review_identity_test.dart` | 新增 | Unicode 规范化、语言隔离、序列化和无效输入测试 |
| `test/features/review/models/review_entry_test.dart` | 新增 | 首次记录、跨 Provider 重译、旧完成和不可变性测试 |
| `pubspec.yaml`、`pubspec.lock` | 修改 | 增加并精确锁定经审查的 `unorm_dart 0.3.2`；未升级其他依赖 |
| `docs/features/translation-memory-review/feature_context.md` | 修改 | 当前状态更新为 TMR-01 至 TMR-09 已本地验证，并记录 live 图片停止条件 |
| `docs/features/translation-memory-review/tdd-report.md` | 新增 | 本报告 |
| `lib/features/review/data/review_store_codec.dart` | 新增 | 版本化 AES-256-GCM 信封、AAD、opaque entry/content key、entry/derived/generation 编解码 |
| `lib/features/review/data/review_key_store.dart` | 新增 | 独立 `ReviewKeyStore`、三端 `flutter_secure_storage` 配置、缺钥/损坏脱敏异常和串行创建 |
| `lib/features/review/data/review_repository.dart` | 新增 | 仓库接口、派生内容模型、显式状态和默认不可用实现 |
| `lib/features/review/data/encrypted_review_repository.dart` | 新增 | 原子 upsert、generation、级联删除、安全清空和 128 MiB LRU |
| `lib/features/review/data/hive_review_ciphertext_store.dart` | 新增 | 独立 Hive 密文 store adapter |
| `lib/features/review/data/review_repository_bootstrap.dart` | 新增 | 启动 key 预置/回读与“有密文缺钥不替换”门槛 |
| `lib/features/review/logic/review_providers.dart`、`lib/main.dart` | 新增/修改 | 默认不可用 Provider；成功打开独立盒、iOS 备份排除和安全 key 后才注入真实仓库 |
| `test/features/review/data/`、`test/features/review/logic/` | 新增 | codec/key/repository/Hive/bootstrap/provider 的 RED-GREEN 与安全故障注入 |
| `pubspec.yaml`、`pubspec.lock`、三端插件生成/Pod 文件 | 修改/生成 | 引入并注册 `flutter_secure_storage 10.3.1`；保留既有 `unorm_dart` |
| `lib/features/review/logic/review_capture_service.dart` | 新增 | 资格优先、开关、typed identity/content 写入及 `captured/excluded/disabled/unavailable/failed` 脱敏结果 |
| `lib/features/review/logic/review_providers.dart` | 修改 | 增加运行时采集开关、采集服务和最新 typed 结果 Provider |
| `lib/features/translate/logic/translate_controller.dart` | 修改 | 在 generation 防线后的缓存/即时/防抖最终完成路径异步采集，失败不改变成功译文 |
| `test/features/review/logic/review_capture_service_test.dart` | 新增 | 主路径、关闭、不可用、写失败和非可复习内容边界测试 |
| `test/features/translate/translate_controller_test.dart` | 修改 | 缓存、即时/防抖、过期/重复完成、失败隔离和 Provider 图测试 |
| `lib/features/review/domain/review_feedback.dart` | 新增 | 三档反馈枚举和带非空规范化 ID 的反馈事件 |
| `lib/features/review/domain/review_scheduler.dart` | 新增 | 纯领域 UTC 调度状态机、不可变幂等账本、强制到期和时钟回拨保护 |
| `test/features/review/domain/review_scheduler_test.dart` | 新增 | 首次到期、三档间隔/计数、封顶、幂等、重译、UTC 与回拨表驱动测试 |
| `lib/core/ai/review_ai_models.dart` | 新增 | 最多 50 候选的最小请求与最多 10 项的版本化严格排序响应 |
| `lib/features/review/services/review_ranker.dart` | 新增 | typed 排序服务、20 秒超时、取消和脱敏错误映射 |
| `lib/features/review/logic/review_queue_controller.dart` | 新增 | 稳定候选选择、组快照、成功/失败 30 分钟缓存、事件失效和晚到保护 |
| `lib/core/ai/ai_provider.dart`, `ai.dart`, `prompts.dart` | 修改 | 暴露排序能力/模型并增加最小化、防提示注入的版本化 Prompt |
| `lib/core/ai/openai_compatible_provider.dart`, `claude_provider.dart` | 修改 | 分别以一次请求实现排序；Claude 增加可取消 JSON 请求生命周期 |
| `lib/features/review/logic/review_providers.dart` | 修改 | 按当前配置创建独立于翻译的复习 Provider 与 ranker family |
| `test/features/review/logic/review_queue_controller_test.dart` | 新增 | 50/10、稳定降级、最小请求、缓存/失效、晚到、generation、空态和回拨测试 |
| `test/features/review/services/review_ranker_test.dart` | 新增 | 超时取消和 typed 失败测试 |
| `test/core/ai/review_ai_models_test.dart`, `claude_provider_test.dart` | 新增 | 严格 JSON 模型与 Claude 排序/取消契约测试 |
| `test/core/ai/openai_compatible_provider_test.dart`, `prompts_test.dart`, `test/features/review/logic/review_providers_test.dart` | 修改 | Provider 请求、最小 Prompt 和生命周期隔离测试 |
| `lib/features/review/data/review_preferences_store.dart` | 新增 | 严格 schema 的采集/告知偏好及 memory、unavailable、Hive 实现 |
| `lib/features/review/logic/review_history_controller.dart` | 新增 | 历史/badge/组加载状态；删除、清空、重建的失效、取消和脱敏边界 |
| `lib/features/review/ui/review_page.dart`、`history_view.dart` | 新增 | 全屏今日/历史页、首次隐私告知、空态/不可用态与确认管理操作 |
| `lib/features/review/logic/review_providers.dart` | 修改 | 注入偏好与调度器；保留应用生命周期队列缓存；采集后刷新历史 |
| `lib/app.dart` | 修改 | 底部复习入口、本地 badge、全屏路由及窄屏双行工具栏 |
| `lib/features/settings/ui/settings_page.dart` | 修改 | 复习采集开关、保存失败隔离及既有 SettingsSheet Material contract |
| `lib/main.dart` | 修改 | 独立打开偏好 Hive 盒，启动前读取；初始化失败时安全关闭采集 |
| `test/features/review/data/review_preferences_store_test.dart` | 新增 | Hive 重开持久化与损坏 schema 拒绝测试 |
| `test/features/review/ui/review_entry_point_test.dart` | 新增 | 三端入口、badge/cache、告知、管理、unavailable、状态保持、窄屏与晚到测试 |
| `test/features/settings/settings_page_test.dart` | 修改 | 采集开关持久化、不清空及失败脱敏测试 |
| `lib/features/review/models/review_content.dart` | 新增 | 生活常用语、虚构对白和强制作品/来源/许可的批准台词身份；严格缓存 schema |
| `lib/features/review/services/review_content_service.dart` | 新增 | 最小文字生成、20 秒超时、成功/失败加密缓存、手动重试、内容身份和晚到丢弃 |
| `lib/features/review/ui/review_card.dart` | 新增 | 当前卡即时基础内容、渐进生活用语/影视化对白、无预取导航和降级重试 |
| `lib/core/ai/ai_provider.dart`、`review_ai_models.dart` | 修改 | 新增默认 unsupported 的图片 capability、最小图片请求、PNG/JPEG/8 MiB 响应与安全拒绝错误码；未接 live adapter |
| `lib/features/review/services/review_image_service.dart` | 新增 | 当前卡图片生成、30 秒超时、成功/失败加密缓存、Provider/契约内容身份、手动重试和晚到丢弃 |
| `lib/features/review/models/review_entry.dart`、`domain/review_scheduler.dart` | 修改 | 将反馈事件账本并入不可变 entry，调度状态默认恢复持久化账本 |
| `lib/features/review/data/review_repository.dart`、`encrypted_review_repository.dart`、`review_store_codec.dart` | 修改 | 串行原子应用反馈并加密保存事件账本；旧 payload 缺少可选账本字段时按空集合读取 |
| `lib/features/review/logic/review_providers.dart`、`review_history_controller.dart` | 修改 | 独立图片 Provider/service；删除/清空/重建失效图片；反馈更新当前组、badge 与完成状态 |
| `lib/features/review/ui/review_card.dart`、`review_page.dart` | 修改 | 主题图标/AI 标识、图片单独重试、三档反馈和“开始下一组” |
| `test/core/ai/ai_provider_review_image_test.dart`、`test/features/review/services/review_image_service_test.dart` | 新增 | capability、图片契约、调用预算、缓存、超时、安全拒绝和晚到测试 |
| `test/features/review/integration/review_closed_loop_test.dart` | 新增 | 固定时钟的翻译采集至反馈再到期端到端测试 |
| `lib/core/ai/review_ai_models.dart`、`prompts.dart`、`ai_provider.dart` | 修改 | 新增版本化严格文字请求/响应、最小 Prompt 和 Provider capability |
| `lib/core/ai/openai_compatible_provider.dart`、`claude_provider.dart` | 修改 | 分别以一次可取消 JSON 请求实现复习文字生成 |
| `lib/features/review/logic/review_providers.dart`、`review_history_controller.dart` | 修改 | 独立文字 Provider/service 生命周期；删除、清空、重建前同步失效文字请求 |
| `lib/features/review/ui/review_page.dart` | 修改 | 今日复习由列表预览切换为按当前卡渐进加载的 `ReviewDeck` |
| `test/features/review/models/review_content_test.dart` | 新增 | AI 虚构身份、批准真实台词 metadata 和缓存往返测试 |
| `test/features/review/services/review_content_service_test.dart` | 新增 | 最小请求、成功/失败缓存、手动重试、超时、删除/配置晚到和加密明文扫描 |
| `test/features/review/ui/review_card_test.dart` | 新增 | 即时词性词义、当前卡无预取、虚构标识、失败不自动重试和手动重试 |
| `test/core/ai/review_ai_models_test.dart`、`prompts_test.dart`、Provider tests | 修改 | 严格响应、AI 自报影片名拒绝、最小 Prompt 与双 Provider 请求形状 |
| `test/features/review/logic/review_providers_test.dart`、`ui/review_entry_point_test.dart` | 修改 | Provider 隔离、卡片页面接入及删除同步取消文字请求 |

## 8. 受限命令执行记录

| 命令 | 范围 | 是否执行 | 结果 | 未执行原因 |
|---|---|---|---|---|
| `flutter test --no-pub` 六个相关测试文件 | 聚焦回归 | 是 | [KNOWN] 39 项通过 | - |
| `dart analyze` 三个改动生产文件 | 聚焦静态分析 | 是 | [KNOWN] 全部 `No issues found` | - |
| `dart format --output=none --set-exit-if-changed` 七个改动 Dart 文件 | 格式 | 是 | [KNOWN] 0 个文件需修改 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 本轮警告清除后仍返回 1；仅剩未改动的 `lib/shared/widgets/state_view.dart:74` 一条既存 `use_null_aware_elements` info | 未修改无关文件 |
| `flutter pub get` | TMR-01 依赖解析 | 是 | [KNOWN] 失败：访问 pub.dev 出现 TLS 错误 | [KNOWN] TMR-01 当时未增加依赖，改用既有 package config 和 `--no-pub` |
| `flutter pub get --offline` | TMR-01 离线依赖解析 | 是 | [KNOWN] 失败：本机离线缓存缺少 `cryptography` 的可解析索引 | [KNOWN] TMR-01 当时未增加依赖或修改锁文件 |
| 全量 `flutter test` | 全仓测试 | 否 | - | [KNOWN] TMR-01 已运行相关 39 项；未扩大到无关平台脚本和全仓测试 |
| `flutter test --no-pub` 八个相关测试文件 | TMR-01/TMR-02 聚合回归 | 是 | [KNOWN] 53 项通过 | - |
| `dart analyze` 两个 TMR-02 生产文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `dart format` 四个 TMR-02 Dart 文件 | 格式 | 是 | [KNOWN] 已格式化；最终检查无差异 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 返回 1；仍仅是未改动的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| `flutter pub get --enforce-lockfile`（标准 `pub.dev`） | 锁文件严格复现 | 是 | [KNOWN] 失败：获取 `test` 包时出现 TLS 错误；命令未改变最终依赖或生成文件 diff | 本机访问 `pub.dev` 的 TLS 环境问题；需网络恢复后重跑 |
| `flutter test test/features/review` | TMR-01 至 TMR-03 模块回归 | 是 | [KNOWN] 41 项通过 | - |
| `flutter test`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 最终 169 项通过 | - |
| `flutter analyze lib/main.dart lib/features/review test/features/review` | TMR-03 聚焦分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter analyze` | 全仓静态分析 | 是 | [KNOWN] 仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 info | 未修改无关文件 |
| `flutter build apk --debug --no-pub` | Android API 24 / Keystore 插件链 | 是 | [KNOWN] 成功产出 `app-debug.apk` | - |
| `flutter build ios --debug --no-codesign --no-pub` | iOS Keychain/entitlement/备份保护插件链 | 是 | [KNOWN] CocoaPods 与 Xcode 编译成功，产出 `Runner.app` | 无签名构建不安装到真机 |
| `zsh scripts/run_macos_debug.sh` | macOS 编译、稳定安装、Service 注册、启动存活 | 是 | [KNOWN] Data Protection entitlement 在无开发证书环境先失败；切换系统 login Keychain 后编译通过；取消旧 Release 的 LaunchServices 注册后脚本完整通过，PID 12735 | 旧 `/Users/jamin/Applications/AITrans.app` 仅取消系统注册，文件未删除 |
| `security find-generic-password -s ... -a ...`（无 `-w`） | macOS Keychain 元数据验证 | 是 | [KNOWN] `login.keychain-db` 存在独立 service/account generic-password 条目；未读取或输出密钥值 | - |
| `flutter test --no-pub` TMR-01 至 TMR-04 相关范围 | TMR-04 聚焦回归 | 是 | [KNOWN] 88 项通过 | - |
| `dart format --output=none --set-exit-if-changed` 五个 TMR-04 文件 | 格式 | 是 | [KNOWN] 0 个文件需修改 | - |
| `flutter analyze --no-pub` 五个 TMR-04 文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter test --no-pub`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 182 项通过 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 info | 未修改无关文件 |
| `flutter test --no-pub test/features/review` | TMR-01 至 TMR-05 模块回归 | 是 | [KNOWN] 56 项通过 | - |
| `dart format --output=none --set-exit-if-changed` 三个 TMR-05 文件 | 格式 | 是 | [KNOWN] 0 个文件需修改 | - |
| `flutter analyze --no-pub` 三个 TMR-05 文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter test --no-pub`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 192 项通过 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 返回 1；仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| `dart format` 16 个 TMR-06 生产/测试文件 | 格式 | 是 | [KNOWN] 最终 0 个文件需修改 | - |
| `flutter analyze --no-pub` 16 个 TMR-06 文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter test --no-pub` 七个 TMR-06 相关测试文件 | 聚焦回归 | 是 | [KNOWN] 26 项通过 | - |
| `flutter test --no-pub test/features/review` | TMR-01 至 TMR-06 模块回归 | 是 | [KNOWN] 70 项通过 | - |
| `flutter test --no-pub`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 211 项通过 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 返回 1；仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| `dart format --output=none --set-exit-if-changed` 11 个 TMR-07 文件 | 格式 | 是 | [KNOWN] 0 个文件需修改 | - |
| `flutter analyze --no-pub` 11 个 TMR-07 文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter test --no-pub test/features/review` | TMR-01 至 TMR-07 模块回归 | 是 | [KNOWN] 84 项通过 | - |
| `flutter test --no-pub test/widget_test.dart test/features/settings/settings_page_test.dart` | 入口、窄屏与设置回归 | 是 | [KNOWN] 15 项通过 | - |
| `flutter test --no-pub test/features/settings/ui/settings_sheet_test.dart` | 既有 SettingsSheet host contract 回归 | 是 | [KNOWN] 10 项通过 | - |
| `flutter test --no-pub`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 227 项通过 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| `flutter test --no-pub` 九个 TMR-08 契约/服务/UI 文件 | 聚焦回归 | 是 | [KNOWN] 41 项通过 | - |
| `dart format --output=none --set-exit-if-changed` 20 个 TMR-08 文件 | 格式 | 是 | [KNOWN] 0 个文件需修改 | - |
| `flutter analyze --no-pub` 20 个 TMR-08 文件 | 聚焦静态分析 | 是 | [KNOWN] `No issues found` | - |
| `flutter test --no-pub test/features/review` | TMR-01 至 TMR-08 模块回归 | 是 | [KNOWN] 96 项通过 | - |
| `flutter test --no-pub`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 243 项通过 | - |
| `flutter analyze --no-pub` | 全仓静态分析 | 是 | [KNOWN] 仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| TMR-09 capability/service/repository/widget 聚焦测试 | 图片、反馈与闭环 | 是 | [KNOWN] 默认 unsupported、成功/失败缓存、超时/安全拒绝、删除/invalidate 晚到、反馈重启幂等、主题图标/AI 标识和再次到期均通过 | - |
| `flutter test test/features/review` | TMR-01 至 TMR-09 模块回归 | 是 | [KNOWN] 111 项通过 | - |
| `flutter test`（含 localhost `NO_PROXY`） | 全仓回归 | 是 | [KNOWN] 260 项通过 | - |
| `flutter analyze` | 全仓静态分析 | 是 | [KNOWN] 仅未修改的 `lib/shared/widgets/state_view.dart:74` 既存 `use_null_aware_elements` info | 未修改无关文件 |
| macOS/iOS/Android 构建 | 原生/依赖回归 | 否 | - | [KNOWN] 本切片未增加依赖或修改原生配置；用户本轮未要求编译启动，沿用 TMR-03 三端构建证据 |

## 9. 风险与待确认问题

| 问题 | 等级 | 影响 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| 多句边界是保守本地保护，不是完整自然语言分句器 | P2 | 极少数未覆盖缩写可能产生误排除；不会误写长句 | 后续按真实脱敏缺陷样例扩充 fixture，不放宽现有保护 | 研发、语言内容负责人 |
| 真实 Provider 对新 Prompt 的格式遵循尚未做付费/联网验证 | P2 | 不遵循时条目安全降级为 `unknown`，基础翻译仍显示 | 在已批准的 Provider 测试环境做脱敏 smoke；不得用自由文本补猜分类 | 研发负责人 |
| 全仓 analyze 存在一条既存 info | P3 | 不影响本轮文件；全仓命令仍非零 | 另行整理 `state_view.dart`，不要混入本切片 | 研发负责人 |
| 本机无法通过 `pub.dev` 完成严格锁文件拉取 | P2 | 当前使用已解析的本地镜像 package config 完成编译/测试；标准源全新拉取未在本机闭环 | 网络/TLS 恢复后运行 `flutter pub get --enforce-lockfile`；锁项已使用标准源、精确版本和 resolver 返回的 SHA-256 | 研发负责人 |
| 大小写规范化使用 Dart Unicode `toLowerCase`，不处理不在支持语言集合内的 locale 特例 | P3 | 当前英/法/德/俄/日代表性 fixture 已覆盖；其余既有语言及未来新增语言仍需扩展 case fixture | 新增语言或发现语言差异前先补语言特定 fixture，不手写零散映射 | 研发、语言内容负责人 |
| `ADR-0001` 仍为 `Proposed` | P1 | TMR-03 已按其当前方案受控实现，但不能把本地验证提升为架构接受或发布许可 | 负责人 Review 时确认 AES-GCM/AAD、独立 key、generation、清理顺序和平台配置；接受后再改 ADR 状态 | 架构/安全负责人 |
| macOS 本地 Debug 无开发签名证书 | P2 | Data Protection Keychain entitlement 无法构建；当前使用未同步的系统 login Keychain，真实 generic-password 元数据已验证，Debug 可运行 | 正式签名环境评估是否启用 Data Protection Keychain/Keychain Sharing；变更前补签名构建和跨重启读写测试 | macOS/发布负责人 |
| iOS/Android 本轮完成编译与 adapter 故障注入，未在真机执行 secure storage 读写 | P2 | 插件链和最低版本已闭环，但设备锁定、Keychain/Keystore 被系统清理等真机状态仍无本地证据 | 发布前在批准的 iOS/Android 设备执行创建、重启读取、缺钥和安全清空 smoke | 移动端/测试负责人 |
| 当前 Provider/模型图片 endpoint、返回格式和 capability 未核验 | P1 | [KNOWN] TMR-09 已完成 capability 抽象、假 Provider、加密缓存和主题图标降级，但不能宣称真实 AI 图片已交付 | 只有 endpoint/格式/capability 有官方或已批准本地证据后，才能以新切片为对应 live adapter 补契约测试；不得静默改用其他图片模型 | 研发、内容安全负责人 |
| TMR-07 队列缓存为应用进程内生命周期 | P3 | 退出再进入复习页仍命中 30 分钟成功/失败缓存且已验证；应用重启后会重新排序，不宣称跨进程缓存 | 若产品要求跨重启避免一次排序调用，再设计加密持久缓存及过期/删除迁移；当前不扩大数据面 | 产品、研发负责人 |
| TMR-06 仅以 loopback stub 验证 Provider 请求形状 | P2 | OpenAI-compatible/Claude 适配器和严格降级已闭环，但真实模型是否稳定遵循 JSON 契约尚无付费调用证据 | 在批准的脱敏测试环境做一次 smoke；失败必须保持本地快照且不得自动重试 | 研发负责人 |
| TMR-07 三端导航使用 Flutter platform override 验证 | P2 | 共用路由、状态保持、窄屏与触控边界已闭环；本切片没有重新执行 iOS/Android 真机导航与辅助功能 smoke | 发布前在批准设备验证系统返回手势、字体放大、屏幕阅读器和安全存储跨重启 | 移动端/测试负责人 |
| TMR-08 文字契约只以 fake/loopback Provider 验证 | P2 | OpenAI-compatible/Claude 请求形状、严格影片名拒绝和降级已闭环；真实模型的语言质量、格式稳定性和内容安全尚无付费调用证据 | 在批准的脱敏测试环境逐 Provider 做一次 smoke；非法或不安全响应保持失败标记并由用户手动重试 | 研发、内容安全负责人 |
| 首期没有批准真实电影台词 source adapter | P2 | 类型系统强制作品/来源/许可 metadata，但当前 AI 路径只能显示明确标注的影视化虚构对白 | 只有版权/法务批准结构化源及展示权后才能接入 approved adapter；不得用 AI 自报来源替代 | 产品、版权/法务负责人 |
| 待用户回答的业务问题 | NONE | 无 | 无 | - |

## 10. 上下文更新建议

| 建议位置 | 类型 | 内容摘要 | 原因 |
|---|---|---|---|
| `docs/features/translation-memory-review/feature_context.md` | 已更新 | TMR-01 至 TMR-09 为 `LOCAL_VERIFIED`；明确 live 图片 adapter 未交付 | 记录真实阶段进度与停止条件边界 |
| `docs/DOMAIN_KNOWLEDGE.md` | 暂不更新 | 待负责人确认后加入 TMR-001 长期规则 | 长期上下文仍需负责人确认 |
| `docs/PROJ_CONTEXT.md` | 暂不更新 | 待负责人确认后加入 Feature 索引和阶段状态 | 不把阶段报告自动提升为正式项目事实 |

## 11. Feature 文档状态

| 文档 | 状态 |
|---|---|
| `feature_context.md` | [KNOWN] 已更新 TMR-01 至 TMR-09 进度与 live 图片边界 |
| `scope-plan.md` | [KNOWN] 保留原 Scope 与九切片计划，不改业务范围 |
| `tdd-report.md` | [KNOWN] 已记录 TMR-01 至 TMR-09 的 RED/GREEN/REFACTOR、故障注入、回归、既有三端编译和启动证据 |
| `ADR-0001-review-data-encryption-key-lifecycle.md` | [KNOWN] 保持 `Proposed`；TMR-03 按当前方案受控实现，不代表负责人已接受 ADR |
