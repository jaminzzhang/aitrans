# S1 TDD 实施报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `LOCAL_VERIFIED` |
| 最高风险等级 | [KNOWN] P1 |
| 模式 | [KNOWN] 受控实现；完整留痕路径 |
| worktree | [KNOWN] `/Users/jamin/Dev/aitrans-s1` |
| 分支 | [KNOWN] `codex/cross-app-selection-translate-s1` |
| 切片 | [KNOWN] S1 外部请求模型、配置与校验 |

## 2. 读取依据与输入缺口

| 材料 | 读取结果 | 关键输入 | 缺口 |
|---|---|---|---|
| `AGENTS.md`, `docs/rules/coding_rules.md` | [KNOWN] 已读取 | [KNOWN] typed boundary、尺寸校验、错误脱敏、测试先行、不得修改生成文件 | [KNOWN] 无 |
| `docs/features/cross-app-selection-translate/feature_context.md` | [KNOWN] 已读取 | [KNOWN] macOS Service、5,000 code points、trim、结构化拒绝 | [KNOWN] 无 |
| `docs/features/cross-app-selection-translate/scope-plan.md` | [KNOWN] 已读取 | [KNOWN] S1 范围、测试边界和停止条件 | [KNOWN] 无 |
| `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | [KNOWN] 已读取 | [KNOWN] 当前翻译边界、模块位置和既有风险 | [KNOWN] Feature 索引尚未由负责人确认更新，不阻断 S1 |

## 3. 测试目标与范围

| 项 | 内容 |
|---|---|
| 公开接口 | [KNOWN] `ExternalTranslationConfig`、`ExternalTranslationRequestValidator.validate`、accepted/rejected typed results |
| 可观察行为 | [KNOWN] 默认上限为 5,000；代码可注入正整数上限；trim 后空白、非正 sequence 和超长请求返回结构化拒绝；合法请求返回不可由调用方绕过校验构造的 typed request |
| 字符语义 | [KNOWN] 使用 Dart `String.runes` 计算 Unicode code points，不使用 UTF-16 code units 或 grapheme clusters |
| 不测试实现细节 | [KNOWN] 私有计数 helper、数字格式化 helper、类的内部拆分 |
| 本轮范围外 | [KNOWN] 手动输入框全局限额、Dart latest-wins coordinator、MethodChannel、macOS `NSServices`、窗口生命周期、AI Provider token 估算 |

## 4. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| S1-T1 | [KNOWN] 合法 macOS Service 请求被接受并去除边界空白 | tracer bullet | P1 | P1 |
| S1-T2 | [KNOWN] 默认配置为 5,000，非正配置抛出 `ArgumentError` | configuration | P1 | P1 |
| S1-T3 | [KNOWN] 非正 sequence 与 trim 后空白返回不同结构化原因 | boundary | P1 | P1 |
| S1-T4 | [KNOWN] 自定义上限在 N 接受、N+1 拒绝，并返回动态上限与用户文案 | boundary | P1 | P1 |
| S1-T5 | [KNOWN] 默认 4,999/5,000/5,001 边界行为与 `5,000` 文案 | boundary | P1 | P1 |
| S1-T6 | [KNOWN] 补充平面字符和 combining sequence 按 code points 计数 | Unicode | P1 | P1 |

## 5. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| S1-GWT-1 | [KNOWN] 默认配置和带边界空白的合法文本 | [KNOWN] sequence=1 的 macOS Service 请求通过 validator | [KNOWN] 返回 accepted，文本为 trim 后内容 |
| S1-GWT-2 | [KNOWN] maxCharacters 为 0 或负数 | [KNOWN] 创建配置 | [KNOWN] 抛出 `ArgumentError`，非法配置不进入 validator |
| S1-GWT-3 | [KNOWN] sequence<=0 或 trim 后空白 | [KNOWN] 校验请求 | [KNOWN] 分别返回 `invalidSequence` 或 `emptyText`，不返回 request |
| S1-GWT-4 | [KNOWN] 配置上限 N | [KNOWN] 校验 N 与 N+1 code points | [KNOWN] N accepted；N+1 `textTooLong`，包含 N 与动态文案 |
| S1-GWT-5 | [KNOWN] 默认上限和 5,001 code points | [KNOWN] 校验请求 | [KNOWN] 拒绝并返回“所选文本过长，请缩短至 5,000 字符以内” |
| S1-GWT-6 | [KNOWN] 两个补充平面字符 `😀😀` | [KNOWN] 在上限 2 下校验 | [KNOWN] accepted，证明未按 4 个 UTF-16 code units 计数 |

## 6. Mock、数据与断言

| 项 | 规则 | 风险 |
|---|---|---|
| 测试数据 | [KNOWN] 只使用人工字符串、emoji 和 combining sequence，不含真实用户文本 | NONE |
| Mock | [KNOWN] 无；S1 是纯 Dart 边界，无外部系统 | NONE |
| 断言 | [KNOWN] 只从公开 validator 入口断言 result 类型、reason、配置上限、用户文案和 accepted request 字段 | P1 |
| 性能边界 | [INFERRED] 计数在发现第 N+1 个 code point 时立即停止，不遍历剩余超长输入 | P2 |

## 7. RED-GREEN-REFACTOR 记录

| 轮次 | 阶段 | 行为与真实结果 | 文件 |
|---|---|---|---|
| 1 | RED | [COMPUTED] focused test 编译失败：配置、request、validator 和 accepted result 文件/类型不存在 | `test/core/platform/external_translation_request_test.dart` |
| 1 | GREEN | [COMPUTED] 添加最小配置、request、accepted result 和 trim validator 后，1 项 tracer test 通过 | `lib/core/config/external_translation_config.dart`, `lib/core/platform/external_translation_request.dart` |
| 2 | RED | [COMPUTED] 新测试编译失败：rejected result 与 rejection reason 尚不存在 | 同上 |
| 2 | GREEN | [COMPUTED] 增加正整数配置校验、sequence/empty/tooLong typed rejection 后，6 项 focused tests 通过 | 同上 |
| 3 | RED | [COMPUTED] 2 项行为失败：`😀😀` 被 UTF-16 双计数拒绝；文案实际为 `5000` 而不是 `5,000` | 同上 |
| 3 | GREEN | [COMPUTED] 改用 `String.runes` 的早停扫描并格式化配置值后，8 项 focused tests 通过 | 同上 |
| 3 | REFACTOR | [COMPUTED] request 与 result 构造器改为 library-private，调用方只能通过 validator 获得合法 request；重构后 8 项 focused tests、静态分析和 38 项全量测试通过 | 同上 |

## 8. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/core/config/external_translation_config.dart` | [KNOWN] 新增 | [KNOWN] 可注入正整数 `maxCharacters`，默认 5,000 |
| `lib/core/platform/external_translation_request.dart` | [KNOWN] 新增 | [KNOWN] typed source/request/result/rejection/validator 与 Unicode code point 校验 |
| `test/core/platform/external_translation_request_test.dart` | [KNOWN] 新增 | [KNOWN] 8 项公开行为测试 |
| `docs/features/cross-app-selection-translate/tdd-report.md` | [KNOWN] 新增 | [KNOWN] S1 完整 TDD 证据 |

