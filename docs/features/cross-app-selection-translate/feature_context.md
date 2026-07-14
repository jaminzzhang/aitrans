# feature_context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] 跨 App 选中文本快速翻译 |
| feature-id | [KNOWN] `cross-app-selection-translate` |
| 需求来源 | [KNOWN] 用户要求在浏览器网页、Books 等 App 中选中文字时出现翻译入口，点击后弹出 AITrans 主窗口并翻译 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 当前状态 | [KNOWN] `TDD_INPUT_READY`；feature-id、首期仅支持 macOS、系统 Services 入口、立即翻译、latest-wins 与可配置 5,000 Unicode code points 上限已由用户于 2026-07-14 确认 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 从其他 App 接收选中文本 | [KNOWN] 用户不需要先复制并手动切换到 AITrans | [KNOWN] 在已确认的目标平台和宿主 App 矩阵中，系统入口能把非空选中文本交给 AITrans |
| [KNOWN] 唤起翻译界面 | [KNOWN] 用户点击翻译入口后看到 AITrans macOS 主窗口 | [KNOWN] 冷启动、后台和前台状态均只出现一个主窗口并处理一次有效请求 |
| [KNOWN] 使用选中文本发起翻译 | [KNOWN] 选中文本覆盖当前输入并立即翻译；进行中的旧请求被取消，最新外部请求优先 | [KNOWN] 输入框显示选中文本；每个被接受的 Service 请求最多触发一次翻译；旧响应不得覆盖新状态 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] macOS 文本 Service 入口 | [KNOWN] 通过 `NSServices` 在系统 Services/上下文菜单提供“使用 AITrans 翻译”入口 | [KNOWN] 用户于 2026-07-14 确认接受系统入口，不要求自定义悬浮按钮 |
| [KNOWN] 外部文本到 Flutter 状态桥接 | [INFERRED] 原生层解析、校验文本后，通过受控平台通道交给 Dart 层 | [KNOWN] 当前项目没有现成外部文本入口 |
| [KNOWN] macOS 主窗口唤起 | [INFERRED] 恢复或启动 AITrans 单一主窗口 | [KNOWN] 用户明确要求“弹出主窗口” |
| [KNOWN] 翻译状态接入 | [INFERRED] 外部输入写入统一输入状态并按已确认触发策略调用现有控制器 | [KNOWN] 当前 `TranslateController` 已提供 `translateNow` |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [INFERRED] 读取任意 App 当前选区 | [KNOWN] 未获用户授权，且可能要求辅助功能权限或越过宿主 App 明示分享边界 | [KNOWN] 首期只处理用户主动调用系统入口后交付的文本 |
| [INFERRED] 后台持续监听剪贴板 | [KNOWN] 用户未要求，且引入隐私、误触发和生命周期风险 | [KNOWN] 不以剪贴板轮询代替平台集成 |
| [KNOWN] 自定义悬浮按钮覆盖所有 App | [KNOWN] 用户已确认接受系统 Services/上下文菜单入口 | [KNOWN] 不申请辅助功能权限，不持续监测其他 App 选区 |
| [KNOWN] macOS Action Extension 内翻译 UI | [KNOWN] 用户要求弹出主窗口，且已确认使用系统 Services/上下文菜单入口 | [KNOWN] 首期不新增第二套 extension 翻译界面 |
| [INFERRED] 图片 OCR、网页全文或文件翻译 | [KNOWN] 当前输入明确为选中文字 | [KNOWN] 非文本内容另立 Scope |
| [INFERRED] 修改或替换宿主 App 原文 | [KNOWN] 当前目标是查看翻译，不是回写 | [KNOWN] 首期只读处理外部选区 |
| [KNOWN] iOS 与 Android 实现 | [KNOWN] 用户于 2026-07-14 确认首期仅支持 macOS | [KNOWN] 后续平台分别建立独立 Scope 或子需求，不复用 macOS 验收结论 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户在 macOS 其他 App 选中非空文本并主动选择 AITrans Service | [INFERRED] `NSServices` 接收文本，唤起 AITrans，并把文本送入翻译状态机 | [KNOWN] 用户看到该文本对应的翻译界面或明确失败 | [KNOWN] macOS 宿主 App × 冷/热启动矩阵 | P1 | [KNOWN] 主干与边界已确认 |
| MAIN-1 | Service 发现 | [KNOWN] macOS 已安装 AITrans，宿主提供兼容的 Services 菜单 | [INFERRED] 在 Runner `Info.plist` 注册只接收纯文本的 `NSServices` 项 | [KNOWN] 合格文本选区出现“使用 AITrans 翻译”系统菜单项 | [KNOWN] 安装、启用、禁用和升级场景 | P1 | [KNOWN] 入口已确认 |
| MAIN-2 | 文本接收 | [KNOWN] 用户点击入口，宿主提供文本 | [INFERRED] 原生层读取单个纯文本载荷，Dart 边界按可注入配置校验 trim 后的 Unicode code points 数 | [KNOWN] 1 至 5,000 code points 的合法文本或结构化拒绝 | [KNOWN] 空白、4,999、5,000、5,001、富文本与多项载荷测试 | P1 | [KNOWN] 用户已确认默认上限 |
| MAIN-3 | 生命周期 | [KNOWN] AITrans 可能未启动、隐藏、后台或已显示 | [INFERRED] macOS 原生层按单实例规则启动、恢复并聚焦主窗口 | [KNOWN] 仅一个可见主窗口处理最新有效请求 | [KNOWN] 冷启动、热启动、隐藏窗口和重复触发测试 | P1 | [INFERRED] 方案候选 |
| MAIN-4 | 状态桥接 | [KNOWN] 原生层得到合法文本且 Flutter 已就绪 | [INFERRED] 通过 typed platform boundary 交付外部翻译请求 | [KNOWN] Dart 层收到一次带来源和进程内单调 sequence 的事件 | [KNOWN] 启动前缓存、引擎就绪、重复事件测试 | P1 | [INFERRED] 方案候选 |
| MAIN-5 | 翻译触发 | [KNOWN] Dart 层收到有效外部文本 | [KNOWN] 覆盖输入框、取消旧请求并调用 `translateNow`；latest-wins | [KNOWN] loading/streaming/complete/error 状态闭环 | [KNOWN] UI、Controller 与 stale-response 回归测试 | P1 | [KNOWN] 用户已确认 |
| BRANCH-1 | 不支持的宿主 | [KNOWN] 宿主不提供选中文本或不展示平台入口 | [KNOWN] 不绕过宿主权限抓取内容 | [KNOWN] 功能不可用且不读取文本 | [KNOWN] 宿主兼容矩阵记录 | P1 | [INFERRED] 推荐边界 |
| BRANCH-2 | 无效载荷 | [KNOWN] trim 后文本为空、类型不符或超过配置的 5,000 Unicode code points | [KNOWN] 拒绝请求；超长显示“所选文本过长，请缩短至 5,000 字符以内”；不启动远程请求 | [KNOWN] 无 AI 调用、无原文日志 | [KNOWN] 0、1、4,999、5,000、5,001 code points boundary tests | P1 | [KNOWN] 用户已确认 |
| BRANCH-3 | 重复/并发 | [KNOWN] 用户连续触发或冷启动期间收到多次请求 | [INFERRED] 使用进程内单调 sequence 拒绝重复与乱序旧请求；更大 sequence 执行 latest-wins 并取消旧翻译 | [KNOWN] 同一 Service 请求最多交付一次，只有最新请求可更新 UI | [KNOWN] duplicate callback 与 race tests | P1 | [KNOWN] 用户已确认 latest-wins |
| BRANCH-4 | Service 失败 | [KNOWN] macOS Service 被禁用、系统拒绝启动或桥接失败 | [INFERRED] 结束 Service 请求并显示安全错误 | [KNOWN] 不挂起宿主，不泄漏选中文本 | [KNOWN] disabled/timeout/channel failure tests | P1 | [INFERRED] 方案候选 |

