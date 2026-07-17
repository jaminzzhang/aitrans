# feature_context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] macOS 状态栏常驻与主窗口恢复 |
| feature-id | [KNOWN] `macos-menu-bar-residency` |
| 需求来源 | [KNOWN] 用户要求 AITrans 在 macOS 状态栏常驻；用户于 2026-07-16 追加确认左键点击需切换主窗口；2026-07-17 追加确认右键菜单包含“翻译、设置、退出”，翻译优先读取选中文字、回退剪贴板，并授权请求辅助功能权限；随后要求菜单增宽、退出前增加分割线、翻译显示快捷键并优化样式，最终把菜单宽度调整为 180pt；同日确认全局 `⌘⇧T` 从隐藏打开窗口时读取当前选区并展示在输入框 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 当前状态 | [COMPUTED] `LOCAL_VERIFIED`；左键 show/close toggle、右键动作和 180pt/分割线/快捷键/语义图标样式均完成本地自动化；既有动作完成 macOS Debug 宿主验证；真实宿主未触发“翻译”，以避免读取并发送用户当前剪贴板 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 关闭窗口后保持 AITrans 可用 | [KNOWN] 用户关闭最后一个主窗口后，应用进程不退出 | [KNOWN] 关闭主窗口后只有窗口从屏幕移除；进程、快捷键和 macOS Service 继续可用 |
| [KNOWN] 从状态栏切换主窗口 | [KNOWN] 用户点击 AITrans 状态栏项目可切换已有主窗口的展示与关闭状态 | [KNOWN] 已关闭、已隐藏或已最小化窗口恢复并聚焦；已显示窗口关闭；不创建第二个主窗口 |
| [KNOWN] 保留标准退出路径 | [KNOWN] 窗口关闭与应用退出语义分离 | [KNOWN] `Cmd+Q`、应用菜单“退出”和调试脚本的正常退出 AppleEvent 仍终止进程 |
| [KNOWN] 允许用户隐藏状态栏项目 | [KNOWN] macOS 设置页提供独立开关，默认显示状态栏项目 | [INFERRED] 切换立即生效并持久化；失败时 UI 回退并显示不含内部异常的错误 |
| [KNOWN] 右键状态栏菜单 | [KNOWN] 右键弹出宽 180pt 的“翻译、设置、分割线、退出”原生菜单；翻译显示独立菜单快捷键 `⌘T`，三项使用语义图标；翻译优先读取当前选中文字，无权限、无选区或空白时回退剪贴板 | [KNOWN] 翻译打开主窗口并进入既有翻译流程；设置打开既有设置页；退出终止进程 |
| [KNOWN] 快捷键选区预填 | [KNOWN] `⌘⇧T` 从隐藏状态打开窗口时，在激活 AITrans 前读取当前选区，选区不可用时回退剪贴板 | [KNOWN] 文本只填入输入框，不自动发起翻译；从显示状态关闭窗口时不读取文本 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] macOS 单进程生命周期 | [KNOWN] 关闭最后窗口不退出，显式退出仍退出 | [KNOWN] 用户确认；当前 `AppDelegate` 的行为相反 |
| [KNOWN] 原生状态栏项目 | [KNOWN] 使用 AppKit `NSStatusItem`，保留强引用并注册点击 action | [KNOWN] 用户确认原生 AppKit 方案；Apple `NSStatusItem` 契约 |
| [KNOWN] 单一主窗口展示与切换 | [KNOWN] Dock reopen 和外部翻译 Service 复用窗口恢复边界；状态栏在同一 presenter 上增加 show/close toggle；全局快捷键保持既有 toggle | [KNOWN] 用户追加确认状态栏 toggle；统一 presenter 可避免生命周期漂移 |
| [KNOWN] macOS 状态栏偏好 | [KNOWN] 默认开启，用户可在设置页关闭或重新开启 | [KNOWN] 用户确认提供状态栏图标开关 |
| [KNOWN] 图标与可访问性 | [INFERRED] 提供兼容 macOS 10.15 的 bundled template image、tooltip 和 accessibility label；缺图时以短文本回退 | [KNOWN] 项目最低目标为 macOS 10.15；状态栏项目必须可识别和可点击 |
| [KNOWN] 自动化和宿主验证 | [KNOWN] 覆盖原生生命周期、幂等、偏好、Flutter bridge、设置 UI 和 macOS Debug 单进程启动 | [KNOWN] 项目测试规则和调试启动规则 |
| [KNOWN] 辅助功能与文本回退 | [KNOWN] 仅在用户显式选择右键“翻译”时请求 Accessibility；拒绝或尚未授权时不阻断，回退 `NSPasteboard.general` | [KNOWN] 用户于 2026-07-17 确认支持请求辅助功能权限 |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [KNOWN] iOS、Android 状态栏或后台常驻 | [KNOWN] 用户只要求 macOS，且移动平台生命周期模型不同 | [KNOWN] 移动平台行为保持不变 |
| [KNOWN] 移除 Dock 图标或改为 `LSUIElement` agent app | [KNOWN] 用户明确要求保留 Dock 图标 | [KNOWN] 应用仍是标准前台 App，可通过 Dock 恢复 |
| [KNOWN] 状态栏弹出翻译面板、历史菜单或第二套 UI | [KNOWN] 用户确认菜单动作复用现有主窗口和设置页 | [KNOWN] 不创建 popover、历史窗口或第二套翻译 UI |
| [KNOWN] 登录时启动 | [KNOWN] 当前需求未要求开机自启 | [KNOWN] 不新增 Login Item |
| [KNOWN] 多窗口支持 | [KNOWN] 当前产品与用户确认均指向单一主窗口 | [KNOWN] 所有入口只恢复已有主窗口 |
| [KNOWN] AI Provider、翻译、缓存或凭证 schema 变更 | [KNOWN] 状态栏生命周期与翻译业务无关 | [KNOWN] 不修改远程请求、缓存内容或加密凭证状态结构 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] AITrans 已在 macOS 启动 | [INFERRED] 维持状态栏入口与单主窗口恢复闭环 | [KNOWN] 关闭窗口后仍可一击恢复，显式退出仍有效 | [KNOWN] 生命周期矩阵与单进程检查 | P1 | [KNOWN] 已确认 |
| MAIN-1 | 启动与注册 | [KNOWN] 应用完成原生启动，偏好不存在或为开启 | [INFERRED] 幂等创建一个 `NSStatusItem` 并配置 template icon、tooltip、accessibility label 和 action | [KNOWN] 系统分配空间时显示一个 AITrans 状态栏项目 | [KNOWN] 默认值、重复注册、bundle asset XCTest | P1 | [KNOWN] 已确认 |
| MAIN-2 | 窗口关闭 | [KNOWN] 用户关闭最后一个主窗口 | [INFERRED] 返回“不随最后窗口退出”；保留 `releasedWhenClosed = false` 的单一窗口对象 | [KNOWN] 窗口从屏幕移除，进程继续运行 | [KNOWN] delegate 返回值、窗口引用和进程存活验证 | P1 | [KNOWN] 已确认 |
| MAIN-3 | 状态栏切换 | [KNOWN] 用户点击状态栏项目 | [KNOWN] 窗口 visible、key 且非最小化时调用 `close()`；窗口已关闭、隐藏、后台非 key 或最小化时恢复、激活并 `makeKeyAndOrderFront` | [KNOWN] 原主窗口在关闭与显示/聚焦之间切换 | [KNOWN] visible/key→closed→visible、stale-visible/non-key XCTest 和真实三击状态矩阵；窗口数量不变 | P1 | [KNOWN] 用户于 2026-07-16 追加确认 |
| MAIN-4 | Dock 与既有入口 | [KNOWN] Dock reopen、全局快捷键或 macOS Service 请求到达 | [INFERRED] 复用同一主窗口 presenter，不创建新窗口 | [KNOWN] 所有入口得到一致的显示和聚焦结果 | [KNOWN] Dock reopen XCTest、快捷键/Service 回归 | P1 | [KNOWN] 已确认 |
| MAIN-5 | 偏好切换 | [KNOWN] macOS 设置页切换“显示状态栏图标” | [INFERRED] 经 typed platform bridge 即时创建或移除状态项，并以独立 `UserDefaults` 键持久化 | [KNOWN] 重启后保持选择；Provider 和凭证状态不变 | [KNOWN] 默认/开/关/重启恢复、UI failure rollback tests | P1 | [INFERRED] 方案已由确认范围收敛 |
| MAIN-6 | 显式退出 | [KNOWN] `Cmd+Q`、菜单 Quit 或正常退出 AppleEvent | [KNOWN] 继续走 AppKit `terminate:` 退出流程 | [KNOWN] 进程退出并释放 Hive 锁与状态栏项目 | [KNOWN] 菜单 wiring、调试脚本重启与单进程验证 | P1 | [KNOWN] 已确认 |
| MAIN-7 | 右键菜单 | [KNOWN] 状态栏收到 rightMouseUp | [KNOWN] 展示 180pt 最小宽度的原生菜单，顺序固定为“翻译、设置、分割线、退出”；翻译显示独立菜单快捷键 `⌘T`；三项使用语义图标；不触发左键 toggle | [KNOWN] 用户选择一项后仅执行对应动作 | [KNOWN] presentation/command/controller XCTest 与真实 AX 菜单读取 | P1 | [KNOWN] 用户于 2026-07-17 确认并追加视觉要求 |
| MAIN-8 | 菜单翻译 | [KNOWN] 用户选择“翻译” | [KNOWN] 按需请求 Accessibility，读取 focused element 的 selected text；空值时读取普通剪贴板；有文本则复用外部翻译校验和翻译流程，无文本则只打开并聚焦输入 | [KNOWN] 唯一主窗口展示，设置弹层关闭，输入文本被翻译或等待输入 | [KNOWN] resolver 优先级、共享 sequence、Flutter command/coordinator tests | P1 | [KNOWN] 用户于 2026-07-17 确认 |
| BRANCH-1 | 重复注册/点击 | [KNOWN] 生命周期回调或设置重复提交相同状态 | [INFERRED] 状态管理器按目标状态幂等处理并持有至多一个 item | [KNOWN] 不出现重复图标或重复窗口 | [KNOWN] call-count 与 identity tests | P1 | [INFERRED] 已收敛 |
| BRANCH-2 | 状态栏空间/图标异常 | [KNOWN] 系统未展示状态项或 bundled image 加载失败 | [INFERRED] 不声明系统保证可见；缺图时使用可访问的短文本回退，Dock 与快捷键保持可用 | [KNOWN] 应用不崩溃且仍有恢复路径 | [KNOWN] nil-image failure injection 与回退测试 | P2 | [INFERRED] 已收敛 |
| BRANCH-3 | bridge 或持久化失败 | [KNOWN] Flutter channel 不可用或原生偏好更新失败 | [INFERRED] 返回 typed error，设置开关回退到真实状态并显示通用错误 | [KNOWN] UI 不显示虚假成功，Provider 配置不受影响 | [KNOWN] method-channel failure 与 widget tests | P1 | [INFERRED] 已收敛 |
| BRANCH-4 | 非 macOS 平台 | [KNOWN] 应用运行于 iOS 或 Android | [KNOWN] 不注册状态栏 channel，设置页不显示该开关 | [KNOWN] 移动端启动与设置行为不变 | [KNOWN] platform-guard tests 与静态分析 | P2 | [KNOWN] 已收敛 |
| BRANCH-5 | 辅助功能拒绝或无选区 | [KNOWN] `AXIsProcessTrustedWithOptions` 返回 false，或 focused element 不提供非空 `AXSelectedText` | [KNOWN] 不报错、不记录选区，回退剪贴板 | [KNOWN] 菜单翻译仍可用；剪贴板也为空时只打开翻译输入 | [KNOWN] resolver failure injection 与 coordinator nil-text test | P1 | [KNOWN] 已收敛 |