## 9. 命令与结果

| 命令 | 范围 | 结果 |
|---|---|---|
| `flutter test test/core/platform/external_translation_request_test.dart` | RED 1 | [COMPUTED] 失败；目标类型不存在 |
| `flutter test test/core/platform/external_translation_request_test.dart` | 初次 GREEN 环境尝试 | [COMPUTED] 连续失败于本地回环 HTTP 连接中断，不是测试断言失败 |
| `env NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test test/core/platform/external_translation_request_test.dart` | 每轮 RED/GREEN 与最终 focused | [COMPUTED] RED 证据符合预期；最终 8/8 通过 |
| `dart format ...` | 3 个变更 Dart 文件 | [COMPUTED] 完成；最终无待格式化变更 |
| `flutter analyze` | 全项目 | [COMPUTED] `No issues found` |
| `env NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test` | 全项目 | [COMPUTED] 38/38 通过 |
| `git diff --check` | worktree diff | [COMPUTED] 命令通过；新增文件尚未跟踪，因此不单独作为新增文件空白校验证据 |
| `rg -n '[[:blank:]]+$' <S1 files>` | 4 个新增文件 | [COMPUTED] 无匹配，未发现行尾空白 |

## 10. 风险、待确认问题与下一步

| 项 | 等级 | 结论或动作 |
|---|---|---|
| grapheme cluster 与 code point 区别 | P2 | [KNOWN] Scope 明确选择 code points；combining sequence 可能视觉上是一个字形但计为多个 code points，这是已测试语义 |
| 配置接入 | P1 | [KNOWN] S1 只提供可注入配置和 validator；S2 必须从应用组合根注入并消费，不得在 UI 或 platform channel 复制 `5000` |
| 原生载荷类型 | P1 | [KNOWN] S3 负责 pasteboard 类型和多项载荷校验；S1 typed API 只接收 `String` |
| 待确认问题 | NONE | [KNOWN] S1 范围内无待确认问题 |
| 下一步 | [KNOWN] S2 Dart 外部请求协调与 UI 同步 | [KNOWN] 使用 S1 validator result；不得扩展手动输入框限额或直接让 UI 依赖 MethodChannel |