## 4. 核心业务规则

| 规则编号 | 业务域 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|---|
| CST-001 | Quick invocation | [KNOWN] 只有用户主动选择 AITrans 系统入口后才能接收选中文本 | [KNOWN] 宿主交付的文本 | [KNOWN] 外部翻译请求 | [KNOWN] 不后台扫描其他 App | [KNOWN] 用户已确认系统入口 |
| CST-002 | Privacy | [KNOWN] 外部选中文本不得写入日志 | [KNOWN] 原文 | [KNOWN] 仅在内存状态与既有翻译/缓存边界中流转 | [KNOWN] 既有缓存保留风险仍存在 | [KNOWN] 项目规则 |
| CST-003 | Validation | [KNOWN] Service 文本 trim 后必须为 1 至配置值个 Unicode code points；默认配置值为 5,000 | [KNOWN] Service 纯文本 | [KNOWN] 合法请求或明确拒绝 | [KNOWN] 超长不截断、不调用 AI；配置值必须为正整数 | [KNOWN] 用户确认与项目规则 |
| CST-004 | Idempotency | [INFERRED] macOS provider 为每次用户触发分配进程内单调递增序号；Dart 只接受大于已处理最大序号的请求 | [KNOWN] sequence 与文本 | [KNOWN] 同一或乱序旧请求不交付，新请求 latest-wins | [KNOWN] 应用重启后两端序号状态同时重置；用户重新触发产生新序号 | [INFERRED] 已确认规则的实现方案 |
| CST-005 | Host boundary | [KNOWN] 不承诺支持未提供对应 macOS 文本动作入口的宿主 App | [KNOWN] 宿主能力 | [KNOWN] 兼容或不可用 | [KNOWN] Safari、Chrome 与 Books 必须在 macOS 实机验证 | [KNOWN] 用户已确认系统入口边界 |

