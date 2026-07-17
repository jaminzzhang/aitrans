# TDD 与辅助编码报告

[KNOWN] 本报告记录 `macos-menu-bar-residency` 的本地实现、RED-GREEN-REFACTOR 证据和宿主验证；不代表合并、发布或生产操作许可。

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [COMPUTED] `LOCAL_VERIFIED` |
| 最高风险等级 | [COMPUTED] P1 |
| 模式 | [KNOWN] 本地修改 |
| 置信度 | [INFERRED] HIGH（95%）；核心行为已由 30 个 Runner XCTest、120 个 Flutter tests、静态分析和真实 Debug 构建/启动验证；自动化只使用合成选区，跨应用选区兼容性仍取决于目标应用暴露的 Accessibility 属性 |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 测试目标 | [KNOWN] 保持既有左键窗口 toggle；右键展示“翻译、设置、退出”；菜单翻译选区优先、剪贴板回退并复用既有主窗口翻译流程；`⌘⇧T` 打开时先读取并只预填输入；设置打开既有 SettingsSheet；退出终止进程；拒绝 Accessibility 时安全降级 |
| 测试范围 | [KNOWN] `NSStatusItem` 左右键分流、菜单命令、Accessibility/clipboard resolver、共享翻译序列、原生与 Dart MethodChannel、Flutter 导航/焦点、entitlements、现有生命周期/Service 回归、Debug 安装和真实宿主菜单 |
| 不覆盖范围 | [KNOWN] iOS/Android 常驻、`LSUIElement`、隐藏 Dock、登录启动、状态栏 popover/历史/第二套 UI、多窗口、Mac App Store 提交和生产环境；真实宿主不读取或发送用户当前剪贴板 |

## 3. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| T01 | [KNOWN] 偏好缺省为 true，显式 false 可持久化 | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T02 | [KNOWN] 状态项重复 enable/disable 幂等，nil 图标回退为 `A`，点击触发窗口 toggle | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T03 | [KNOWN] visible/key 窗口点击后关闭、再次点击恢复；stale-visible/non-key 与最小化窗口恢复并前置；窗口缺失时不激活、不创建第二窗口 | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T04 | [KNOWN] 关闭最后窗口不退出，Dock reopen 调用统一恢复器 | [KNOWN] Runner lifecycle | [KNOWN] P1 | [KNOWN] P1 |
| T05 | [KNOWN] 原生 `getVisibility`/`setVisibility` 只接受和返回 Bool，非法参数与未知方法走类型化分支 | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T06 | [KNOWN] Dart channel 校验原生返回值，unsupported 平台不调用 macOS channel | [KNOWN] Dart unit | [KNOWN] P1 | [KNOWN] P2 |
| T07 | [KNOWN] 设置开关成功后提交 UI，失败保持旧值并显示通用错误，unsupported 平台不渲染 | [KNOWN] Widget | [KNOWN] P1 | [KNOWN] P1 |
| T08 | [KNOWN] App bundle 含 `MenuBarIcon` template 矢量资源，运行时仍保留文本回退 | [KNOWN] Runner resource | [KNOWN] P2 | [KNOWN] P2 |
| T09 | [KNOWN] `⌘W` 后进程和状态项仍存在；真实状态栏首次点击展示窗口、再次点击关闭、第三次点击恢复；Quit 后进程消失 | [KNOWN] macOS host | [KNOWN] P1 | [KNOWN] P1 |
| T10 | [KNOWN] 现有 Flutter、Service 注册、单进程和启动存活行为无回归 | [KNOWN] regression/integration | [KNOWN] P1 | [KNOWN] P1 |
| T11 | [KNOWN] 右键菜单顺序固定为“翻译、设置、退出”，左键仍只触发窗口 toggle | [KNOWN] Runner unit + macOS host | [KNOWN] P1 | [KNOWN] P1 |
| T12 | [KNOWN] 非空选区优先于剪贴板；空白/无权限选区回退剪贴板；两者为空只打开翻译输入，不发请求 | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T13 | [KNOWN] Service 与菜单翻译共享单调 sequence，避免交错请求被 Dart 去重门误判 | [KNOWN] Runner unit | [KNOWN] P1 | [KNOWN] P1 |
| T14 | [KNOWN] showTranslation 关闭设置并聚焦输入；showSettings 打开既有设置；bridge 冷启动只保留最新命令 | [KNOWN] Dart/Widget + Runner | [KNOWN] P1 | [KNOWN] P1 |
| T15 | [KNOWN] 右键“退出”不依赖 Flutter channel，真实点击后进程消失 | [KNOWN] Runner + macOS host | [KNOWN] P1 | [KNOWN] P1 |

