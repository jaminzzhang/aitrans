# Scope 需求梳理、准入与 TDD 计划

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `TDD_INPUT_READY` |
| 最高风险等级 | [KNOWN] P1 |
| 一句话依据 | [KNOWN] macOS `NSServices` 主干、范围边界、latest-wins、可配置 5,000 Unicode code points 上限、错误口径和验证切片均已确认或明确排除 |
| 下一步建议 | [KNOWN] 按 S1 至 S5 顺序转 `hicode:tdd`，每个切片独立执行 RED-GREEN-REFACTOR |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| [KNOWN] 项目规则 | `AGENTS.md`, `docs/rules/coding_rules.md` | [KNOWN] 是 | [KNOWN] 平台代码必须隔离；外部输入需校验；新行为需行为测试 | [KNOWN] 无 |
| [KNOWN] 项目上下文 | `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | [KNOWN] 是 | [KNOWN] 产品目标含 macOS、iOS、Android；现有 quick invocation 仅为 macOS 快捷键 | [KNOWN] 新 Feature 尚未进入长期索引 |
| [KNOWN] 产品简述 | `aitrans-prd.md` | [KNOWN] 是 | [KNOWN] 仅定义 macOS 全局快捷键快速唤起，没有跨 App 选中文本需求 | [KNOWN] 平台与验收口径缺失 |
| [KNOWN] 当前 Dart 实现 | `lib/main.dart`, `lib/app.dart`, `lib/core/platform/`, `lib/features/translate/` | [KNOWN] 是 | [KNOWN] 已有窗口、输入状态与立即翻译控制器；没有外部文本平台通道 | [KNOWN] 外部输入同步与生命周期策略缺失 |
| [KNOWN] 当前原生实现 | `macos/Runner/`, `ios/Runner/`, `android/app/src/main/` | [KNOWN] 是 | [KNOWN] 未注册接收其他 App 选中文本的 service、extension 或 Activity filter | [KNOWN] 三平台均无现成入口 |
| [KNOWN] Apple 平台资料 | [Apple Action Extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Action.html), [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices), [NSExtensionContext.open](https://developer.apple.com/documentation/foundation/nsextensioncontext/open%28_%3Acompletionhandler%3A%29) | [KNOWN] 是 | [KNOWN] macOS 可接收选区；iOS 是否收到选区由宿主提供，且 extension point 限制打开主 App | [KNOWN] 目标系统版本与发行渠道待确认 |
| [KNOWN] Android 平台资料 | [Android Intent ACTION_PROCESS_TEXT](https://developer.android.com/reference/android/content/Intent) | [KNOWN] 是 | [KNOWN] API 23 起可接收并处理选中文本 | [KNOWN] 最低 Android 版本与宿主矩阵待确认 |

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | [KNOWN] `NO_BLOCKING_GAPS` |
| 需求分析输入 | [KNOWN] “从浏览器网页、Books 等 App 中选中文字，出现翻译入口，点击弹出主窗口翻译”；feature-id 已确认 |
| 证据缺口 | [KNOWN] 业务、研发和测试负责人未指派；Safari、Chrome、Books 实机结果需在 S5 产出，不阻断 TDD 输入 |

| 检查项 | 结论 | 证据或缺口 |
|---|---|---|
| [KNOWN] 一句话目标 | [KNOWN] 已明确 | [KNOWN] 用户原始输入 |
| [KNOWN] 范围内/外/非目标 | [KNOWN] 已明确平台和入口 | [KNOWN] macOS `NSServices` 在范围内；iOS、Android、自定义浮层和 extension 内第二套 UI 在范围外 |
| [KNOWN] 可测试验收标准 | [KNOWN] 已明确 | [KNOWN] 覆盖 Service 发现、载荷、冷/热启动、窗口、状态、并发、超长、隐私和宿主矩阵 |
| [KNOWN] 业务规则与异常路径 | [KNOWN] 已明确 | [KNOWN] 自动翻译、覆盖、取消、重复触发、5,000 code points 上限和超长提示均已确认 |
| [KNOWN] 术语冲突 | [KNOWN] 无已知冲突 | [KNOWN] 首期“主窗口”固定为 AITrans macOS Runner 的单一主窗口 |
| [KNOWN] 权限、隐私与审计 | [KNOWN] 涉及 | [KNOWN] 外部 App 文本进入本应用并可能发送给远程 Provider |
| [KNOWN] 影响范围 | [KNOWN] 已定位到文件和模块级 | [KNOWN] `Info.plist`、AppDelegate/service provider、Flutter platform boundary、输入 UI 与控制器 |
| [KNOWN] 设计树输入 | [KNOWN] 已闭合 | [KNOWN] macOS Service、生命周期、状态、输入上限和失败分支均可进入 TDD |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | [KNOWN] 用户在其他 App 选择文本后，通过系统提供的 AITrans 入口打开翻译界面并翻译该文本 |
| 范围内 | [INFERRED] 系统入口注册、文本载荷校验、原生到 Flutter 桥接、生命周期恢复、输入同步和翻译触发 |
| 范围外 | [KNOWN] iOS 与 Android 首期实现；[INFERRED] 未授权读取任意 App 选区、剪贴板轮询、OCR、全文抓取、回写宿主文本 |
| 非目标 | [INFERRED] 不保证绕过宿主能力在所有 App 中显示入口；不顺带修改 AI Provider 或翻译质量策略 |
| 验收标准 | [KNOWN] 系统菜单显示“使用 AITrans 翻译”；1 至 5,000 code points 可唤起单一主窗口并立即翻译；5,001 拒绝且不调用 AI；重复请求去重，不同请求 latest-wins；原文不进入日志 |
| feature_context 更新 | [KNOWN] 已创建草稿 |
| ADR 处理 | [INFERRED] 不需要；`NSServices` 被封装在 macOS Runner 内，可替换且未引入高权限模型 |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] macOS 其他 App 中存在非空文本选区，用户主动选择 AITrans Service | [INFERRED] `NSServices` 接收文本并唤起 AITrans 翻译状态机 | [KNOWN] 主窗口显示该文本的翻译状态或明确失败 | [KNOWN] 仅支持提供兼容 Services 菜单的宿主 | [KNOWN] 宿主 × 生命周期矩阵 | P1 |
| MAIN-1 | Service 发现 | [KNOWN] macOS 已安装 AITrans | [INFERRED] 在 Runner 注册只接收纯文本的 `NSServices` 项 | [KNOWN] 系统 Services/上下文菜单显示“使用 AITrans 翻译” | [KNOWN] 不自绘跨 App UI，不新增 extension UI | [KNOWN] 安装、启用、禁用验证 | P1 |
| MAIN-2 | 请求接收 | [KNOWN] 用户点击入口且宿主提供文本 | [INFERRED] 原生层解析一个只读纯文本请求，Dart 边界按可注入配置校验 trim 后 Unicode code points 数 | [KNOWN] typed external translation request | [KNOWN] 接受 1 至 5,000；配置必须为正整数 | [KNOWN] Swift 载荷测试与 Dart 4,999/5,000/5,001 boundary tests | P1 |
| MAIN-3 | 生命周期闭环 | [KNOWN] 应用处于未启动、后台或前台 | [INFERRED] 恢复单一主界面并缓存引擎就绪前请求 | [KNOWN] Flutter 就绪后一次性交付 | [KNOWN] 不并行创建多个翻译窗口/Activity | [KNOWN] cold/warm/resume tests | P1 |
| MAIN-4 | 状态与翻译 | [KNOWN] Dart 收到有效外部请求 | [KNOWN] 覆盖输入 UI、取消旧请求并立即翻译；latest-wins | [KNOWN] 只有最新请求可进入并更新 translate state 的唯一终态 | [KNOWN] 不排队，不保留旧输入 | [KNOWN] widget/controller race tests | P1 |
| BRANCH-1 | 宿主不支持 | [KNOWN] 宿主不暴露系统动作或不提供选区 | [KNOWN] 不抓取、不提升权限绕过 | [KNOWN] 入口不存在 | [KNOWN] 记录支持矩阵，不承诺全覆盖 | [KNOWN] Safari/Chrome/Books 实机验证 | P1 |
| BRANCH-2 | 无效输入 | [KNOWN] trim 后空白、超过配置上限、无纯文本或多项载荷 | [KNOWN] 拒绝且不截断；超长显示“所选文本过长，请缩短至 5,000 字符以内” | [KNOWN] 不触发 AI 请求 | [KNOWN] 默认上限 5,000 Unicode code points；代码配置可替换 | [KNOWN] table tests | P1 |
| BRANCH-3 | 重复请求 | [KNOWN] 系统重复回调、乱序回调或用户连续触发 | [INFERRED] 原生分配进程内单调 sequence；Dart 拒绝小于等于已处理最大 sequence 的请求；更大 sequence latest-wins | [KNOWN] 同一或旧请求不重复交付，旧翻译响应不能覆盖最新状态 | [KNOWN] 应用重启后原生与 Dart 序号状态同时重置 | [KNOWN] concurrency tests | P1 |
| BRANCH-4 | Service 失败 | [KNOWN] Service 禁用、启动失败或 bridge timeout | [INFERRED] 安全结束请求并显示不含原文的通用错误 | [KNOWN] 宿主不挂起，原文不进日志 | [KNOWN] 不暴露路径、堆栈或原生异常 | [KNOWN] failure injection | P1 |

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| [KNOWN] feature-id 是否为 `cross-app-selection-translate`？ | [KNOWN] 已关闭 | [KNOWN] 是 | [KNOWN] 用户已确认 | [KNOWN] 需求目录已固定 | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 首期平台范围是什么？ | [KNOWN] 已关闭 | [KNOWN] 仅 macOS | [KNOWN] 用户已确认 | [KNOWN] iOS、Android 首期实现已排除 | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 系统 Services/上下文动作是否满足“翻译按钮”？ | [KNOWN] 已关闭 | [KNOWN] 使用系统 Services/上下文菜单入口 | [KNOWN] 用户已确认不要求自定义悬浮按钮 | [KNOWN] 排除辅助功能覆盖层和 Action Extension 内第二套 UI | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 外部文本是否立即翻译并覆盖当前输入？ | [KNOWN] 已关闭 | [KNOWN] 立即翻译；覆盖当前输入；取消旧请求；不同请求 latest-wins | [KNOWN] 用户已确认 | [KNOWN] 状态机、幂等和并发测试口径已固定 | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 最大文本长度是多少？ | [KNOWN] 已关闭 | [KNOWN] trim 后最多 5,000 Unicode code points；代码配置可替换 | [KNOWN] 用户确认推荐边界 | [KNOWN] 超长不截断、不调用 AI并显示确认文案 | [KNOWN] 用户于 2026-07-14 确认 |

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| [KNOWN] `lib/core/platform/` | [INFERRED] 增加带进程内单调 sequence 的外部翻译请求端口 | [KNOWN] 当前只有 hotkey service；latest-wins 已确认 | [KNOWN] 已确认设计树方案 | P1 |
| [KNOWN] 外部请求配置 | [INFERRED] 新增可注入的 `ExternalTranslationConfig` 或等价 typed config，默认 `maxCharacters = 5000` | [KNOWN] 用户要求限额作为代码中可配置的值 | [KNOWN] 已确认 | P1 |
| [KNOWN] `CommandBar` | [KNOWN] 当前 controller 只由组件内部 `_controller` 更新；外部 provider 变化不会自动填入输入框 | [KNOWN] 源码 | [KNOWN] 已定位 | P1 |
| [KNOWN] `TranslateController` | [KNOWN] 已有 latest generation 保护和 `translateNow`，可作为外部请求落点 | [KNOWN] 源码 | [KNOWN] 已定位 | P1 |
| [KNOWN] macOS Runner | [INFERRED] 注册 `NSServices`、实现 service provider 生命周期和 Flutter 通道 | [KNOWN] 当前 macOS 原生目录无接收实现 | [KNOWN] 平台与入口已确认 | P1 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] 后续移动平台不能复用 macOS 验收结论 | P2 | [KNOWN] iOS extension 与 Android `ACTION_PROCESS_TEXT` 生命周期不同 | [KNOWN] iOS、Android 后续分别建立 Scope | [KNOWN] 产品/研发负责人 |
| [KNOWN] 自定义跨 App 浮层权限高 | P2 | [KNOWN] 用户已排除该方案 | [KNOWN] 首期不申请辅助功能权限；未来变更必须返回 Scope | [KNOWN] 产品/安全负责人 |
| [KNOWN] 外部文本隐私 | P1 | [KNOWN] 文本可能来自网页、书籍或敏感文档，并可能发送至远程 AI Provider | [KNOWN] 不记录原文；保留既有 Provider 告知与缓存风险项 | [KNOWN] 产品/隐私负责人 |
| [KNOWN] 重复事件导致重复计费 | P1 | [INFERRED] 冷启动与生命周期回调可能重复或乱序交付 | [INFERRED] 原生单调 sequence、Dart 最大 sequence 去重和 race tests | [KNOWN] 研发负责人 |

[KNOWN] P1 阻断状态：无未关闭 P1 阻断问题；隐私、重复计费、生命周期、输入边界和宿主兼容风险均已映射到 S1-S5，负责人未指派不改变技术输入完整性。

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. macOS `NSServices` 系统入口 | [KNOWN] 已确认 | [INFERRED] 系统接收选区 → 原生校验 → 唤起窗口 → Dart 处理翻译请求 | [INFERRED] 宿主不支持时不显示；冷启动缓存一次请求 | [KNOWN] Safari、Chrome、Books 需实机验证；不承诺自绘浮动按钮 | [INFERRED] 最贴近现有 macOS 主窗口能力，权限较小，切片可验证 | [KNOWN] 系统入口样式和位置不由应用完全控制 | [KNOWN] 用户已确认 |
| B. macOS Action Extension 内展示翻译 | [KNOWN] 已排除 | [INFERRED] 系统接收选区 → extension 内显示轻量翻译视图 | [INFERRED] 主 App 未启动时由 extension 独立完成任务 | [KNOWN] 不进入首期范围 | [INFERRED] 更符合 extension 生命周期 | [KNOWN] 与用户明确的“弹出主窗口”冲突，且引入第二套 UI/状态边界 | [KNOWN] 用户已确认 `NSServices` 主窗口方案 |
| C. 自定义跨 App 浮动按钮 | [KNOWN] 已排除 | [INFERRED] 监测选区并在其他 App 上方绘制按钮，点击后打开 AITrans | [INFERRED] 权限拒绝、坐标变化和宿主安全限制均需处理 | [KNOWN] 不进入首期范围 | [INFERRED] 最接近字面交互 | [INFERRED] 权限、隐私、兼容性和商店审核风险最高 | [KNOWN] 用户已接受系统入口 |

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | [KNOWN] `TDD_INPUT_READY` |
| 下一步路由 | [KNOWN] 按 S1 至 S5 顺序转 `hicode:tdd` |
| 未覆盖设计树节点 | [KNOWN] 无；Safari、Chrome、Books 的真实兼容结论由 S5 产出，不能在 Scope 中预判 |

### 最终 TDD 切片

| 任务 | 目标与设计树节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点与测试重点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|---|---|
| S1 外部请求模型、配置与校验 | [KNOWN] 建立 typed external request 和可配置 5,000 code points 边界；MAIN-2、BRANCH-2 | [KNOWN] 用户确认的长度、trim、超长文案和不截断规则 | [KNOWN] 内：sequence、source、text、正整数配置、Unicode code points 校验；外：手动输入框全局限额、AI Provider token 估算 | [INFERRED] 待新增 `lib/core/config/external_translation_config.dart`, `lib/core/platform/external_translation_request.dart` 或等价文件及 focused tests | [KNOWN] 先写配置非正值、空白、1、4,999、5,000、5,001、复合 Unicode 输入 RED tests | [KNOWN] focused `flutter test` + `flutter analyze` | [KNOWN] 若必须新增依赖才能定义字符语义，或需要把限制扩展到手动输入，则返回 Scope |
| S2 Dart 外部请求协调与 UI 同步 | [KNOWN] 收到合法请求后覆盖输入、取消旧请求并立即翻译；MAIN-4、BRANCH-3 | [KNOWN] S1 typed request；现有 `TranslateController` generation guard 和 `CommandBar` | [KNOWN] 内：sequence 小于等于最大已处理值时拒绝、更大 sequence latest-wins、输入 controller 同步、超长错误状态；外：修改 Provider 协议、队列 | [INFERRED] `lib/features/translate/logic/`, `command_bar.dart`, `app.dart` 或独立 coordinator 及 controller/widget tests | [KNOWN] 先写外部 provider 更新后输入框显示、translateNow 一次、重复/乱序 sequence 不追加、旧流晚到不覆盖、5,001 不调用 AI tests | [KNOWN] focused controller/widget tests | [KNOWN] 若 UI 必须直接依赖 MethodChannel 或需改变既有手动输入语义，则返回 Scope |
| S3 macOS `NSServices` 注册与载荷解析 | [KNOWN] 在系统 Services/上下文菜单注册“使用 AITrans 翻译”并解析只读纯文本；MAIN-1、MAIN-2、BRANCH-1/2 | [KNOWN] Apple `NSServices` 契约；当前 macOS 10.15 deployment target | [KNOWN] 内：`NSSendTypes`、菜单名、pasteboard 纯文本、进程内单调 sequence；外：Action Extension、自定义浮层、辅助功能权限、回写宿主文本 | [INFERRED] `macos/Runner/Info.plist`, `AppDelegate.swift` 或独立 service provider 及 `macos/RunnerTests/` | [KNOWN] 先写有效纯文本、无文本、多项/不支持类型、sequence 递增、原文不进错误 tests；再注册 Service | [KNOWN] Runner XCTest + macOS debug build + plist inspection | [KNOWN] Safari、Chrome 或 Books 均无法暴露该 Service，或实现要求解除 App Sandbox 时停止并返回 Scope |
| S4 macOS 窗口生命周期与 Flutter bridge | [KNOWN] 冷启动、隐藏、后台和前台状态均恢复单一主窗口并一次性交付；MAIN-3/4、BRANCH-3/4 | [KNOWN] S2 coordinator、S3 service provider、现有 `window_manager` | [KNOWN] 内：引擎就绪前单个 latest pending request、show/focus、bridge timeout、重复 callback 去重；外：多窗口、后台队列 | [INFERRED] `macos/Runner/`, `lib/main.dart`, `lib/core/platform/` 及 platform/Dart tests | [KNOWN] 先写 cold/warm/hidden、两次启动前请求 latest-wins、bridge failure、无原文日志 tests | [KNOWN] XCTest + focused Flutter tests + macOS debug build | [KNOWN] 若 bridge 需要把原文放入启动参数、日志或持久化，或无法证明一次性交付，则停止并返回 Scope |
| S5 宿主矩阵与全量回归 | [KNOWN] 产出可复核的 Safari、Chrome、Books 兼容证据并保护其他平台；ROOT、BRANCH-1/4 | [KNOWN] S1-S4 完成实现；公开非敏感测试文本 | [KNOWN] 内：配置的 macOS 10.15 deployment baseline、可用测试系统上的冷/热启动、正常/超长文本、Service 禁用；外：iOS/Android 功能实现 | [INFERRED] host verification checklist, `test/`, `macos/RunnerTests/` | [KNOWN] 自动化回归先行；手工矩阵只记录真实结果，不把未支持宿主写成成功 | [KNOWN] `dart format --output=none --set-exit-if-changed lib test`; `flutter analyze`; `flutter test`; macOS debug build；Safari/Chrome/Books 实机记录 | [KNOWN] 任一目标宿主不支持 `NSServices` 或主窗口行为不一致时停止，不得把该宿主标为验收通过 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-2/BRANCH-2 | [KNOWN] 空白、1、4,999、5,000、5,001 code points、富文本与多项载荷 | boundary | P1 | [KNOWN] 人工脱敏文本和复合 Unicode fixture | S1/S3 |
| MAIN-3 | [KNOWN] 冷启动、热启动、隐藏窗口恢复、引擎未就绪 | lifecycle | P1 | [KNOWN] 确定性 request fixture | S4 |
| MAIN-4 | [KNOWN] 外部状态同步到输入框、取消旧请求并立即翻译 | widget/controller | P1 | [KNOWN] fake `AIProvider` | S2 |
| BRANCH-1 | [KNOWN] macOS Safari、Chrome、Books 与不支持宿主 | manual/integration | P1 | [KNOWN] 非敏感公开文本 | S3/S5 |
| BRANCH-3 | [KNOWN] 重复 callback、连续外部请求、旧翻译晚到 | concurrency | P1 | [KNOWN] controllable fake stream | S2/S4 |
| BRANCH-4 | [KNOWN] macOS Service 禁用、启动失败、bridge timeout | failure injection | P1 | [KNOWN] 不含原文的错误 fixture | S4/S5 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | [INFERRED] 否 |
| 判断理由 | [INFERRED] `NSServices` 可封装在 macOS Runner 内，未引入辅助功能权限、全局覆盖层或公共 SDK 接口，不满足难逆条件 |
| 涉及决策点 | [KNOWN] 系统 Services 入口已确认；若未来改为自定义浮层或 extension 内独立翻译 UI，必须重新评估 ADR |

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 建议更新 | [INFERRED] 增加“外部选中文本请求”“宿主 App”“macOS Text Service”术语与 5,000 code points 规则 | [KNOWN] 负责人未指派，按项目规则暂不正式写入长期上下文 | [KNOWN] 待负责人确认 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 建议更新 | [KNOWN] Feature 索引候选 `cross-app-selection-translate`，Scope 状态 `TDD_INPUT_READY` | [KNOWN] 负责人未指派，按项目规则暂不正式更新 Feature 索引 | [KNOWN] 待负责人确认 |
| `docs/adr/` | [KNOWN] 跳过 | [INFERRED] 已确认的 `NSServices` Runner 封装不满足难逆条件 | [KNOWN] 若未来改为高权限自定义浮层再读取模板 | [KNOWN] 当前不需要 |

## 14. 文档处理清单

| 文档 | 处理结果 |
|---|---|
| `docs/features/cross-app-selection-translate/feature_context.md` | [KNOWN] 已更新；状态为 `TDD_INPUT_READY` |
| `docs/features/cross-app-selection-translate/scope-plan.md` | [KNOWN] 已更新；结论为 `TDD_INPUT_READY`，包含 S1-S5 |
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 未更新；等待负责人确认长期术语和规则 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 未更新；等待负责人确认 Feature 索引 |
| `docs/adr/` | [KNOWN] 未创建 ADR |