## 5. 高严谨业务系统风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 领域业务逻辑严谨性 | [KNOWN] 是 | [KNOWN] 外部文本覆盖当前输入并立即进入既有翻译流；默认上限 5,000 Unicode code points | [KNOWN] 无 | P1 |
| 金额与关键数值精度 | [KNOWN] 间接涉及 | [INFERRED] 重复事件可能产生重复 AI 计费请求 | [INFERRED] 已采用进程内单调 sequence 去重与 latest-wins 方案 | P1 |
| 交易与数据一致性 | [KNOWN] 否 | [KNOWN] 未发现数据库交易 | [KNOWN] 无 | NONE |
| 状态流转 | [KNOWN] 是 | [KNOWN] 冷启动、后台恢复、前台已显示三类入口状态；多请求 latest-wins | [KNOWN] 无 |
| 幂等与并发 | [KNOWN] 是 | [INFERRED] 原生生命周期和 Flutter 初始化可能重复交付事件 | [INFERRED] 进程内单调序号 + Dart 最大已处理序号；不同新请求 latest-wins | P1 |
| 权限与审计 | [KNOWN] 是 | [KNOWN] 首期采用 `NSServices`，不使用辅助功能监听或全局覆盖层 | [KNOWN] Service 注册与用户禁用行为 | P1 |
| 隐私与适用监管/合规 | [KNOWN] 是 | [KNOWN] 用户选择的其他 App 文本会进入 AITrans，并可能发送给远程 Provider | [KNOWN] 首次告知和敏感文本策略 | P1 |
| 生产变更与回滚 | [KNOWN] 是 | [INFERRED] 新增 macOS service registration 会改变安装包能力 | [KNOWN] 删除 `NSServices` 注册并保留原翻译入口可回滚该能力 | P1 |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| [KNOWN] 外部请求配置 | 待新增 `lib/core/config/external_translation_config.dart` 或等价对象 | [INFERRED] 定义可注入、可测试的 `maxCharacters`，默认 5,000；拒绝非正配置 | P1 |
| [KNOWN] 跨平台边界 | `lib/core/platform/` | [INFERRED] 新增 typed external-translation request 接口与 Unicode code point 边界校验 | P1 |
| [KNOWN] 应用启动 | `lib/main.dart`, `lib/app.dart` | [INFERRED] 需要在 Flutter 就绪后消费启动前收到的请求 | P1 |
| [KNOWN] 输入 UI | `lib/features/translate/ui/command_bar.dart` | [KNOWN] 当前 `TextEditingController` 不会随 `inputTextProvider` 外部更新自动同步 | P1 |
| [KNOWN] 翻译状态 | `lib/features/translate/logic/translate_controller.dart` | [INFERRED] 需要统一外部提交入口与重复请求保护 | P1 |
| [KNOWN] macOS 原生 | `macos/Runner/Info.plist`, `macos/Runner/AppDelegate.swift` 或独立 service provider | [INFERRED] 注册 `NSServices`、读取 pasteboard 纯文本、恢复主窗口并桥接 Flutter | P1 |
| [KNOWN] iOS 与 Android | `ios/`, `android/` | [KNOWN] 首期不修改，仅做跨平台构建回归保护 | P2 |
| [KNOWN] 测试 | `test/`, 平台 Runner tests | [INFERRED] 需要 Dart 状态测试、原生载荷测试和宿主实机矩阵 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| [KNOWN] 冷启动、热启动、后台恢复 | 生命周期测试 | P1 | [KNOWN] 用户动作可能在 Flutter 引擎初始化前到达 |
| [KNOWN] Safari/Chrome/Books 等宿主矩阵 | 实机兼容测试 | P1 | [KNOWN] 系统入口是否出现取决于平台与宿主提供能力 |
| [KNOWN] 空白、富文本、多项载荷与 4,999/5,000/5,001 code points | 边界测试 | P1 | [KNOWN] 外部输入不可信；上限来自可注入代码配置 |
| [KNOWN] 重复 Service/extension callback | 并发测试 | P1 | [INFERRED] 重复翻译可能重复计费 |
| [KNOWN] 原文不进入日志 | 隐私测试 | P1 | [KNOWN] 项目规则禁止输出用户内容 |
| [KNOWN] 不支持平台的构建回归 | 构建测试 | P1 | [KNOWN] 平台代码必须由平台检查隔离 |