## 4. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| GWT-01 | [KNOWN] 隔离的 `UserDefaults` suite 没有状态栏键 | [KNOWN] controller 应用已存偏好 | [KNOWN] 只创建一个强引用状态项，并把缺省值视为 true |
| GWT-02 | [KNOWN] 状态项已存在或已移除 | [KNOWN] 重复设置相同目标值 | [KNOWN] 不重复创建、不重复移除，持久化值与目标一致 |
| GWT-03 | [KNOWN] 唯一主窗口已关闭、隐藏、最小化、后台非 key 或当前 visible/key | [KNOWN] 状态栏 action 到达 | [KNOWN] visible、key 且非 minimized 时 `close()`；否则通过稳定 registry 复用同一 `MainFlutterWindow`，解除最小化、激活并 `makeKeyAndOrderFront` |
| GWT-03B | [KNOWN] Dock reopen 或 Service 请求到达 | [KNOWN] 主窗口处于任意非终止状态 | [KNOWN] 继续复用 `showMainWindow()` always-show，不受状态栏 toggle 影响 |
| GWT-04 | [KNOWN] 用户关闭最后主窗口 | [KNOWN] AppKit 询问是否终止应用 | [KNOWN] delegate 返回 false，进程继续运行；标准 Quit 不被转换成 hide |
| GWT-05 | [KNOWN] macOS 设置页已读到真实状态 | [KNOWN] 用户切换开关 | [KNOWN] 原生确认后更新 UI；channel 失败时保持旧值并显示 `无法更新状态栏设置，请重试` |
| GWT-06 | [KNOWN] 平台不支持菜单栏偏好 | [KNOWN] 打开设置或调用 service | [KNOWN] UI 不渲染开关，service 抛 `UnsupportedError` 且 channel 调用次数为 0 |
| GWT-07 | [KNOWN] Debug App 已由规定脚本启动 | [KNOWN] 发送 `⌘W`，再连续三次点击 AITrans status menu | [KNOWN] 第一次恢复并聚焦，第二次关闭但进程常驻，第三次恢复；状态项和窗口对象始终各至多一个 |
| GWT-08 | [KNOWN] 状态栏存在且收到 rightMouseUp | [KNOWN] 菜单展开 | [KNOWN] 只显示“翻译、设置、退出”，不执行左键 toggle |
| GWT-09 | [KNOWN] 用户选择“翻译”且目标应用有非空 AXSelectedText | [KNOWN] resolver 执行 | [KNOWN] 不读剪贴板；显示主窗口，把 trim 后文本送入既有外部翻译校验和 AI 流程 |
| GWT-10 | [KNOWN] Accessibility 未授权、无选区或选区为空 | [KNOWN] 用户选择“翻译” | [KNOWN] 回退普通剪贴板；剪贴板也为空时只显示并聚焦翻译输入 |
| GWT-11 | [KNOWN] 用户选择“设置”或“退出” | [KNOWN] 菜单命令执行 | [KNOWN] 设置显示唯一主窗口中的 SettingsSheet；退出直接终止 AppKit 进程 |
| GWT-12 | [KNOWN] 用户右键展开状态栏菜单 | [KNOWN] 原生菜单完成布局 | [KNOWN] 最小宽度为 180pt；退出前有分割线；翻译显示独立菜单快捷键 `⌘T`；macOS 11 及以上为三项显示语义系统图标，10.15 保留可操作的文本菜单 |
| GWT-13 | [KNOWN] AITrans 窗口隐藏且其他应用存在当前选区 | [KNOWN] 用户按 `⌘⇧T` | [KNOWN] 先读取选区，再显示并聚焦主窗口；文本展示在输入框且不自动翻译 |
| GWT-14 | [KNOWN] AITrans 窗口已显示，或选区读取失败 | [KNOWN] 用户按 `⌘⇧T` | [KNOWN] 显示时只隐藏且不读取；读取失败时仍显示并聚焦窗口 |

## 5. Mock、数据与断言

