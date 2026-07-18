# Mobile Platform Adaptation TDD 报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | `PARTIAL_VERIFICATION` |
| 最高风险等级 | P1 |
| 模式 | 受控实现（完整留痕） |
| 一句话依据 | Android Debug、iOS 26.5 Simulator 构建启动、Dynamic Island 视觉检查和 124 项全量测试已通过；因原 lock 间接依赖与本机 Flutter 解析环境不完全一致，保留部分验证结论 |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 测试目标 | 验证 iPhone/Android 的顶部安全区、320px 布局、初始焦点、触控目标、全屏设置、软键盘滚动、macOS UI 隔离、平台显示名和 Android Release 联网权限 |
| 测试范围 | `AppShell`、翻译 UI、设置 UI、Android Manifest、iOS Info.plist、全量 Flutter 回归、Android Debug 构建、iOS Simulator 构建探测 |
| 不覆盖范围 | 真机系统栏/输入法矩阵、极端大字体、iOS Share Extension、Android PROCESS_TEXT 接收入口、局域网 Ollama、商店签名与发布 |

## 3. 公开接口与可观察行为

| 公开入口 | 可观察行为 | 不测试的实现细节 |
|---|---|---|
| `AppShell` | iOS/Android 无 macOS 拖拽标题区；320px 主操作可见且无 overflow | 私有 Widget 拆分与条件表达式 |
| 设置齿轮 | 移动端打开安全区内全屏设置；不显示 macOS 快捷键；关闭按钮至少 48px | 路由类名与内部动画帧 |
| 软件键盘 + 设置滚动 | 300px bottom inset 下列表仍可滚动并访问版本尾部 | ScrollController 内部位置 |
| Android 安装包配置 | 主 Manifest 含 INTERNET，应用名为 AITrans | Gradle 合并内部顺序 |
| iOS Bundle 配置 | `CFBundleDisplayName` 为 AITrans | Xcode 工程内部生成步骤 |

## 4. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| MPA-T0 | Dynamic Island/状态栏安全区与移动端初始不抢焦点 | Widget + Simulator | P0 | P1 |
| MPA-T1 | 320x568 iPhone 视口主操作可用且无 RenderFlex overflow | Widget | P0 | P1 |
| MPA-T2 | 390x844 手机设置全宽、无 macOS 快捷键、关闭按钮 48px | Widget | P0 | P1 |
| MPA-T3 | 390x700 + 300px 软键盘 inset 时设置可滚动 | Widget | P0 | P1 |
| MPA-T4 | Android 主 Manifest INTERNET + 双平台显示名 | Shell/static | P0 | P1 |
| MPA-T5 | 既有 AppShell、CommandBar、ResultDocument、Settings 行为不回退 | Flutter regression | P0 | P1 |
| MPA-T6 | Android Debug APK 与 iOS Simulator Debug 构建 | Build | P0 | P1 |

## 5. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| MPA-T0 | iOS 平台主题、59px 顶部安全区 | 渲染 AppShell | 输入栏位于安全区下方，TextField 初始不获取焦点 |
| MPA-T1 | iOS 平台主题、320x568 视口 | 渲染 AppShell | 输入、翻译、语言和设置可见；关键触控高度 >= 48；无异常 |
| MPA-T2 | iOS 平台主题、390x844 视口 | 点击设置 | surface 宽 390；不出现“快捷键/唤起隐藏窗口”；关闭按钮高度 >= 48 |
| MPA-T3 | 设置已打开 | viewInsets.bottom 变为 300 并拖动列表 | 版本尾部仍在 Widget 树中且无布局异常 |
| MPA-T4 | 仓库平台配置 | 执行静态脚本 | Android INTERNET、Android AITrans 与 iOS AITrans 全部命中 |
| MPA-T6 | 本机非生产工具链 | 执行 Debug 构建 | Android 生成 APK；iOS 成功或记录明确环境阻断 |

## 6. RED-GREEN-REFACTOR 记录

| 步骤 | 行为 | 文件 | 结果 |
|---|---|---|---|
| RED-1 | Android 主 Manifest 必须具备 Release INTERNET | `test/platform/mobile_platform_config_test.sh` | 失败：`Android main manifest must grant INTERNET to release builds.` |
| GREEN-1 | 增加 INTERNET 并统一移动端产品名 | Android Manifest、iOS Info.plist | 静态配置测试通过 |
| RED-2 | 320px 主界面不得 overflow | `test/widget_test.dart` | 首跑失败：底部 RenderFlex 向右溢出 0.560px |
| GREEN-2 | 移动端底栏收紧横向留白，主要控件 48px | `app.dart`, `command_bar.dart`, tokens | 320px 用例通过 |
| REFACTOR-2 | UI 统一从 `ThemeData.platform` 读取平台，避免全局测试平台污染 | App/translate/settings UI | 新增 3 项移动端用例通过；生产默认平台行为不变 |
| RED-3 | 移动设置全宽、隐藏 macOS 文案、键盘下可滚动 | `test/widget_test.dart` | 修改前固定 Dialog/快捷键实现不满足目标；首轮新增用例与 RED-2 同批运行 |
| GREEN-3 | 手机使用 fullscreenDialog；SettingsSheet 响应安全区、键盘 inset 和全屏尺寸 | `app.dart`, `settings_page.dart` | 三项移动端用例全部通过 |
| REFACTOR-3 | 全屏路由退场测试改为固定 500ms，避免 Loading 动画导致 `pumpAndSettle` 永不稳定 | `test/widget_test.dart` | 路由回归测试通过且保留“设置已关闭”断言 |
| RED-4 | Simulator 启动后输入栏不得侵入 Dynamic Island | `test/widget_test.dart` + Simulator 截图 | Widget RED：TextField 顶边 16.5px，小于 59px 安全区；截图复现遮挡与自动键盘 |
| GREEN-4 | 手机 AppShell 增加顶部 SafeArea，移动端启动不自动抢焦点 | `app.dart`, `command_bar.dart` | 新用例通过；iOS 26.5 iPhone 17 Pro 截图确认输入栏避开 Dynamic Island 且键盘未自动弹出 |