## 11. 文档状态

| 文档 | 状态 |
|---|---|
| `feature_context.md` | [KNOWN] 未修改；Scope 事实未变化 |
| `scope-plan.md` | [KNOWN] 未修改；S1 按既有切片执行 |
| `tdd-report.md` | [KNOWN] 已创建并记录真实 S1 证据 |
| `DOMAIN_KNOWLEDGE.md` | [KNOWN] 未修改；长期上下文仍等待负责人确认 |
| `PROJ_CONTEXT.md` | [KNOWN] 未修改；Feature 索引仍等待负责人确认 |

---

# S2 TDD 实施报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `LOCAL_VERIFIED` |
| 最高风险等级 | [KNOWN] P1 |
| 模式 | [KNOWN] 受控实现；完整留痕路径 |
| worktree | [KNOWN] `/Users/jamin/Dev/aitrans-s1` |
| 分支 | [KNOWN] `codex/cross-app-selection-translate-s1` |
| 切片 | [KNOWN] S2 Dart 外部请求协调、latest-wins 与输入框同步 |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 公开入口 | [KNOWN] `externalTranslationCoordinatorProvider` 与 `ExternalTranslationCoordinator.handle` |
| 合法请求 | [KNOWN] 覆盖 `inputTextProvider`，调用一次 `translateNow` 和一次 `loadContent`，发布 accepted 状态 |
| 幂等与顺序 | [KNOWN] 进程内只接受严格大于已处理最大值的正 sequence；重复和乱序请求发布 ignored 状态且无副作用 |
| 非法请求 | [KNOWN] 发布 typed rejected 状态；5,001 code points 不覆盖输入、不调用 AI，并返回配置生成的 `5,000` 文案 |
| UI 同步 | [KNOWN] `CommandBar` 从 `inputTextProvider` 同步 controller 与末尾光标；程序化同步不调用 `onTextChanged` |
| 旧结果保护 | [KNOWN] 既有 generation guard 同时覆盖旧缓存结果与旧流事件，晚到结果不能覆盖最新翻译 |
| 本轮范围外 | [KNOWN] MethodChannel、macOS `NSServices`、窗口激活、系统菜单注册与可见错误组件；这些属于 S3/S4 |

## 3. RED-GREEN-REFACTOR 记录

| 轮次 | 阶段 | 行为与真实结果 | 文件 |
|---|---|---|---|
| 1 | RED | [COMPUTED] focused test 编译失败：协调器文件、Provider 与 accepted 状态不存在 | `test/features/translate/external_translation_coordinator_test.dart` |
| 1 | GREEN | [COMPUTED] 添加最小协调器后，合法请求覆盖 trim 后输入并各调用一次翻译与辅助内容；1/1 通过 | `lib/features/translate/logic/external_translation_coordinator.dart` |
| 2 | RED | [COMPUTED] 新测试编译失败：ignored/rejected 状态及字段不存在 | 同上 |
| 2 | GREEN | [COMPUTED] 添加最大 sequence 门槛和 typed rejected/ignored 状态后，4/4 协调器测试通过 | 同上 |
| 3 | RED | [COMPUTED] widget 行为失败：外部更新 provider 后 TextField controller 仍为空 | `test/features/translate/ui/command_bar_test.dart` |
| 3 | GREEN | [COMPUTED] 增加差异化 controller 同步后，TextField 显示外部文本、光标置末尾、`onTextChanged` 调用为 0 | `lib/features/translate/ui/command_bar.dart` |
| 3 | REFACTOR | [COMPUTED] 超长协调测试改为默认 5,001 边界；补充旧流事件晚到测试；格式化后 focused 20/20、静态分析和全量 44/44 通过 | S1/S2 focused files |