| 项 | 规则 | 风险 |
|---|---|---|
| [KNOWN] 偏好数据 | [KNOWN] 每个 XCTest 使用独立随机 suite，结束后删除持久域 | [KNOWN] 避免污染真实用户偏好，P1 |
| [KNOWN] 状态项 fake | [KNOWN] 记录创建、配置、remove 和 action；不依赖系统菜单栏空间 | [KNOWN] 系统视觉由真实宿主的 status menu 数量/描述补证，P2 |
| [KNOWN] 窗口 fake | [KNOWN] 记录 miniaturize、visible、key 和 activation；窗口缺失单独断言 | [KNOWN] 真实 AppKit 激活由宿主 AX 状态补证，P1 |
| [KNOWN] MethodChannel fake | [KNOWN] 偏好 channel 只传 Bool/null；application command 只传固定 showTranslation/showSettings；外部翻译沿既有 typed payload 传测试文本 | [KNOWN] 不传凭证或原始异常；非法命令拒绝，P1 |
| [KNOWN] 设置 service fake | [KNOWN] 成功记录目标值；失败只抛合成异常，UI 断言通用错误 | [KNOWN] 防止测试依赖真实插件或泄露原生细节，P1 |
| [KNOWN] 宿主数据 | [KNOWN] 只读取 AITrans 自身的进程存在性、窗口 AX 状态、状态栏项数量和描述 | [KNOWN] 未读取其他应用内容或敏感数据，P1 |
| [KNOWN] Accessibility/clipboard fake | [KNOWN] resolver 由闭包注入合成 selected/clipboard 文本，断言优先级和零冗余读取 | [KNOWN] 自动化不访问真实用户选区或剪贴板，P1 |

## 6. RED-GREEN-REFACTOR 记录