## 8. 待确认问题

| 问题 | 风险等级 | 影响 | 建议确认人 | 期望材料 |
|---|---|---|---|---|
| [KNOWN] 业务、研发与测试负责人分别是谁？ | P3 | [KNOWN] 影响后续确认与交付责任，不改变当前 TDD 技术输入 | [KNOWN] 项目负责人 | [KNOWN] 负责人名单 |

## 9. 已确认事项

| 事项 | 风险等级 | 影响 | 确认结论 | 确认来源 |
|---|---|---|---|---|
| [KNOWN] feature-id | P3 | [KNOWN] 固定单需求目录 | [KNOWN] `cross-app-selection-translate` | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 首期平台范围 | P1 | [KNOWN] 排除 iOS、Android 原生入口和对应验收矩阵 | [KNOWN] 首期仅支持 macOS | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] macOS 入口形态 | P1 | [KNOWN] 排除自定义浮层与 Action Extension 内第二套 UI | [KNOWN] 使用系统 Services/上下文菜单项，不要求自定义悬浮按钮 | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] 外部翻译状态规则 | P1 | [KNOWN] 固定输入覆盖、取消和并发处理 | [KNOWN] 立即翻译；覆盖当前输入；取消旧请求；不同请求 latest-wins；同一请求最多交付一次 | [KNOWN] 用户于 2026-07-14 确认 |
| [KNOWN] Service 文本上限 | P1 | [KNOWN] 固定校验、错误和计费边界 | [KNOWN] trim 后最多 5,000 Unicode code points；值由代码配置；超长不截断、不调用 AI 并显示确认文案 | [KNOWN] 用户于 2026-07-14 确认 |