## 4. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/features/translate/logic/external_translation_coordinator.dart` | [KNOWN] 新增 | [KNOWN] 配置/validator 组合、请求协调、sequence 门槛和 typed handling state |
| `lib/features/translate/ui/command_bar.dart` | [KNOWN] 修改 | [KNOWN] 外部输入状态同步到 TextEditingController，不触发手动输入回调 |
| `test/features/translate/external_translation_coordinator_test.dart` | [KNOWN] 新增 | [KNOWN] 合法、重复/乱序、5,001 超长和非法 sequence 行为测试 |
| `test/features/translate/ui/command_bar_test.dart` | [KNOWN] 修改 | [KNOWN] 外部输入同步与手动语义保护测试 |
| `test/features/translate/translate_controller_test.dart` | [KNOWN] 修改 | [KNOWN] 增加旧流事件晚到不覆盖最新结果测试 |
| `docs/features/cross-app-selection-translate/tdd-report.md` | [KNOWN] 修改 | [KNOWN] 追加 S2 完整 TDD 证据 |

## 5. 命令与结果

| 命令 | 范围 | 结果 |
|---|---|---|
| `flutter test test/features/translate/external_translation_coordinator_test.dart` | RED 1 | [COMPUTED] 编译失败；协调器接口不存在 |
| 同一 focused 命令 | GREEN 1 | [COMPUTED] 1/1 通过 |
| 同一 focused 命令 | RED 2 | [COMPUTED] 编译失败；ignored/rejected 状态不存在 |
| 同一 focused 命令 | GREEN 2 | [COMPUTED] 4/4 通过 |
| `flutter test test/features/translate/ui/command_bar_test.dart` | RED 3 | [COMPUTED] 4 项既有测试通过，新增外部同步断言失败，实际 controller 文本为空 |
| S1/S2 四个 focused test 文件 | 最终 focused | [COMPUTED] 20/20 通过 |
| `dart format ...` | 8 个 S1/S2 Dart 文件 | [COMPUTED] 完成；2 个文件被格式化，后续单文件格式化完成 |
| `flutter analyze` | 全项目 | [COMPUTED] `No issues found` |
| `flutter test` | 全项目 | [COMPUTED] 44/44 通过 |

## 6. 风险、停止条件与下一步

| 项 | 等级 | 结论或动作 |
|---|---|---|
| sequence 生命周期 | P1 | [KNOWN] 门槛仅存在于 coordinator 实例生命周期；S4 原生桥必须提供进程内单调递增正整数，不得复用旧 sequence |
| 非法正 sequence | P1 | [KNOWN] 一旦被处理即推进门槛，之后同 sequence 即使文本改变也被忽略，满足“同一请求最多处理一次” |
| 手动输入语义 | P1 | [KNOWN] 程序化 controller 写入不触发 `onChanged`；立即翻译只由 coordinator 显式调用一次 |
| 平台隔离 | NONE | [KNOWN] UI 与 coordinator 均未依赖 MethodChannel；S2 停止条件未触发 |
| 待确认问题 | NONE | [KNOWN] S2 范围内无待确认问题 |
| 下一步 | [KNOWN] S3 macOS `NSServices` 原生适配 | [KNOWN] 原生层校验 pasteboard 类型、提取文本并产生 sequence；不得复制 Dart 的业务限额判断 |

---

# S3-S5 TDD 实施报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `PARTIAL_VERIFICATION` |
| 最高风险等级 | [KNOWN] P1 |
| 已完成 | [KNOWN] S3 原生 Service、S4 冷/热启动 bridge 与窗口恢复、S5 自动化回归和宿主清单 |
| 未完成证据 | [KNOWN] Safari、Chrome、Books 实机矩阵尚未完成；最终 Debug App 在当前机器卡于 macOS App Sandbox 初始化，不能给出宿主兼容结论 |