| 步骤 | 行为 | 文件 | 结果 |
|---|---|---|---|
| RG-01 RED | [KNOWN] 先写偏好、状态项和窗口 presenter 测试 | [KNOWN] `macos/RunnerTests/RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：缺失 `MenuBarStatusItem`、`MainWindowPresentable` |
| RG-01 GREEN | [KNOWN] 加入独立偏好、幂等 status controller、AppKit adapter 和 presenter | [KNOWN] `macos/Runner/AppDelegate.swift` | [KNOWN] 13 个当时已有 Runner XCTest 全部通过 |
| RG-02 RED | [KNOWN] 先写 close-last-window 与 Dock reopen 测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：缺失 `ApplicationLifecycleController` |
| RG-02 GREEN | [KNOWN] 统一 presenter，接入 AppDelegate 启动/关闭/Dock/Service | [KNOWN] `AppDelegate.swift` | [KNOWN] Runner XCTest 退出 0 |
| RG-03 RED | [KNOWN] 先写 Dart typed channel 与 platform guard 测试 | [KNOWN] `menu_bar_preference_service_test.dart` | [KNOWN] `flutter test` 退出 1：生产文件与类型缺失 |
| RG-03 GREEN | [KNOWN] 加入 `MethodChannelMenuBarPreferenceService` | [KNOWN] `menu_bar_preference_service.dart` | [KNOWN] 4 个聚焦测试全部通过 |
| RG-04 RED | [KNOWN] 先写 Swift get/set/invalid/unknown method 测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：缺失 handler/error 类型 |
| RG-04 GREEN | [KNOWN] 加入 Swift method handler、bridge 并在 Flutter window 装配 | [KNOWN] `AppDelegate.swift`, `MainFlutterWindow.swift` | [KNOWN] Runner XCTest 退出 0 |
| RG-04 TEST FIX | [KNOWN] 首次 GREEN 重跑发现 fake 的 setter 不更新 getter，导致合成状态自相矛盾 | [KNOWN] `RunnerTests.swift` | [KNOWN] 修正 fake 状态传播；未放宽生产断言，随后通过 |
| RG-05 RED | [KNOWN] 先写设置开关成功、失败回退和 unsupported 渲染测试 | [KNOWN] `settings_sheet_test.dart` | [KNOWN] 两个目标场景因开关不存在失败；unsupported 和 8 个既有场景通过 |
| RG-05 GREEN | [KNOWN] 加入异步读取、原生确认后提交、失败提示和 macOS-only UI | [KNOWN] `settings_page.dart` | [KNOWN] 首次重跑发现 `Switch` 缺少 `Material` 祖先；最小包裹后 10 个设置测试全部通过 |
| RG-06 RED | [KNOWN] 先写 bundle icon 资源测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] 仅 `testBundleContainsTheMenuBarTemplateIcon` 失败，`xcodebuild` 退出 65 |
| RG-06 GREEN | [KNOWN] 加入 bundled SVG template imageset | [KNOWN] `MenuBarIcon.imageset/` | [KNOWN] 当时 18 个 Runner XCTest 全部可编译执行，`xcodebuild` 退出 0 |
| RG-07 SCOPE CHANGE | [KNOWN] 用户在提交前把状态栏行为从 always-show 改为 show/close toggle | [KNOWN] `feature_context.md`, `scope-plan.md` | [KNOWN] Dock、快捷键和 Service 语义不变；只修改状态栏 action |
| RG-07 RED | [KNOWN] 先写 visible→closed→visible presenter 测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：`MainWindowPresenter` 缺失 `toggleMainWindow` |
| RG-07 GREEN | [KNOWN] 增加 `isVisible`/`close()` 窗口能力并让状态栏调用 toggle | [KNOWN] `AppDelegate.swift` | [KNOWN] 聚焦测试退出 0；随后 19 个 Runner XCTest 全部通过 |
| RG-07 REFACTOR | [KNOWN] show/toggle 复用同一私有 show 路径，`onOpenMainWindow` 重命名为 `onToggleMainWindow` | [KNOWN] `AppDelegate.swift`, `RunnerTests.swift` | [KNOWN] 全部 Runner XCTest 重跑退出 0 |
| RG-08 HOST FAILURE | [KNOWN] 真实第二次点击关闭后，第三次点击无法恢复 | [KNOWN] Debug App / `AppDelegate.swift` | [KNOWN] `close()` 后窗口从 `NSApp.windows` 移除，shared provider 返回 nil；原 fake 直接持有窗口而未覆盖该宿主边界 |
| RG-08 RED | [KNOWN] 先写 registry 关闭后仍提供同一窗口的测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] 初次 `xcodebuild test` 被 test manager worker 卡住并中断，不计 RED；`build-for-testing` 随后退出 65，唯一目标错误是缺失 `MainWindowRegistry` |
| RG-08 GREEN | [KNOWN] 增加进程级强引用 registry，并在 `MainFlutterWindow.awakeFromNib` 注册唯一窗口 | [KNOWN] `AppDelegate.swift`, `MainFlutterWindow.swift` | [KNOWN] registry 聚焦测试和当时全部 20 个 Runner XCTest 通过 |
| RG-09 HOST FAILURE | [KNOWN] registry 修复后，`⌘W` 关闭窗口仍可能保留陈旧 `isVisible=true`，第一次 status click 被误判为 close | [KNOWN] Debug App / `AppDelegate.swift` | [KNOWN] 宿主第一击未恢复，AX 窗口数为 0 |
| RG-09 RED | [KNOWN] 先写 stale-visible/non-key 必须执行 show 的测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] 目标断言失败，`xcodebuild` 退出 65 |
| RG-09 GREEN | [KNOWN] close 判据增加 `isKeyWindow`，其余状态统一 show | [KNOWN] `AppDelegate.swift`, `RunnerTests.swift` | [KNOWN] 聚焦测试和最终 21 个 Runner XCTest 全部通过 |
| RG-09 HOST GREEN | [KNOWN] 规定 Debug 脚本后执行 `⌘W` 与三次真实 status click | [KNOWN] stable Debug App | [KNOWN] 第一次展示为 frontmost/main/not-minimized；第二次关闭但进程与一个状态项仍在；第三次恢复为 frontmost/main/not-minimized |
| RG-10 SCOPE CHANGE | [KNOWN] 用户追加右键“翻译、设置、退出”，并确认选区优先、剪贴板回退及请求辅助功能权限 | [KNOWN] `feature_context.md`, `scope-plan.md` | [KNOWN] Apple 文档确认跨应用 Accessibility 与 App Sandbox 不兼容；用户授权关闭 Sandbox |
| RG-10 RED | [KNOWN] 先写 menu command、resolver、coordinator、共享 sequence 和 command buffer 测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：缺失 `MenuBarCommand` 等目标类型 |
| RG-10 GREEN | [KNOWN] 加入左右键分流、三项原生菜单、AXSelectedText/clipboard resolver、共享 request factory、应用命令 bridge 和原生 terminate | [KNOWN] `AppDelegate.swift`, `MainFlutterWindow.swift`, entitlements | [KNOWN] 26/26 Runner XCTest 通过 |
| RG-11 RED | [KNOWN] 先写 Dart application command bridge 与 AppShell 导航/焦点 tests | [KNOWN] `application_command_platform_bridge_test.dart`, `widget_test.dart` | [KNOWN] `flutter test` 退出 1：目标文件、类型和 provider 不存在 |
| RG-11 GREEN | [KNOWN] 加入 typed bridge/provider、翻译焦点 request、SettingsSheet 复用和通用 bridge 错误 | [KNOWN] `lib/core/platform/`, `lib/features/app/`, `app.dart`, `command_bar.dart` | [KNOWN] 初次聚焦 11/11、全量 113/113、analyze 零问题 |
| RG-11 HOST GREEN | [KNOWN] 用规定 Debug 脚本安装后发送真实右键，读取 AITrans 自身 AX 菜单并点击设置/退出 | [KNOWN] stable Debug App | [KNOWN] 菜单文本为“翻译、设置、退出”；设置使主窗口 main/non-minimized；退出后进程不存在；最终重启单进程存活 |
| RG-12 REVIEW RED | [KNOWN] 提交前发现重复相同命令会复用 canonical const event，先补 distinct-event test | [KNOWN] `application_command_platform_bridge_test.dart` | [KNOWN] 新测试失败：`identical(first, second)` 为 true |
| RG-12 GREEN | [KNOWN] decoder 每次创建独立事件，确保连续“翻译”或“设置”都能通知 Riverpod | [KNOWN] `application_command_platform_bridge.dart` | [KNOWN] 聚焦 12/12、最终全量 114/114 通过 |
| RG-13 RED | [KNOWN] 先写菜单 3 倍宽度、退出分割线、翻译快捷键和三项语义图标展示测试 | [KNOWN] `RunnerTests.swift` | [KNOWN] `xcodebuild` 退出 65：缺失 `MenuBarMenuPresentation` 及 command 展示属性；首次沙箱内命令只产生 Xcode 环境错误，不计 RED |
| RG-13 GREEN | [KNOWN] 使用原生 `NSMenu.minimumWidth=240`、原生 separator、独立 `⌘T` key equivalent 和 macOS 11+ SF Symbols；10.15 自动降级为文本菜单 | [KNOWN] `AppDelegate.swift` | [KNOWN] 聚焦 2/2、最终 28/28 Runner XCTest、114/114 Flutter tests 和 analyze 零问题 |
| RG-13 REVIEW RED | [KNOWN] 复核发现 `⌘⇧T` 已用于全局显示/隐藏窗口，先把菜单测试改为独立 `⌘T` | [KNOWN] `RunnerTests.swift` | [KNOWN] 聚焦测试失败：实际 modifier 为 Shift+Command，期望 Command |
| RG-13 REVIEW GREEN | [KNOWN] 移除菜单快捷键的 Shift modifier，保留全局窗口快捷键原语义 | [KNOWN] `AppDelegate.swift` | [KNOWN] 完整 28/28 Runner XCTest 通过 |
| RG-13 HOST GREEN | [KNOWN] 用规定脚本安装后，仅对 AITrans 状态项发送真实右键并读取自身 AX 菜单 | [KNOWN] stable Debug App | [KNOWN] 最终菜单 AX 名称为“翻译、设置、分割线、退出”，实际尺寸为 240×87；翻译快捷键属性为 `T`、modifier 0（Command）；进程单实例运行 |
| RG-14 RED | [KNOWN] 用户把最终菜单宽度从 240pt 调整为 180pt，先修改 presentation 宽度断言 | [KNOWN] `RunnerTests.swift` | [KNOWN] 聚焦测试失败：实际 240，期望 180 |
| RG-14 GREEN | [KNOWN] 把 `NSMenu.minimumWidth` 展示契约改为固定 180pt，并移除已失效的三倍宽度常量 | [KNOWN] `AppDelegate.swift` | [KNOWN] 完整 28/28 Runner XCTest 通过 |
| RG-14 HOST PARTIAL | [KNOWN] 用规定脚本安装最终构建并向 AITrans 状态项发送真实右键 | [KNOWN] stable Debug App | [KNOWN] AX 读取到“翻译、设置、分割线、退出”，但本轮系统对展开菜单返回尺寸 0×0，因此不把宿主像素尺寸计为通过；180pt 由原生 presentation 测试证明 |
| RG-15 RED | [KNOWN] 先写快捷键打开顺序、关闭不读取、读取失败仍打开及原生 capture method 测试 | [KNOWN] `hotkey_service_test.dart`, `RunnerTests.swift` | [KNOWN] Dart 缺少 `HotkeyWindowController`，Swift 缺少 `HotkeySelectionCaptureMethodHandler`，两侧编译失败 |
| RG-15 GREEN | [KNOWN] 增加 Dart toggle coordinator、Dart→Swift capture channel，并复用 AX selected-text/clipboard resolver；读取发生在 show/focus 前 | [KNOWN] `hotkey_service.dart`, `AppDelegate.swift`, `MainFlutterWindow.swift` | [KNOWN] Dart 3/3 与 Runner 聚焦 2/2 通过 |
| RG-16 RED | [KNOWN] 先写 `macosHotkey` 来源只填入而不自动翻译测试 | [KNOWN] external translation bridge/coordinator tests、`RunnerTests.swift` | [KNOWN] Dart 缺少 `macosHotkey` enum；Swift request 缺少 source，编译失败 |
| RG-16 GREEN | [KNOWN] 外部请求增加 typed source；Service/菜单保持自动翻译，快捷键来源只更新输入 | [KNOWN] Dart/Swift external translation boundary | [KNOWN] 相关 Dart 12/12 与 Runner 聚焦测试通过 |
| REFACTOR | [KNOWN] Service、Dock 和 status action 复用 `MainWindowPresenter.shared`；偏好保持独立于 Provider/credential schema | [KNOWN] Swift/Dart 平台边界 | [KNOWN] `flutter analyze` 与全量回归通过 |

## 7. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| [KNOWN] `macos/Runner/AppDelegate.swift` | [KNOWN] 修改 | [KNOWN] 增加状态栏偏好/controller、原生 channel handler/bridge、窗口 presenter、Dock/close 生命周期；状态栏使用 show/close toggle，Service/Dock 继续复用 always-show presenter |
| [KNOWN] `macos/Runner/MainFlutterWindow.swift` | [KNOWN] 修改 | [KNOWN] 注册唯一主窗口，并装配菜单栏偏好、外部翻译和 application-command MethodChannel |
| [KNOWN] `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` | [KNOWN] 修改 | [KNOWN] 移除 App Sandbox entitlement，使用户授权后可读取其他应用 Accessibility 选区 |
| [KNOWN] `macos/Runner/Assets.xcassets/MenuBarIcon.imageset/Contents.json` | [KNOWN] 新增 | [KNOWN] 声明矢量保留与 template rendering intent |
| [KNOWN] `macos/Runner/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.svg` | [KNOWN] 新增 | [KNOWN] 18×18 单色状态栏 glyph |
| [KNOWN] `lib/core/platform/menu_bar_preference_service.dart` | [KNOWN] 新增 | [KNOWN] Dart typed service、macOS capability guard 和 Riverpod provider |
| [KNOWN] `lib/features/settings/ui/settings_page.dart` | [KNOWN] 修改 | [KNOWN] 增加 macOS 状态栏显示开关、loading 防重入和通用错误回退 |
| [KNOWN] `macos/RunnerTests/RunnerTests.swift` | [KNOWN] 修改 | [KNOWN] 增加菜单展示、resolver、共享 sequence 和 command buffer 回归；全文件共 28 个测试 |
| [KNOWN] `lib/core/platform/application_command_platform_bridge.dart` | [KNOWN] 新增 | [KNOWN] 只接受 showTranslation/showSettings 的 typed native-to-Dart bridge |
| [KNOWN] `lib/features/app/logic/application_command_coordinator.dart` | [KNOWN] 新增 | [KNOWN] macOS-only bridge 生命周期、事件和失败状态 |
| [KNOWN] `lib/features/translate/logic/translation_input_focus.dart` | [KNOWN] 新增 | [KNOWN] 菜单翻译请求聚焦既有 CommandBar |
| [KNOWN] `lib/app.dart`, `command_bar.dart` | [KNOWN] 修改 | [KNOWN] 消费应用命令、复用 SettingsSheet、关闭旧弹层并聚焦输入 |
| [KNOWN] `test/core/platform/application_command_platform_bridge_test.dart`, `test/widget_test.dart` | [KNOWN] 新增/修改 | [KNOWN] 增加 4 个 typed bridge 与 2 个 AppShell 行为测试 |
| [KNOWN] `test/core/platform/menu_bar_preference_service_test.dart` | [KNOWN] 新增 | [KNOWN] 增加 4 个 typed channel/platform guard 测试 |
| [KNOWN] `test/features/settings/ui/settings_sheet_test.dart` | [KNOWN] 修改 | [KNOWN] 增加 3 个设置开关 Widget 测试并注入 fake service |
| [KNOWN] `test/features/settings/settings_page_test.dart` | [KNOWN] 修改 | [KNOWN] 注入 unsupported fake，避免测试依赖真实 macOS channel |
| [KNOWN] `lib/core/platform/hotkey_service.dart`, `MainFlutterWindow.swift` | [KNOWN] 修改 | [KNOWN] 快捷键打开分支在窗口激活前调用 typed native capture channel |
| [KNOWN] `external_translation_request.dart`, `external_translation_platform_bridge.dart`, `external_translation_coordinator.dart` | [KNOWN] 修改 | [KNOWN] 增加 `macosHotkey` typed source，并与 Service 的自动翻译语义分离 |
| [KNOWN] `test/core/platform/hotkey_service_test.dart` | [KNOWN] 新增 | [KNOWN] 覆盖打开顺序、关闭不读取和读取失败仍打开 |
| [KNOWN] `docs/features/macos-menu-bar-residency/tdd-report.md` | [KNOWN] 新增 | [KNOWN] 记录本次 TDD 证据、命令、风险和上下文建议 |

## 8. 受限命令执行记录

| 命令 | 范围 | 是否执行 | 结果 | 未执行原因 |
|---|---|---|---|---|
| [KNOWN] `xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | [KNOWN] Runner XCTest RED/GREEN 与最终回归 | [KNOWN] 是，多轮 | [KNOWN] RED 均命中目标缺失行为；最终 30 个测试退出 0 | [KNOWN] 不适用 |
| [KNOWN] `flutter test test/core/platform/menu_bar_preference_service_test.dart` | [KNOWN] Dart channel 聚焦测试 | [KNOWN] 是 | [KNOWN] 最终 4/4 通过 | [KNOWN] 不适用 |
| [KNOWN] `flutter test test/features/settings/ui/settings_sheet_test.dart` | [KNOWN] 设置页聚焦测试 | [KNOWN] 是 | [KNOWN] 最终 10/10 通过 | [KNOWN] 不适用 |
| [KNOWN] `flutter analyze` | [KNOWN] 全项目静态分析 | [KNOWN] 是 | [KNOWN] 退出 0，No issues found | [KNOWN] 不适用 |
| [KNOWN] `flutter test`，含 localhost NO_PROXY | [KNOWN] 全项目 Flutter 回归 | [KNOWN] 是 | [KNOWN] 120/120 通过 | [KNOWN] 不适用 |
| [KNOWN] `dart format --output=none --set-exit-if-changed lib test` | [KNOWN] 全项目格式基线 | [KNOWN] 是 | [KNOWN] 退出 1：本次文件修正后，仍有两个无关既有文件 `lib/features/translate/ui/translate_page.dart`、`lib/main.dart` 不符合 formatter | [KNOWN] 按规则保留用户既有改动，不扩大修改范围 |
| [KNOWN] 对本次 7 个 Dart 文件执行 `dart format` | [KNOWN] 本次变更格式 | [KNOWN] 是 | [KNOWN] 退出 0 | [KNOWN] 不适用 |
| [KNOWN] `git diff --check` | [KNOWN] 变更空白检查 | [KNOWN] 是 | [KNOWN] 退出 0 | [KNOWN] 不适用 |
| [KNOWN] `zsh scripts/run_macos_debug.sh` | [KNOWN] 规定的关闭、构建、稳定安装、Service 注册、启动、单进程和存活检查 | [KNOWN] 历史八次加本轮重建 | [KNOWN] 2026-07-17 本轮退出 0，启动单实例 PID 34453 | [KNOWN] 不读取真实用户选区，实际内容由用户手工验收 |
| [KNOWN] 仅针对 AITrans 的 AX/CGEvent 宿主验证 | [KNOWN] 真实右键菜单、尺寸、快捷键、设置和显式退出 | [KNOWN] 部分 | [KNOWN] 最终菜单项目为“翻译、设置、分割线、退出”；本轮 AX 尺寸返回 0×0，未取得 180px 宿主尺寸证据；既有 240pt 版本曾返回 240×87，设置/退出行为也已验证 | [KNOWN] 180pt 宽度由 Runner presentation 测试覆盖；真实“翻译”仍未点击，避免发送用户剪贴板 |
| [KNOWN] `codesign -d --entitlements` | [KNOWN] 已安装 Debug App 权限核对 | [KNOWN] 是 | [KNOWN] 签名中无 `com.apple.security.app-sandbox`，保留 Debug JIT/network/get-task-allow | [KNOWN] 不适用 |