## 4. 核心业务规则

| 规则编号 | 业务域 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|---|
| MBR-001 | [KNOWN] macOS 生命周期 | [KNOWN] 关闭最后一个主窗口不得终止 AITrans | [KNOWN] 主窗口 close | [KNOWN] 窗口不可见、进程存活 | [KNOWN] 显式 Quit 仍终止 | [KNOWN] 用户确认 |
| MBR-002 | [KNOWN] 主窗口切换 | [KNOWN] 状态栏点击必须切换唯一主窗口：当前 visible/key 时关闭，否则恢复并聚焦 | [KNOWN] 状态栏 click | [KNOWN] 已有窗口在 closed 与 visible/key 之间切换 | [KNOWN] 最小化、后台非 key 或陈旧 visible 状态按恢复处理；不创建第二窗口 | [KNOWN] 用户于 2026-07-16 追加确认 |
| MBR-003 | [KNOWN] 状态栏偏好 | [KNOWN] 默认显示状态栏项目，用户可以关闭 | [KNOWN] 无偏好或布尔偏好 | [KNOWN] 一个或零个状态栏 item | [KNOWN] 系统空间不足时无法保证肉眼可见 | [KNOWN] 用户确认 |
| MBR-004 | [INFERRED] 偏好隔离 | [INFERRED] 状态栏偏好必须与 Provider/凭证状态分离 | [KNOWN] macOS 布尔设置 | [KNOWN] 独立原生偏好 | [KNOWN] 不迁移或改写加密凭证 schema | [INFERRED] Scope 设计结论 |
| MBR-005 | [KNOWN] 标准退出 | [KNOWN] `Cmd+Q`、Quit 菜单和 AppleEvent quit 必须真正退出 | [KNOWN] AppKit terminate 请求 | [KNOWN] 进程结束 | [KNOWN] 关闭窗口不等同退出 | [KNOWN] 用户确认 |
| MBR-006 | [INFERRED] 幂等 | [INFERRED] 重复启用、禁用、注册或显示操作不得产生重复 item 或窗口 | [KNOWN] 重复生命周期事件 | [KNOWN] 状态收敛到目标值 | [KNOWN] 进程内规则，不跨重启保留对象 identity | [INFERRED] 生命周期安全要求 |
| MBR-007 | [KNOWN] 菜单输入优先级 | [KNOWN] “翻译”先取非空选中文字，再取非空剪贴板；两者都为空时不得发起 AI 请求 | [KNOWN] Accessibility selected text 与 general pasteboard | [KNOWN] 一个外部翻译请求或仅显示输入页 | [KNOWN] 文本统一 trim，并继续受 5,000 code-point 校验约束 | [KNOWN] 用户确认与现有外部翻译规则 |
| MBR-008 | [KNOWN] 菜单动作隔离 | [KNOWN] 左键只切换窗口；右键只展示菜单；“设置”复用现有 SettingsSheet；“退出”直接调用 AppKit terminate | [KNOWN] mouse event/menu command | [KNOWN] 单一确定动作 | [KNOWN] Flutter bridge 失效不得影响原生退出 | [KNOWN] 用户确认 |
| MBR-009 | [KNOWN] 菜单视觉契约 | [KNOWN] 右键菜单设置 180pt 最小宽度；退出前使用原生分割线；翻译使用独立菜单快捷键 `⌘T`，避免与现有“显示/隐藏窗口”全局快捷键 `⌘⇧T` 冲突；macOS 11 及以上显示语义系统图标 | [KNOWN] menu presentation | [KNOWN] 宽菜单、清晰动作分组和快捷键提示 | [KNOWN] macOS 10.15 无系统符号时保留原生文本菜单，不影响动作 | [KNOWN] 用户最终宽度确认与现有快捷键实现 |
| MBR-010 | [KNOWN] 快捷键选区预填 | [KNOWN] `⌘⇧T` 仅在打开窗口分支读取选区，并且必须先读取再激活窗口；选区不可用时回退剪贴板 | [KNOWN] 全局快捷键与外部文本 | [KNOWN] 输入框更新，不自动调用 Provider | [KNOWN] 关闭分支不读取；读取失败不得阻止窗口打开 | [KNOWN] 用户于 2026-07-17 确认 |

