# Scope 需求梳理、准入与 TDD 计划

[KNOWN] 本文件是 `SDD-HICODE-scope` 对 `macos-menu-bar-residency` 的需求收敛和 TDD 输入证据，不代表实现、审批或发布结论。

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [COMPUTED] `TDD_INPUT_READY` |
| 最高风险等级 | [COMPUTED] P1 |
| 一句话依据 | [KNOWN] 用户已确认 Feature ID、macOS 范围、左键窗口 toggle、右键三项菜单、选区优先/剪贴板回退、辅助功能权限、Dock 保留、状态栏偏好和原生 AppKit 路线；主干、异常分支和验证入口均已定位 |
| 下一步建议 | [KNOWN] 进入 `SDD-HICODE-tdd`，按 S1 至 S4 执行 |
| 本轮问题状态 | [KNOWN] 无阻断问题 |
| 置信度 | [INFERRED] HIGH（90%）；真实状态栏视觉和完整生命周期仍需 macOS 宿主验证 |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| [KNOWN] 项目入口规则 | `AGENTS.md` | [KNOWN] 是 | [KNOWN] 已初始化 hicode；Scope 文档固定写入 `docs/features/<feature-id>/`；业务实现必须转 TDD | [KNOWN] 无 |
| [KNOWN] 编码规则 | `docs/rules/coding_rules.md` | [KNOWN] 是 | [KNOWN] 平台代码必须隔离并保护非目标平台；新行为需要主路径和失败断言 | [KNOWN] 无 |
| [KNOWN] 长期上下文 | `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | [KNOWN] 是 | [KNOWN] 已有 macOS quick invocation、`window_manager` 和单主窗口；索引没有本 Feature | [KNOWN] 负责人未确认长期上下文更新 |
| [KNOWN] 产品简述 | `aitrans-prd.md` | [KNOWN] 是 | [KNOWN] macOS 属于目标平台，已有全局快捷键快速唤起意图 | [KNOWN] PRD 未描述状态栏驻留 |
| [KNOWN] 用户确认 | 2026-07-16 对话 | [KNOWN] 是 | [KNOWN] 确认 `macos-menu-bar-residency`、首次启动显示、关闭驻留、保留 Dock、状态栏显示开关和原生 AppKit | [KNOWN] 版本与责任人待确认，不阻断技术输入 |
| [KNOWN] Dart 启动与窗口代码 | `lib/main.dart`, `lib/core/platform/hotkey_service.dart`, `lib/app.dart` | [KNOWN] 是 | [KNOWN] 启动时显示/聚焦窗口；快捷键切换 show/hide；没有状态栏实现 | [KNOWN] window show/focus 逻辑分散 |
| [KNOWN] macOS Runner | `AppDelegate.swift`, `MainFlutterWindow.swift`, `MainMenu.xib`, `Info.plist` | [KNOWN] 是 | [KNOWN] 最后窗口关闭当前返回 true；Nib 已设置 `releasedWhenClosed=NO`；Quit 菜单调用 `terminate:`；Service 已有原生 bridge | [KNOWN] 没有 `NSStatusItem`、Dock reopen 或状态栏偏好 channel |
| [KNOWN] 设置持久化 | `settings_preferences_store.dart`, `settings_repository.dart`, `encrypted_provider_credential_store.dart`, `settings_page.dart` | [KNOWN] 是 | [KNOWN] 现有存储只承载 Provider、endpoint、model 和凭证；状态栏偏好不应进入凭证 schema | [KNOWN] 需要独立 macOS 偏好边界 |
| [KNOWN] 原生测试 | `macos/RunnerTests/RunnerTests.swift` | [KNOWN] 是 | [KNOWN] Runner XCTest 已能测试注入式 AppKit service 组件 | [KNOWN] 尚无窗口/状态栏测试 seam |
| [KNOWN] 调试脚本 | `scripts/run_macos_debug.sh` | [KNOWN] 是 | [KNOWN] 脚本依赖正常 AppleEvent quit、Hive 锁释放、稳定安装、Service 注册和单进程存活 | [KNOWN] 生命周期改变后必须实际回归 |
| [KNOWN] Apple AppKit 资料 | [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem), [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar), [applicationShouldTerminateAfterLastWindowClosed](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed%28_%3A%29), [applicationShouldHandleReopen](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen%28_%3Ahasvisiblewindows%3A%29), [NSWindow](https://developer.apple.com/documentation/appkit/nswindow) | [KNOWN] 是 | [KNOWN] 状态项支持 button action；最后窗口关闭可选择不退出；Dock reopen 有专用 delegate；关闭且不 release 的窗口可保留并再次显示 | [KNOWN] 系统状态栏空间不能由应用保证 |

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | [COMPUTED] `NO_BLOCKING_GAPS` |
| 需求分析输入 | [KNOWN] “实现 mac 常驻状态栏，能够在状态栏上点击打开主窗口”及用户对推荐完整方案的确认 |
| 证据缺口 | [KNOWN] 版本、责任人与最终品牌 glyph 待确认；这些缺口不改变生命周期、实现边界、P1 风险或测试重点 |

| 检查项 | 结论 | 证据或缺口 |
|---|---|---|
| [KNOWN] 一句话目标 | [KNOWN] 已明确 | [KNOWN] 关闭主窗口后保持进程驻留，并可点击状态栏项目切换唯一主窗口的展示与关闭 |
| [KNOWN] 范围内/外/非目标 | [KNOWN] 已明确 | [KNOWN] 仅 macOS；保留 Dock；排除移动端、agent app、登录启动、下拉菜单和多窗口 |
| [KNOWN] 可测试验收标准 | [KNOWN] 已明确 | [KNOWN] 覆盖启动、关闭、状态栏、Dock、快捷键、Service、偏好、退出、幂等、失败和平台保护 |
| [KNOWN] 业务规则与异常路径 | [KNOWN] 已明确 | [KNOWN] 默认开启、关闭窗口不退出、状态栏点击 show/close toggle、显式退出、重复操作幂等、bridge 失败回退 |
| [KNOWN] 关键术语冲突 | [KNOWN] 无已知冲突 | [KNOWN] “常驻”定义为应用持有状态项且关闭窗口后进程存活，不承诺系统永远为图标分配可见空间 |
| [KNOWN] 金融核心风险 | [KNOWN] 不涉及核心业务、金额或交易 | [KNOWN] 仅状态流转和幂等达到 P1 |
| [KNOWN] 权限、隐私与审计 | [KNOWN] 新增按需 Accessibility 权限和外部文本输入 | [KNOWN] 用户显式选择“翻译”才请求权限；选区为空/拒绝时回退剪贴板；文本进入既有校验和翻译流程，不记录文本、凭证或异常原文 |
| [KNOWN] 影响范围 | [KNOWN] 已定位到类、文件、资源、测试和调试脚本 | [KNOWN] 原生 Runner、platform bridge、设置 UI、XCTest 与 Flutter tests |
| [KNOWN] 设计树输入 | [KNOWN] 已闭合 | [KNOWN] 主干和 P1 分支均有处理、验证点和停止条件 |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | [KNOWN] macOS 用户关闭 AITrans 主窗口后仍能通过状态栏、Dock、全局快捷键或现有 Service 恢复唯一主窗口；状态栏再次点击可关闭已显示主窗口 |
| 范围内 | [KNOWN] 原生状态项、关闭不退出、窗口 presenter、Dock reopen、默认开启的独立状态栏偏好、macOS 设置开关、template icon、回归测试 |
| 范围外 | [KNOWN] iOS/Android 常驻、`LSUIElement`、隐藏 Dock、登录启动、状态栏 popover/历史/第二套 UI、多窗口、Provider/缓存/凭证 schema 变更 |
| 非目标 | [KNOWN] 不保证 macOS 在菜单栏空间不足时实际展示图标；不把窗口关闭改成应用退出；不后台持续读取选区或剪贴板 |
| 验收标准 | [KNOWN] 首次启动显示主窗口和一个状态项；关闭窗口后进程存活；状态项点击按 hidden/closed/minimized→visible/key、visible→closed 切换同一窗口；偏好即时生效且重启恢复；关闭偏好后 Dock/快捷键仍可恢复；显式 Quit 真退出；现有 Service 与调试脚本通过 |
| feature_context 更新 | [KNOWN] 已创建并收敛到 `TDD_INPUT_READY` |
| ADR 处理 | [INFERRED] 不需要；方案可局部替换和回滚，不改变跨平台公共协议或权限模型 |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] AITrans 运行于 macOS | [INFERRED] 建立状态栏入口、进程驻留与单窗口恢复闭环 | [KNOWN] 关闭窗口不丢失快速入口，显式退出不被阻断 | [KNOWN] 仅 macOS 标准前台 App | [KNOWN] 端到端生命周期矩阵 | P1 |
| MAIN-1 | 启动注册 | [KNOWN] 原生启动完成且 `menuBarItemVisible` 无值或为 true | [INFERRED] controller 幂等创建一个强引用 `NSStatusItem`，加载 bundled template icon 并注册 click action | [KNOWN] 系统可展示一个 AITrans 状态项 | [KNOWN] 系统空间不足不视为应用可控制的失败 | [KNOWN] default/enable/repeat/image/accessibility XCTest | P1 |
| MAIN-2 | 关闭驻留 | [KNOWN] 用户关闭最后主窗口 | [INFERRED] `applicationShouldTerminateAfterLastWindowClosed` 返回 false；复用 Nib 的 `releasedWhenClosed=NO` | [KNOWN] 窗口从屏幕移除但对象和进程保留 | [KNOWN] 不把 Quit 事件改成 hide | [KNOWN] delegate 与窗口 identity tests、进程检查 | P1 |
| MAIN-3 | 左键切换 | [KNOWN] 状态栏 leftMouseUp 到达，窗口可能 closed/hidden/minimized/visible/key/non-key | [KNOWN] visible、key 且非 minimized 时关闭；closed/hidden/minimized/non-key 时由统一 presenter 解最小化、激活 App、显示并聚焦现有窗口 | [KNOWN] 唯一窗口在 closed 与 visible/key 之间切换，状态内容保持 | [KNOWN] 不创建窗口、不自动提交翻译；不能只信任 Flutter window 的陈旧 `isVisible` | [KNOWN] visible/key→closed→visible、stale-visible/non-key tests 与窗口 count | P1 |
| MAIN-4 | Dock/快捷键/Service | [KNOWN] Dock reopen、快捷键或外部翻译请求到达 | [KNOWN] Dock 与原生 Service 继续 always-show；Dart `⌘⇧T` 保持 toggle，在打开分支先读取选区/剪贴板并只填入输入框；状态栏单独使用 presenter 的 show/close toggle | [KNOWN] 各入口保持用户确认的独立语义，快捷键预填不自动翻译 | [KNOWN] 关闭分支不读取文本；读取失败不阻止打开；状态栏 toggle 不得改变 Dock/Service 的 always-show | [KNOWN] reopen/service/hotkey regression tests | P1 |
| MAIN-5 | 偏好切换 | [KNOWN] 用户在 macOS 设置页切换状态栏可见性 | [INFERRED] typed bridge 调用原生 controller；成功后写独立 `UserDefaults`，UI 反映真实值 | [KNOWN] enable 创建一个 item，disable 移除 item，重启恢复 | [KNOWN] 不写 Provider/credential Hive state；移动端不展示 | [KNOWN] native persistence、channel 与 widget tests | P1 |
| MAIN-6 | 显式退出 | [KNOWN] AppKit 收到 `terminate:`、quit AppleEvent 或右键菜单“退出” | [KNOWN] 保持标准终止流程，右键菜单直接调用 AppKit terminate | [KNOWN] 进程和状态项结束，Hive lock 释放 | [KNOWN] 不经 Flutter bridge | [KNOWN] controller XCTest、真实菜单点击与 debug script 重启 | P1 |
| MAIN-7 | 右键菜单与翻译输入 | [KNOWN] rightMouseUp 后用户选择“翻译、设置、退出”之一 | [KNOWN] 菜单最小宽度 180pt，退出前有原生分割线，翻译显示独立菜单快捷键 `⌘T`，动作使用语义图标；翻译按需请求 Accessibility，选区优先、剪贴板回退并复用既有外部翻译；设置经 typed app command 打开现有 SettingsSheet；退出原生终止 | [KNOWN] 仅对应动作发生 | [KNOWN] `⌘T` 不替换现有 `⌘⇧T` 全局窗口 toggle；macOS 10.15 无系统符号时退化为原生文本菜单；不持续监听、不记录文本、不创建第二套 UI；无文本不发 AI 请求 | [KNOWN] Runner presentation/resolver/coordinator/menu tests、Dart bridge/widget tests、宿主菜单/设置/退出 | P1 |
| BRANCH-1 | 重复事件 | [KNOWN] 重复启动回调、重复 enable/disable 或快速点击 | [INFERRED] 所有操作按目标状态幂等，UI action 在主线程串行 | [KNOWN] 至多一个 item 和一个主窗口 | [KNOWN] 不跨进程共享原生对象 | [KNOWN] factory count、remove count、window identity | P1 |
| BRANCH-2 | 图标或空间异常 | [KNOWN] template image 为 nil，或系统不展示状态项 | [INFERRED] image nil 时用短文本和 accessibility label 回退；保留 Dock 与快捷键 | [KNOWN] 应用可操作且不崩溃 | [KNOWN] 不声称突破系统菜单栏空间限制 | [KNOWN] failure injection 与手工视觉检查 | P2 |
| BRANCH-3 | channel/偏好失败 | [KNOWN] channel 未附着、方法未知或偏好写入未完成 | [INFERRED] 返回 typed failure；设置开关回退并显示通用错误 | [KNOWN] 不产生 UI/原生状态漂移 | [KNOWN] 不输出本地路径或原始异常 | [KNOWN] fake channel/store failure tests | P1 |
| BRANCH-4 | 非 macOS | [KNOWN] iOS 或 Android 启动/打开设置 | [KNOWN] platform service 返回 unsupported，UI 不渲染开关 | [KNOWN] 现有移动端流程不变 | [KNOWN] 不加载 AppKit 资源或 channel | [KNOWN] Dart platform guard tests | P2 |

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| [KNOWN] Feature ID 是否为 `macos-menu-bar-residency`？ | [KNOWN] 已关闭 | [KNOWN] 是 | [KNOWN] 用户确认 | [KNOWN] 需求目录已固定 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] 首次启动与关闭窗口行为是什么？ | [KNOWN] 已关闭 | [KNOWN] 首次显示主窗口；关闭只移除窗口并保持进程 | [KNOWN] 用户确认 | [KNOWN] 生命周期与验收已固定 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] 是否保留 Dock，状态栏是否可隐藏？ | [KNOWN] 已关闭 | [KNOWN] 保留 Dock；默认显示状态栏项目并提供隐藏开关 | [KNOWN] 用户确认 | [KNOWN] 排除 agent app，并保留恢复后路 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] 使用原生 AppKit 还是 Flutter tray 插件？ | [KNOWN] 已关闭 | [KNOWN] 原生 AppKit | [KNOWN] 用户确认 | [KNOWN] 不新增托盘依赖，原生测试边界确定 | [KNOWN] 用户于 2026-07-16 确认 |
| [KNOWN] 版本、责任人与最终品牌 glyph | [KNOWN] 待负责人确认 | [KNOWN] 不阻断 TDD；先使用最小 template glyph，品牌资源后续可替换 | [KNOWN] 不改变功能接口、风险等级或测试主干 | [KNOWN] 只影响排期和视觉定稿 | [KNOWN] 项目/设计负责人 |

## 6.1 本轮问题

[KNOWN] 不适用；无会改变范围、P1 风险、实现路径或 TDD 准入的未关闭问题。

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| [KNOWN] `AppDelegate` | [INFERRED] 反转最后窗口关闭行为，初始化状态项，处理 Dock reopen，并保持 Quit | [KNOWN] 当前源码与用户确认 | [KNOWN] 已确认 | P1 |
| [KNOWN] `MainWindowPresenter` 或等价 seam | [INFERRED] 集中 closed/hidden/minimized/visible 的恢复，供 status item、Dock 和 Service 复用 | [KNOWN] 当前 `AppDelegate` 与 Dart hotkey 存在分散 show/focus | [INFERRED] 设计树已收敛 | P1 |
| [KNOWN] `MenuBarStatusItemController` 或等价 seam | [INFERRED] 强引用、幂等 create/remove、template icon、action 和回退 | [KNOWN] Apple `NSStatusItem` 契约 | [INFERRED] 设计树已收敛 | P1 |
| [KNOWN] `UserDefaults` macOS 偏好 | [INFERRED] 独立布尔键，缺省 true，成功变更后持久化 | [KNOWN] 用户确认状态栏开关；Provider state 与该偏好无关 | [INFERRED] 设计树已收敛 | P1 |
| [KNOWN] platform channel | [INFERRED] `getVisibility`/`setVisibility` typed boundary，只传布尔值和通用错误 | [KNOWN] `MainFlutterWindow` 已有 Flutter messenger 装配模式 | [INFERRED] 设计树已收敛 | P1 |
| [KNOWN] 设置页 | [INFERRED] macOS 专属开关即时应用，loading 期间防重入，失败回退 | [KNOWN] 用户确认设置入口；当前设置页已有异步状态模式 | [INFERRED] 设计树已收敛 | P1 |
| [KNOWN] template icon asset | [INFERRED] bundled monochrome 资源兼容 macOS 10.15，含 tooltip/accessibility | [KNOWN] 当前 deployment target 10.15，现有 asset catalog 无状态栏资源 | [INFERRED] 设计树已收敛 | P2 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] 关闭窗口语义改变后进程意外不退出或意外退出 | P1 | [KNOWN] 当前 delegate 返回 true；用户要求返回相反行为 | [KNOWN] 分开测试 close 与 terminate，并运行正常退出/重启脚本 | [KNOWN] 研发/测试负责人 |
| [INFERRED] 多入口各自实现 show/focus 会产生状态漂移 | P1 | [KNOWN] Service 在 Swift 激活窗口，快捷键在 Dart show/focus | [INFERRED] 提取原生 presenter，并保护快捷键既有 toggle 语义 | [KNOWN] 研发负责人 |
| [INFERRED] 状态项未被强引用或重复创建会消失/重复 | P1 | [KNOWN] `NSStatusItem` 是原生生命周期对象，当前没有管理器 | [INFERRED] controller 持有唯一 item，注入 factory 做 call-count tests | [KNOWN] 研发负责人 |
| [INFERRED] 偏好 UI 与原生状态不一致 | P1 | [KNOWN] 需要异步 Flutter-to-native 更新 | [INFERRED] 原生成功后提交 UI；失败回退并验证重启恢复 | [KNOWN] 研发/测试负责人 |
| [KNOWN] 调试脚本无法正常关闭常驻进程 | P1 | [KNOWN] 脚本发送 AppleEvent quit 并等待 Hive 锁释放 | [KNOWN] 禁止拦截 terminate；以脚本完整通过为停止条件 | [KNOWN] 研发负责人 |
| [KNOWN] 状态栏空间不可保证 | P2 | [KNOWN] Apple 明确说明 status item 不保证始终可用 | [KNOWN] 保留 Dock/快捷键并提供偏好；验收不声称系统绝对可见 | [KNOWN] 产品负责人 |
| [KNOWN] 新资源只支持较新 macOS | P2 | [KNOWN] deployment target 是 10.15 | [KNOWN] 使用 bundled template image，不把高版本 SF Symbol 作为唯一资源 | [KNOWN] 研发/设计负责人 |

[COMPUTED] P1 阻断状态：无；所有 P1 风险都已映射到 S1-S4 的失败测试、回归验证或停止条件。

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. 原生 AppKit 状态项 + 独立原生偏好 | [KNOWN] 已确认 | [INFERRED] AppDelegate 注册 item，presenter 恢复窗口，Flutter 设置经 channel 读写偏好 | [INFERRED] nil icon、重复注册、Dock reopen、bridge failure 都在原生边界处理 | [KNOWN] 仅 macOS；保留 Dock；不新增菜单 | [INFERRED] 无新依赖，直接符合 AppKit 生命周期，Runner XCTest 可覆盖 | [INFERRED] 需要维护 Swift channel 和 asset | [KNOWN] 用户已选择本方案 |
| B. `tray_manager` 等 Flutter 插件 | [KNOWN] 已排除 | [INFERRED] Dart 初始化托盘并处理 click/window_manager | [INFERRED] 插件 readiness、版本兼容和 Dart/native 生命周期需额外协调 | [KNOWN] 仍仅 macOS，但引入跨平台依赖 | [INFERRED] Dart API 集中 | [INFERRED] 新依赖和插件生命周期扩大影响面 | [KNOWN] 用户确认原生 AppKit；项目当前无该依赖 |
| C. `LSUIElement` 菜单栏 agent app | [KNOWN] 已排除 | [INFERRED] 隐藏 Dock，只通过状态栏管理窗口 | [INFERRED] 状态项隐藏时需另设恢复路径 | [KNOWN] 改变应用身份、激活和发行行为 | [INFERRED] 更接近纯菜单栏应用 | [INFERRED] 与保留 Dock 冲突，回滚和验收面更大 | [KNOWN] 用户明确保留 Dock |

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | [COMPUTED] `TDD_INPUT_READY` |
| 下一步路由 | [KNOWN] `SDD-HICODE-tdd` |
| 未覆盖设计树节点 | [KNOWN] 无；品牌 glyph 最终定稿为 P3 非阻断视觉替换，不隐藏在功能任务中 |
| 最终 TDD 任务清单状态 | [KNOWN] 可执行 |

### 最终 TDD 切片

| 任务 | 目标与设计树节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点与测试重点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|---|---|
| S1 原生状态项、偏好与窗口 presenter | [KNOWN] 建立可注入、幂等的纯原生边界；MAIN-1、MAIN-3、MAIN-5、BRANCH-1/2 | [KNOWN] 用户确认、AppKit 契约、macOS 10.15 baseline | [KNOWN] 内：默认 true 的独立偏好、create/remove、强引用、template icon/短文本回退、closed/hidden/minimized 恢复和 visible 关闭；外：Flutter UI、AppDelegate wiring、菜单 | [INFERRED] `AppDelegate.swift` 或独立 Swift 类型、`Assets.xcassets/`, `RunnerTests.swift` | [KNOWN] 先写默认值、显式 false、重复 enable/disable、nil icon、click callback、visible→closed→visible 和单 window identity RED tests | [KNOWN] Runner XCTest focused scheme | [KNOWN] 若必须移除 Dock、提高 deployment target、增加托盘依赖或创建第二窗口，则返回 Scope |
| S2 AppDelegate 生命周期与既有入口整合 | [KNOWN] 关闭窗口后驻留，并让 status click、Dock reopen 和 Service 使用单窗口 presenter；MAIN-2/3/4/6、BRANCH-1 | [KNOWN] S1 seam；当前 Service bridge、Nib `releasedWhenClosed=NO`、Quit wiring 和 debug script | [KNOWN] 内：启动注册、最后窗口不退出、Dock reopen、Service presenter、标准 terminate 回归；外：改变 hotkey toggle、右键菜单具体命令（由 S5 承担） | [INFERRED] `AppDelegate.swift`, `MainFlutterWindow.swift`, `MainMenu.xib` inspection, `RunnerTests.swift` | [KNOWN] 先写 delegate false、reopen、Service 单窗口、重复注册和 terminate 不被转换为 hide tests | [KNOWN] Runner XCTest + macOS debug build | [KNOWN] AppleEvent quit 不能终止、Service 重复交付或 window identity 无法保持时停止并返回 Scope |
| S3 Flutter bridge 与 macOS 设置开关 | [KNOWN] 让用户即时读取和设置状态栏可见性，失败不制造假状态；MAIN-5、BRANCH-3/4 | [KNOWN] S1 controller；现有 Flutter messenger 与 SettingsSheet 异步模式 | [KNOWN] 内：typed get/set、macOS platform guard、loading、防重入、失败回退/通用错误；外：Provider save transaction、移动端 UI、凭证 schema | [INFERRED] `MainFlutterWindow.swift`, `lib/core/platform/`, `settings_page.dart`, platform/widget tests | [KNOWN] 先写 get true/false、set、unknown method、channel failure、macOS-only rendering、toggle success/failure rollback RED tests | [KNOWN] focused Flutter tests + Runner XCTest + `flutter analyze` | [KNOWN] 若必须把偏好写入 encrypted Provider state、向移动端暴露无效开关或泄露原生异常，则返回 Scope |
| S4 全量回归与 macOS 宿主验证 | [KNOWN] 验证完整常驻闭环且不破坏既有功能；ROOT、所有 MAIN/BRANCH | [KNOWN] S1-S3 完成；项目调试启动规则 | [KNOWN] 内：format/analyze/test、Runner XCTest、debug build/install/start、关闭后存活、status/Dock/hotkey/Service、Cmd+Q/AppleEvent quit、重启偏好；外：发布签名、登录启动、移动真机常驻 | [KNOWN] `lib/`, `test/`, `macos/`, `scripts/run_macos_debug.sh`, TDD report | [KNOWN] 自动化先行，再用非敏感固定文本手工验证可见状态、关闭、恢复、显式退出和单进程 | [KNOWN] `dart format --output=none --set-exit-if-changed lib test`; `flutter analyze`; `flutter test`; Runner XCTest；`zsh scripts/run_macos_debug.sh` | [KNOWN] 出现多进程、Hive 锁争用、Quit 失效、Service 注册丢失、状态项重复或主窗口无法恢复时停止，不得宣称本地验证通过 |
| S5 右键命令、Accessibility、菜单样式与 Flutter 导航 | [KNOWN] 实现 MAIN-7、MAIN-8、BRANCH-5 | [KNOWN] 用户 2026-07-17 确认；Apple Accessibility/App Sandbox 边界；既有 ExternalTranslationBridge 与 `⌘⇧T` 全局快捷键 | [KNOWN] 内：rightMouseUp 菜单、180pt 最小宽度、退出分割线、快捷键标注、语义系统图标及 10.15 降级、选区优先/剪贴板回退、共享 sequence、showTranslation/showSettings typed command、原生 terminate、移除 macOS Sandbox entitlement；外：持续监听、模拟 Cmd+C、第二套 UI、真实用户剪贴板宿主测试 | [KNOWN] `AppDelegate.swift`, entitlements, `MainFlutterWindow.swift`, `lib/core/platform/`, `lib/features/app/`, AppShell/CommandBar, Runner/Flutter tests | [KNOWN] 先写 menu presentation/resolver/coordinator/sequence/buffer RED，再写 Dart bridge/navigation/focus RED | [KNOWN] Runner XCTest、聚焦 Flutter tests、全量回归、codesign entitlement、仅 AITrans AX 宿主菜单 | [KNOWN] 若用户不同意关闭 Sandbox、退出依赖 Flutter、文本被记录或无文本仍发 AI 请求，则停止并返回 Scope |
| S6 `⌘⇧T` 打开时预填选区 | [KNOWN] 扩展 MAIN-4 | [KNOWN] 用户 2026-07-17 确认；既有 AX resolver、external translation bridge 和 Dart hotkey toggle | [KNOWN] 内：打开分支在 show/focus 前读取选区、选区不可用时回退剪贴板、以 `macosHotkey` typed source 填入输入框且不自动翻译、关闭分支不读取、读取失败仍打开；外：持续监听、模拟 Cmd+C、改变菜单“翻译”的自动翻译语义 | [KNOWN] `hotkey_service.dart`, native bridge, external translation source/coordinator, Runner/Flutter tests | [KNOWN] 先写打开顺序/关闭不读/失败降级 RED，再写 typed source 只填入 RED | [KNOWN] 聚焦 Flutter tests、Runner XCTest、全量回归、规定 Debug 脚本 | [KNOWN] 若必须先激活窗口再读选区、快捷键自动发 Provider 请求或读取失败阻止打开，则停止 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1/BRANCH-1 | [KNOWN] 缺省、开启、关闭、重复开启/关闭、重复注册 | unit/idempotency | P1 | [KNOWN] 隔离 `UserDefaults` suite 和 fake status-item factory | S1 |
| MAIN-2/MAIN-6 | [KNOWN] close last window 与 terminate/quit 分离 | lifecycle | P1 | [KNOWN] fake delegate inputs 与真实 debug process | S2/S4 |
| MAIN-3 | [KNOWN] closed、hidden、minimized、non-key 点击恢复，visible/key 点击关闭并可再次恢复 | state matrix | P1 | [KNOWN] fake window/application ports；真实 macOS 三击矩阵 | S1/S4 |
| MAIN-4 | [KNOWN] Dock reopen、hotkey toggle、Service 唤起 | integration/regression | P1 | [KNOWN] 现有非敏感 Service fixture | S2/S4 |
| MAIN-5/BRANCH-3 | [KNOWN] bridge get/set、快速重复点击、native failure、UI rollback、重启恢复 | unit/widget/persistence | P1 | [KNOWN] fake channel/store，无密钥或用户文本 | S3/S4 |
| BRANCH-2 | [KNOWN] icon 存在、nil image 回退、tooltip/accessibility、系统空间限制说明 | resource/accessibility | P2 | [KNOWN] bundled template asset 与 fake image loader | S1/S4 |
| BRANCH-4 | [KNOWN] iOS/Android 不显示开关且不调用 macOS channel | platform guard | P2 | [KNOWN] fake platform capability | S3 |
| MAIN-7/MAIN-8/BRANCH-5 | [KNOWN] 右键三项、选区/剪贴板优先级、拒绝权限、无文本、应用命令导航、原生退出 | unit/widget/host | P1 | [KNOWN] 合成文本和 fake readers；宿主不读取真实剪贴板 | S5 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | [INFERRED] 是；正式文件待负责人确认 |
| 判断理由 | [INFERRED] 状态栏代码仍可局部替换，但为跨应用 Accessibility 移除 App Sandbox 会改变发行与安全边界，达到 ADR 候选门槛 |
| 涉及决策点 | [KNOWN] 用户已确认请求辅助功能权限；正式 ADR 和 Mac App Store/站外发行选择仍需项目负责人确认并写入长期上下文 |

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 建议更新 | [INFERRED] 增加“macOS 菜单栏驻留”“显式退出”“主窗口恢复”术语和 MBR-001 至 MBR-006 | [KNOWN] 负责人未指派，按项目规则暂不正式写入长期上下文 | [KNOWN] 待负责人确认 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 建议更新 | [INFERRED] Feature 索引候选 `macos-menu-bar-residency`，Scope 状态 `TDD_INPUT_READY`；平台模块增加状态栏/窗口 presenter 计划 | [KNOWN] 负责人未指派，按项目规则暂不正式更新 | [KNOWN] 待负责人确认 |
| `docs/adr/` | [KNOWN] 建议新增 | [INFERRED] 记录“为状态栏选区读取关闭 macOS App Sandbox”的安全与发行取舍 | [KNOWN] 本轮用户授权实现，但负责人身份未确认，按项目规则仅记录建议、不创建正式 ADR | [KNOWN] 待负责人确认 |

## 14. 文档处理清单

| 文档 | 处理结果 |
|---|---|
| `docs/features/macos-menu-bar-residency/feature_context.md` | [KNOWN] 已创建；记录确认范围、规则、设计树、影响面和非阻断缺口 |
| `docs/features/macos-menu-bar-residency/scope-plan.md` | [KNOWN] 已创建；结论为 `TDD_INPUT_READY`，包含 S1-S5 最终任务 |
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 未更新；等待负责人确认长期术语和规则 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 未更新；等待负责人确认 Feature 索引 |
| `docs/adr/` | [KNOWN] 未创建 ADR |