## 9. 风险与待确认问题

| 问题 | 等级 | 影响 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] 全项目 formatter 基线仍有两个无关既有文件不通过 | [KNOWN] P3 | [KNOWN] 不影响本 Feature 编译、分析或测试，但全量格式命令仍返回非零 | [KNOWN] 由对应改动负责人单独格式化 `translate_page.dart` 与 `main.dart`，避免混入本需求 | [KNOWN] 对应文件负责人 |
| [KNOWN] Flutter 构建提示 `hotkey_manager_macos`、`screen_retriever_macos`、`window_manager` 尚不支持 Swift Package Manager | [KNOWN] P2 | [INFERRED] 当前构建成功，但未来 Flutter 版本可能把警告升级为错误 | [KNOWN] 单独跟踪插件升级，不在本 Feature 引入依赖迁移 | [KNOWN] macOS/依赖负责人 |
| [KNOWN] macOS 不能保证菜单栏空间不足时仍绘制每个 status item | [KNOWN] P2 | [KNOWN] 应用可持有状态项但用户可能看不到图标 | [KNOWN] 保留 Dock、快捷键和设置回退；不要把系统空间写成应用 SLA | [KNOWN] 产品负责人 |
| [KNOWN] 最终品牌 glyph 尚未由设计负责人确认 | [KNOWN] P3 | [KNOWN] 仅影响视觉定稿，不影响 action、accessibility、template 或回退路径 | [KNOWN] 后续只替换 `MenuBarIcon.svg` 并保留资源测试 | [KNOWN] 设计负责人 |
| [KNOWN] Quit AppleEvent 返回 `-128`，但进程随后消失 | [KNOWN] P3 | [KNOWN] 与既有 Debug 脚本的 `|| true` 加进程消失判据一致，不影响真实终止 | [KNOWN] 继续以进程退出和锁释放作为判据，不以 AppleScript reply 单独判失败 | [KNOWN] macOS 负责人 |
| [KNOWN] 关闭 App Sandbox 改变发行边界 | [KNOWN] P1 | [KNOWN] Apple 要求 Mac App Store 应用启用 Sandbox，而跨应用 Accessibility 读取与 Sandbox 不兼容 | [KNOWN] 发行前由负责人确认站外签名/notarization 路线，并补正式 ADR 与隐私说明 | [KNOWN] 产品/发行/安全负责人 |
| [KNOWN] 目标应用可能不暴露 `AXSelectedText` | [KNOWN] P2 | [KNOWN] 此时实现回退剪贴板，但不会模拟 Cmd+C，因此“当前选区”可能不可得 | [KNOWN] 保留 macOS Service 作为确定的选区入口；按目标应用兼容矩阵补测 | [KNOWN] macOS 负责人 |

## 10. 上下文更新建议

| 建议位置 | 类型 | 内容摘要 | 原因 |
|---|---|---|---|
| [KNOWN] `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 待负责人确认的术语/业务规则 | [INFERRED] 增加“macOS 状态栏驻留”“显式退出”“唯一主窗口恢复”，记录关闭窗口不等于退出 | [KNOWN] 该行为将影响后续所有 macOS 窗口需求，但项目规则要求负责人确认后才能写长期上下文 |
| [KNOWN] `docs/PROJ_CONTEXT.md` | [KNOWN] 待负责人确认的 Feature 索引 | [INFERRED] 将 `macos-menu-bar-residency` 从 `TDD_INPUT_READY` 更新为本地已验证，并登记 Swift/Dart 平台边界 | [KNOWN] 避免后续重复实现状态栏或把偏好误写入 Provider schema |
| [KNOWN] `docs/adr/` | [KNOWN] 建议负责人确认后新增 | [INFERRED] 记录“为跨应用选区读取关闭 App Sandbox”的安全、隐私和 Mac App Store 发行取舍 | [KNOWN] 该边界已超出普通可局部替换 UI 决策，不能继续沿用“无需 ADR”的旧结论 |