## 2. RED-GREEN-REFACTOR 记录

| 轮次 | 阶段 | 真实结果 |
|---|---|---|
| S3-0 | 环境隔离 | [COMPUTED] 首次 XCTest 因 worktree 缺少 Pods/Flutter ephemeral 输入失败；UTF-8 locale 生成后恢复，不计为 RED |
| S3-1 | RED | [COMPUTED] 原生 build 发现 Service error 指针被 `catch error` 遮蔽，安全错误分支无法编译 |
| S3-1 | GREEN | [COMPUTED] 参数重命名后 macOS debug build 通过；7 个 Runner XCTest 通过 |
| S4-1 | RED | [COMPUTED] Dart bridge 错把返回 `void` 的 `setMethodCallHandler` 当作 Future，3 个 focused 文件编译失败 |
| S4-1 | GREEN | [COMPUTED] 修正 handler 生命周期后 focused 9/9 通过 |
| S4-2 | REFACTOR | [INFERRED] 发现 engine 创建与 Dart handler ready 之间的冷启动竞态；增加 Dart→native `ready` 握手，只在 handler 安装后冲刷最新 pending request |
| S4-2 | GREEN | [COMPUTED] ready handshake focused 10/10、Runner XCTest 和 macOS debug build 通过 |
| S5-1 | RED | [COMPUTED] Safari 选中公开测试文本后未出现 AITrans Service；同一菜单中的既有文本 Service 可见。AITrans 声明使用 `public.utf8-plain-text`，可工作的本机 Service 使用 `NSStringPboardType` |
| S5-1 | GREEN | [COMPUTED] 将 `NSSendTypes` 改为 `NSStringPboardType` 后，最终 bundle 声明检查通过，Launch Services 注册成功，`NSPerformService` 对公开测试文本返回 `true` |
| S5-2 | RED | [COMPUTED] 首次最终 `xcodebuild test` 虽 7/7 通过，但宿主启动日志出现 `unrecognized selector -[AppDelegate applicationDidFinishLaunching:]`；原因是调用了不存在的父类 delegate 实现 |
| S5-2 | GREEN | [COMPUTED] 删除该 `super.applicationDidFinishLaunching` 调用后，第二次 `xcodebuild test` exit 0 且不再出现 uncaught exception；新增 bundle Service 契约回归后 8 项 Runner XCTest 通过 |

## 3. 实现与验证

| 范围 | 结果 |
|---|---|
| Service 注册 | [KNOWN] 编译后 bundle 声明菜单、selector、`NSStringPboardType`、port 与 timeout；系统直接调用返回 `true` |
| 原生解析 | [KNOWN] 只接受恰好一个含纯文本表示的 pasteboard item；错误文案不含原文 |
| 生命周期 | [KNOWN] 代码与自动化测试覆盖 Service 请求激活应用、恢复首个主窗口和 Flutter ready 前只保留最新请求；最终签名 Debug App 的实机窗口验证被当前环境阻断 |
| 桥接 | [KNOWN] typed method payload 包含 sequence/source/text；非法 payload 返回安全 PlatformException |
| Dart 协调 | [KNOWN] sequence 门槛、latest-wins、输入覆盖、立即翻译、5,001 拒绝和旧流保护 |
| 用户错误 | [KNOWN] 超长与 bridge unavailable 均显示不含原生异常、路径或原文的安全 SnackBar |
| 静态分析 | [COMPUTED] `flutter analyze` 无问题 |
| Flutter 回归 | [COMPUTED] 全量测试命令通过；增加设置弹窗关闭回归后当前测试总数为 50 |
| 原生回归 | [COMPUTED] 最终 `xcodebuild test` exit 0；xcresult 记录 RunnerTests 共 8 项；修复后输出未再出现 AppDelegate uncaught exception |
| macOS 构建 | [COMPUTED] 最终 `flutter build macos --debug` 成功；编译后 plist 校验通过 |

## 4. 残余风险与下一步