## 5. 金融核心系统风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 保险核心业务逻辑严谨性 | [KNOWN] 否 | [KNOWN] 仅 macOS 客户端窗口生命周期 | [KNOWN] 无 | NONE |
| 金额精度 | [KNOWN] 否 | [KNOWN] 不处理金额 | [KNOWN] 无 | NONE |
| 交易一致性 | [KNOWN] 否 | [KNOWN] 不引入交易或远程写入 | [KNOWN] 无 | NONE |
| 状态流转 | [KNOWN] 是 | [KNOWN] 状态项与窗口存在 visible/hidden/minimized/terminated 状态 | [KNOWN] 无阻断问题 | P1 |
| 幂等与并发 | [KNOWN] 是 | [INFERRED] 启动、偏好和点击事件可能重复到达主线程 | [KNOWN] 无阻断问题 | P1 |
| 权限与审计 | [KNOWN] 是 | [KNOWN] 跨应用读取选区使用 macOS Accessibility，仅在显式菜单“翻译”或 `⌘⇧T` 打开窗口时请求；用户拒绝时回退剪贴板 | [KNOWN] 发行方式需接受关闭 App Sandbox 后不能按普通沙盒 App 路径提交 Mac App Store | P1 |
| 隐私与监管 | [KNOWN] 是 | [KNOWN] 选区或剪贴板文本经既有外部翻译 channel 进入既有 AI 流程；实现不记录文本，真实宿主验证未触发翻译 | [KNOWN] 产品隐私说明需披露按需读取和远程 Provider 处理 | P1 |
| 生产变更与回滚 | [KNOWN] 是 | [KNOWN] macOS Runner 生命周期和资源发生本地客户端变更 | [KNOWN] 无阻断问题 | P2 |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| [KNOWN] 原生生命周期 | `macos/Runner/AppDelegate.swift` | [INFERRED] 状态项初始化、最后窗口关闭不退出、Dock reopen 和显式退出回归 | P1 |
| [KNOWN] 原生窗口 | `macos/Runner/MainFlutterWindow.swift` | [INFERRED] 挂接状态栏偏好 channel，并向单一 window presenter 提供稳定窗口引用 | P1 |
| [KNOWN] 原生权限配置 | `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` | [KNOWN] 移除 App Sandbox entitlement，使用户授予 Accessibility 后可跨应用读取选区 | P1 |
| [KNOWN] 原生资源 | `macos/Runner/Assets.xcassets/` | [INFERRED] 增加兼容 10.15 的 monochrome template image | P2 |
| [KNOWN] 原生测试 | `macos/RunnerTests/RunnerTests.swift` | [INFERRED] 增加状态项、窗口恢复、偏好、Dock reopen 与退出语义 tests | P1 |
| [KNOWN] Dart 平台边界 | `lib/core/platform/` | [INFERRED] 增加 typed menu-bar preference bridge/controller，非 macOS 安全降级 | P1 |
| [KNOWN] 应用命令边界 | `lib/core/platform/application_command_platform_bridge.dart`, `lib/features/app/logic/` | [KNOWN] 接收 showTranslation/showSettings，不接收 quit 或任意方法 | P1 |
| [KNOWN] 设置 UI | `lib/features/settings/ui/settings_page.dart` | [INFERRED] macOS 专属即时开关、loading/error/rollback 状态 | P1 |
| [KNOWN] Flutter 测试 | `test/core/platform/`, `test/features/settings/` | [INFERRED] 增加 channel、platform guard 和设置交互 tests | P1 |
| [KNOWN] 调试流程 | `scripts/run_macos_debug.sh` | [KNOWN] 不计划修改；必须验证正常退出、构建、稳定安装、单进程启动与 Service 注册仍通过 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| [KNOWN] 关闭窗口后进程存活 | lifecycle | P1 | [KNOWN] 当前实现会退出，必须形成回归测试 |
| [KNOWN] 已关闭/隐藏/最小化窗口恢复与可见窗口关闭 | state matrix | P1 | [KNOWN] 用户要求状态栏点击执行 show/close toggle；AppKit 状态不同 |
| [KNOWN] 单 item、单窗口 | idempotency | P1 | [INFERRED] 重复初始化或快速点击不得复制原生对象 |
| [KNOWN] 显式退出 | regression | P1 | [KNOWN] 调试脚本依赖 AppleEvent quit 释放 Hive 锁 |
| [KNOWN] Service 与快捷键恢复 | integration | P1 | [KNOWN] 现有 `ExternalTranslationBridge` 与 `HotkeyService` 都会显示窗口 |
| [KNOWN] 偏好默认值和重启恢复 | persistence | P1 | [KNOWN] 用户确认默认显示并允许关闭 |
| [KNOWN] macOS 10.15 icon | compatibility | P2 | [KNOWN] 当前 deployment target 为 10.15，不能只依赖更高版本系统 symbol API |
| [KNOWN] iOS/Android 不受影响 | platform guard | P2 | [KNOWN] 产品仍支持三个平台，功能仅限 macOS |
| [KNOWN] 右键三项功能 | integration/privacy | P1 | [KNOWN] 菜单顺序、设置导航和退出做真实宿主验证；翻译文本路径只在隔离测试中验证，避免发送用户剪贴板 |
| [KNOWN] 辅助功能拒绝 | permission fallback | P1 | [KNOWN] 首次请求异步返回未授权时立即回退剪贴板，后续授权后可读取 AXSelectedText |

## 8. 待确认问题

| 问题 | 风险等级 | 影响 | 建议确认人 | 期望材料 |
|---|---|---|---|---|
| [KNOWN] 所属版本及负责人尚未指派 | P3 | [KNOWN] 不改变已确认功能范围或 TDD 测试入口 | [KNOWN] 项目负责人 | [KNOWN] 版本计划与责任人清单 |
| [KNOWN] 最终品牌化状态栏 glyph 尚未提供 | P3 | [KNOWN] 不阻断以最小 monochrome AITrans template glyph 验证功能；品牌定稿可替换资源 | [KNOWN] 产品/设计负责人 | [KNOWN] 16/32pt template asset 或视觉确认 |