## 7. 验证命令与真实结果

| 命令 | 结果 |
|---|---|
| `sh test/platform/mobile_platform_config_test.sh` | PASS |
| `flutter test --no-pub test/widget_test.dart ... settings_sheet_test.dart` | 39 项受影响 UI 测试通过 |
| `env NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test --no-pub` | 124 项全量测试通过 |
| `dart format --output=none --set-exit-if-changed lib test` | 66 个文件格式通过 |
| `flutter analyze --no-pub` | 仅 1 个任务前既存 info：`lib/shared/widgets/state_view.dart:74 use_null_aware_elements`；本次修改无新增分析问题 |
| `flutter build apk --debug --no-pub` | PASS；生成 `build/app/outputs/flutter-apk/app-debug.apk`（约 142MB） |
| `flutter run -d 92DA17CE-4FAF-4DE5-AD47-62BA2661BFD3 --debug --no-pub --no-resident` | PASS；在 iOS 26.5 iPhone 17 Pro Simulator 构建、安装并启动，最终运行 PID 92293 |

## 8. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/app.dart` | 修改 | 平台标题隔离、移动底栏、移动设置全屏路由、触控目标 |
| `lib/shared/theme/app_tokens.dart` | 修改 | compact breakpoint、48px touch target、平台分类 extension |
| `lib/features/translate/ui/translate_page.dart` | 修改 | 移动端水平留白 |
| `lib/features/translate/ui/command_bar.dart` | 修改 | 320px 命令条与移动触控/图标策略 |
| `lib/features/translate/ui/result_document.dart` | 修改 | 移动端结果文档留白 |
| `lib/features/settings/ui/settings_page.dart` | 修改 | 全屏尺寸、安全区、键盘、滚动、移动文案与触控 |
| `android/app/src/main/AndroidManifest.xml` | 修改 | INTERNET 与 AITrans 显示名 |
| `ios/Runner/Info.plist` | 修改 | AITrans 显示名 |
| `test/widget_test.dart` | 修改 | 4 项移动端行为测试、安全区模拟与路由等待适配 |
| `test/platform/mobile_platform_config_test.sh` | 新增 | 双平台原生配置静态断言 |
| `docs/features/mobile-platform-adaptation/` | 新增 | Scope、上下文与 TDD 报告 |

## 9. 受限命令与环境处理

| 事项 | 处理 | 结果 |
|---|---|---|
| pub.dev TLS | 主站握手失败；使用可访问镜像恢复本地依赖索引 | 依赖可用于测试；镜像引发的 lockfile/生成文件变化已全部恢复，未纳入任务 diff |
| 依赖图 | 当前 Flutter 3.38.5 对部分原 lock 间接版本重解析 | 测试使用相同直接依赖但部分间接版本不同；保留为 P1 验证限制 |
| iOS Simulator | 用户安装后系统可用 iOS 26.2/26.5 runtime | iOS 26.5 iPhone 17 Pro 完成首次迁移、构建、安装、启动与截图验证 |
| Android SDK | 构建工具按 Flutter/Gradle 请求安装 Platform 35 与 CMake 3.22.1 | Android Debug 构建通过 |

## 10. 风险与待确认问题

| 问题 | 等级 | 影响 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| iPhone 真机尚未运行 | P2 | Simulator 不能完全替代真实设备输入法、性能和系统栏行为 | 在至少一台刘海屏 iPhone 真机复核键盘、安全区和 Provider 网络请求 | 测试/研发负责人 |
| 验证依赖图与原 lock 的部分间接版本不同 | P1 | 当前机器结果不能完全替代 CI 的 lockfile 验证 | 在与 lockfile 生成环境一致的 Flutter 工具链运行 `flutter pub get --enforce-lockfile`、全量测试和双平台构建 | 研发环境负责人 |
| 无 Android AVD | P2 | 未进行截图与系统栏视觉 QA | 建立 320/360/412px Android AVD 真机矩阵 | 测试负责人 |
| 极端大字体未覆盖 | P2 | 200% 字体可能需要额外换行策略 | 独立可访问性验收 | 产品/测试负责人 |

## 11. 上下文更新建议

| 建议位置 | 类型 | 内容摘要 | 原因 |
|---|---|---|---|
| `docs/PROJ_CONTEXT.md` Feature 索引 | 待负责人确认后更新 | `mobile-platform-adaptation` 状态 `PARTIAL_VERIFICATION`；Android Debug、iOS 26.5 Simulator 与 124 tests 通过 | 长期上下文按项目规则需负责人确认 |
| `docs/DOMAIN_KNOWLEDGE.md` | 不更新 | 本轮未新增稳定业务术语或业务规则 | 避免把 UI 实现策略写入领域事实 |