| 风险 | 等级 | 状态 |
|---|---|---|
| Safari/Chrome/Books 是否展示 Service | P1 | [KNOWN] `BLOCKED_ENVIRONMENT`；Accessibility 已返回 `true`，但签名 Debug App 启动后无窗口，主线程采样持续停在 `_libsecinit_appsandbox` 等待 XPC；不能由 plist、`NSPerformService` 或单元测试推断宿主菜单结果 |
| Books 测试材料 | P1 | [KNOWN] 导入测试 EPUB 会修改用户 Books 资料库，需单独授权 |
| Service 系统缓存 | P2 | [COMMON] macOS 安装/升级后菜单发现受 Services 数据库刷新影响；实机矩阵需覆盖首次启动与升级后场景 |
| iOS/Android | NONE | [KNOWN] 明确不在本 Scope，未修改其平台入口 |
| GUI 隐私证据 | P1 | [KNOWN] 一次全屏截图越过隔离边界，已删除且不作为证据；Books 测试材料未导入并已删除 |

---

# S6 Services 稳定安装修复报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `PARTIAL_VERIFICATION` |
| 最高风险等级 | [KNOWN] P1 |
| 已完成 | [KNOWN] Debug App 稳定目录安装、LaunchServices 强制注册、系统 Service 启用、legacy/modern 文本类型声明、TextEdit 有效选区菜单验证、单实例启动与存活检查 |
| 未完成证据 | [KNOWN] Safari、Chrome 和 Books 的选中文本菜单仍需逐宿主现场验证 |

## 2. RED-GREEN 记录

| 轮次 | 阶段 | 真实结果 |
|---|---|---|
| S6-1 | RED | [COMPUTED] 当前 build 目录 bundle 可在旧 `pbs` 缓存中出现，但执行 `/System/Library/CoreServices/pbs -update` 后“使用 AITrans 翻译”从 live Services 数据库消失 |
| S6-1 | GREEN 尝试 | [COMPUTED] 将 bundle 安装到 `~/Applications/AITrans Debug.app`、强制注册并刷新后，live 数据库已保留该稳定路径；首版脚本因 `pbs -dump` 将中文转义为 Unicode 而误判失败 |
| S6-2 | GREEN | [COMPUTED] 将菜单名契约改由已安装 bundle 的 `Info.plist` 验证，live 数据库只验证稳定 `NSBundlePath`；完整脚本 exit 0，App 单一进程 PID 66789 启动并存活至少 2 秒 |
| S6-3 | INVALID PROBE | [COMPUTED] 首次 TextEdit 探针使用 `System Events` Command-A，但 `AXSelectedText` 为空；该结果没有形成真实文本选区，不作为 RED 证据 |
| S6-4 | RED | [COMPUTED] 系统设置中“使用 AITrans 翻译”复选框未选中；用户授权后启用，`NSServicesStatus` 写入 context menu 和 Services menu 启用状态 |
| S6-5 | RED | [COMPUTED] 通过 TextEdit `Edit → Select All` 建立有效公开文本选区后，旧 bundle 仍未显示 AITrans；同时 `NSPerformService` 返回 `true`，将故障收敛到宿主文本类型匹配 |
| S6-5 | GREEN | [COMPUTED] Runner XCTest 先以实际只有 `NSStringPboardType`、期望同时包含 `public.utf8-plain-text` 得到 1/8 失败；增加现代文本类型后 8/8 通过 |
| S6-6 | GREEN | [COMPUTED] 重新安装、注册并重启 TextEdit 后，有效公开文本选区的 Services 菜单从 12 项增至 30 项，明确包含“使用 AITrans 翻译” |

## 3. 修改与验证

| 文件或边界 | 结果 |
|---|---|
| `scripts/run_macos_debug.sh` | [KNOWN] 构建后使用 staging bundle 安装到稳定用户 Applications 目录，刷新并校验 Service，再启动 App |
| `AGENTS.md` | [KNOWN] macOS Debug 流程已改为稳定安装与 Service 注册流程 |
| `macos/Runner/Info.plist` | [KNOWN] `NSSendTypes` 同时声明 legacy `NSStringPboardType` 和 modern `public.utf8-plain-text` |
| `macos/RunnerTests/RunnerTests.swift` | [KNOWN] bundle 契约测试保护两种宿主文本类型 |
| Flutter 业务代码 | [KNOWN] 未修改 |
| Shell 静态检查 | [COMPUTED] `zsh -n scripts/run_macos_debug.sh` 通过 |
| Diff 空白检查 | [COMPUTED] `git diff --check` 通过 |
| 原生测试 | [COMPUTED] 最终 `xcodebuild test` exit 0，Runner XCTest 8/8 通过 |
| 完整启动检查 | [COMPUTED] `zsh scripts/run_macos_debug.sh` exit 0，输出 `AITrans debug build is running (PID 85396).` |

## 4. 残余风险

| 风险 | 等级 | 状态 |
|---|---|---|
| 宿主菜单缓存 | P1 | [COMMON] 已运行宿主可能缓存 Services 菜单；数据库 GREEN 不能替代 Safari、Chrome 和目标 App 的重新启动后现场验证 |
| 入口形态 | P1 | [KNOWN] 当前 Scope 是系统 Services/右键菜单入口，不是选中文本旁的自定义悬浮按钮 |
| 系统 Service 启用状态 | NONE | [COMPUTED] 用户已授权并启用；`NSServicesStatus` 明确记录 context menu 与 Services menu 均为 1 |
| Chrome 现场验证 | P1 | [KNOWN] Chrome 控制连接因运行时冲突不可用；应用菜单未显示文本 Service，但其辅助功能接口不暴露网页选区，Control-click 探针也无法可靠读取，因此不得判定通过或不支持 |

---

# S7 首次启动自动刷新 Services 注册报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `LOCAL_VERIFIED` |
| 最高风险等级 | [KNOWN] P1 |
| 已完成 | [KNOWN] App 首次启动安装 Service provider 后，通过公开 `NSUpdateDynamicServices()` API 主动刷新系统 Services 列表；同一进程重复注册幂等 |
| 边界 | [KNOWN] 系统是否启用 Service 仍由用户设置控制；实现不修改私有 `NSServicesStatus` 偏好 |

## 2. RED-GREEN-REFACTOR 记录

| 轮次 | 阶段 | 真实结果 |
|---|---|---|
| S7-0 | 环境隔离 | [COMPUTED] 沙箱内两次 `xcodebuild` 因 Xcode workspace/CoreSimulator 权限环境失败，不作为 RED |
| S7-1 | RED | [COMPUTED] 沙箱外定向 XCTest 编译失败，错误为 `cannot find 'MacOSServiceRegistration' in scope`，证明启动注册协调器尚不存在 |
| S7-1 | GREEN | [COMPUTED] 增加幂等注册协调器并接入 `applicationDidFinishLaunching` 后，定向 XCTest exit 0 |

## 3. 修改与验证

| 文件或边界 | 结果 |
|---|---|
| `macos/Runner/AppDelegate.swift` | [KNOWN] `MacOSServiceRegistration` 先设置 `NSApp.servicesProvider`，再调用 `NSUpdateDynamicServices()`，每进程只执行一次 |
| `macos/RunnerTests/RunnerTests.swift` | [KNOWN] 新增 provider 安装、动态刷新和重复调用幂等测试 |
| 定向原生测试 | [COMPUTED] `xcodebuild test -quiet ... -only-testing:RunnerTests/RunnerTests/testServiceRegistrationInstallsProviderAndRefreshesDynamicServicesOnlyOnce` exit 0 |
| 完整原生回归 | [COMPUTED] `xcodebuild test -quiet ...` exit 0 |
| 静态分析 | [COMPUTED] `flutter analyze` exit 0，输出 `No issues found!` |
| macOS 构建 | [COMPUTED] 沙箱内因 Flutter 全局 SDK cache 无写权限失败；获授权后 `flutter build macos --debug` exit 0 |

## 4. 残余风险

| 风险 | 等级 | 状态 |
|---|---|---|
| 首次启动前发现 | P2 | [COMMON] App 尚未运行时不能主动调用刷新 API；安装到 Applications 目录后的发现仍依赖 macOS Launch Services |
| 用户启用状态 | P1 | [KNOWN] Apple 公开机制不允许 App 保证替用户启用 Service；必要时仍需一次系统设置引导 |
| 宿主缓存 | P1 | [COMMON] 已运行宿主可能继续缓存 Services 菜单；升级后可能需要重启宿主 App |
