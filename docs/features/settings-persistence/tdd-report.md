# TDD 与辅助编码报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `PARTIAL_VERIFICATION` |
| 最高风险等级 | [KNOWN] P1 |
| 模式 | [KNOWN] 受控实现 |
| 一句话依据 | [KNOWN] 42 项测试、静态分析、macOS Debug 构建与启动通过；iOS/Android 构建受本机工具链阻断 |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 测试目标 | [KNOWN] 设置跨重启持久化、API Key 按 Provider 安全隔离、Draft 后提交、字段显式清除和失败回退 |
| 测试范围 | [KNOWN] Hive preferences、credential boundary、组合 repository、Riverpod 初始装配、settings widget、macOS plugin build/startup |
| 不覆盖范围 | [KNOWN] 真实 API Key、真实收费端点、签名后的 iOS/macOS Release、Android Java 17 构建、凭证云同步、生物识别、翻译缓存治理 |

## 3. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| S1-1 | [KNOWN] 重建 Hive store 后恢复 Provider、Base URL 和模型 | repository | P1 | P1 |
| S1-2 | [KNOWN] Hive 记录不包含 API Key 字段 | security | P1 | P1 |
| S1-3 | [KNOWN] 空覆盖值清除旧 Base URL/模型；损坏数据回退 Ollama | boundary | P1 | P1 |
| S2-1 | [KNOWN] OpenAI 与 Qwen 使用不同凭证键 | security | P1 | P1 |
| S2-2 | [KNOWN] 空凭证只删除当前 Provider；底层失败向上传播 | failure | P1 | P1 |
| S3-1 | [KNOWN] repository 组合当前偏好与对应 Provider 凭证 | repository | P1 | P1 |
| S3-2 | [KNOWN] 保存把凭证与偏好分仓；偏好失败向 UI 传播 | failure | P1 | P1 |
| S4-1 | [KNOWN] Provider 切换只修改 Draft，保存成功后更新全局状态 | widget/state | P1 | P1 |
| S4-2 | [KNOWN] 保存失败与测试连接不污染生效配置 | widget/failure | P1 | P1 |
| S5-1 | [KNOWN] macOS 安全存储插件编译、注册并完成启动读取 | platform | P1 | P1 |

## 4. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| GWT-1 | [KNOWN] 临时 Hive box 为空 | [KNOWN] 保存 Qwen 偏好并重建 store | [KNOWN] 恢复相同非敏感设置且记录无 API Key |
| GWT-2 | [KNOWN] 两个 Provider 有虚构凭证 | [KNOWN] 删除 OpenAI 凭证 | [KNOWN] Qwen 凭证保持不变 |
| GWT-3 | [KNOWN] Ollama 是当前生效配置 | [KNOWN] Draft 切换 Qwen | [KNOWN] 全局状态仍是 Ollama且 Draft 加载 Qwen 凭证 |
| GWT-4 | [KNOWN] Draft 持久化失败 | [KNOWN] 点击保存 | [KNOWN] 页面保留、全局状态不变并显示脱敏错误 |
| GWT-5 | [KNOWN] 旧自定义 endpoint/model 存在 | [KNOWN] 保存空字段 | [KNOWN] 重载后字段为 null，Provider preset 生效 |

## 5. Mock、数据与断言

| 项 | 规则 | 风险 |
|---|---|---|
| [KNOWN] Hive | [KNOWN] 使用系统临时目录中的真实 Hive box，不访问用户数据 | P1 |
| [KNOWN] Secure storage | [KNOWN] 单元测试使用内存 fake；平台启动只执行当前 Provider 的无值读取 | P1 |
| [KNOWN] API Key fixture | [KNOWN] 仅使用 `openai-test-key`、`qwen-test-key` 等虚构值 | P1 |
| [KNOWN] 失败注入 | [KNOWN] fake store 抛 `StateError`；UI 只断言脱敏消息 | P1 |
| [KNOWN] 网络 | [KNOWN] 自动化测试不调用真实端点；缺密钥在请求前失败 | P1 |

## 6. RED-GREEN-REFACTOR 记录

| 步骤 | 行为 | 文件 | 结果 |
|---|---|---|---|
| RED-S1 | [KNOWN] 设置偏好仓储测试引用不存在文件 | `settings_preferences_store_test.dart` | [KNOWN] 编译失败，目标类型不存在 |
| GREEN-S1 | [KNOWN] 实现单记录 Hive 非敏感偏好 | `settings_preferences_store.dart` | [KNOWN] 3 项测试通过 |
| RED-S2 | [KNOWN] Provider 凭证接口不存在 | `provider_credential_store_test.dart` | [KNOWN] 编译失败，目标接口不存在 |
| GREEN-S2 | [KNOWN] 实现稳定 Provider 键、隔离、删除和错误传播 | `provider_credential_store.dart` | [KNOWN] 3 项测试通过 |
| RED-S3 | [KNOWN] 组合仓储接口不存在 | `settings_repository_test.dart` | [KNOWN] 编译失败，目标 repository 不存在 |
| GREEN-S3 | [KNOWN] 组合 preferences 与 credentials | `settings_repository.dart` | [KNOWN] 4 项测试通过 |
| RED-S4 | [KNOWN] UI 测试要求 repository provider 和 Draft 行为 | settings widget tests | [KNOWN] 编译失败，provider 不存在 |
| GREEN-S4 | [KNOWN] 本地 Draft、异步 Provider 切换、测试和保存 | `settings_page.dart`, Riverpod providers | [KNOWN] 5 项设置测试通过 |
| REFACTOR | [KNOWN] 删除含 API Key 的 Hive adapter 与错误 `copyWith(null)` 语义，配置改为 immutable | `ai_config.dart`, generated adapter | [KNOWN] 全量测试和分析通过 |
| PLATFORM | [KNOWN] 接入 secure storage 与 Apple entitlement | dependency、main、platform files | [KNOWN] macOS Debug build/startup 通过；移动构建环境阻断 |

## 7. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/core/config/ai_config.dart` | [KNOWN] 重构 | [KNOWN] 不可变运行时配置，不再 Hive 序列化 |
| `lib/core/config/settings_preferences_store.dart` | [KNOWN] 新增 | [KNOWN] 非敏感 Hive 偏好 |
| `lib/core/config/settings_repository.dart` | [KNOWN] 新增 | [KNOWN] 组合设置仓储与不可用回退 |
| `lib/core/security/` | [KNOWN] 新增 | [KNOWN] Provider credential boundary 与 secure-storage adapter |
| `lib/main.dart` | [KNOWN] 修改 | [KNOWN] 启动加载并注入初始配置/repository |
| `lib/features/settings/ui/settings_page.dart` | [KNOWN] 修改 | [KNOWN] Draft、异步保存、清除和错误状态 |
| `lib/features/translate/logic/translate_controller.dart` | [KNOWN] 修改 | [KNOWN] 初始配置和 repository providers |
| `pubspec.yaml`, `pubspec.lock` | [KNOWN] 修改 | [KNOWN] `flutter_secure_storage` 10.3.1 |
| Apple platform project/entitlements | [KNOWN] 修改 | [KNOWN] 插件注册、Swift Package 集成和 Keychain 配置 |
| `test/core/config/`, `test/core/security/`, settings tests | [KNOWN] 新增/修改 | [KNOWN] 15 项功能聚焦测试；全仓合计 42 项 |

## 8. 受限命令执行记录

| 命令 | 范围 | 是否执行 | 结果 | 未执行原因 |
|---|---|---|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 全 Dart | [KNOWN] 是 | [KNOWN] 43 files，0 changed |
| `flutter analyze` | 全项目 | [KNOWN] 是 | [KNOWN] No issues found |
| `flutter test --concurrency=1` | 全测试 | [KNOWN] 是 | [KNOWN] 42 passed |
| `flutter build macos --debug` | macOS | [KNOWN] 是 | [KNOWN] 成功生成 Debug app |
| `flutter run -d macos` | macOS 启动 | [KNOWN] 是 | [KNOWN] 插件注册和初始 secure read 无异常，随后正常退出 |
| `flutter build ios --debug --no-codesign` | iOS | [KNOWN] 是 | [KNOWN] 失败：本机未安装 iOS 17.5 platform | [KNOWN] 环境组件缺失 |
| `flutter build apk --debug` | Android | [KNOWN] 是 | [KNOWN] 失败：当前 JDK 11，Android Gradle Plugin 要求 Java 17 | [KNOWN] 本机 JDK 配置不满足 |

## 9. 风险与待确认问题

| 问题 | 等级 | 影响 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] iOS 构建未完成 | P1 | [KNOWN] Keychain 插件与 entitlement 未在 iOS 编译验证 | [KNOWN] 安装匹配 iOS platform 后重跑无签名构建 | [KNOWN] 研发负责人 |
| [KNOWN] Android 构建未完成 | P1 | [KNOWN] Keystore adapter 与 minSdk 未进入编译验证 | [KNOWN] 将 Flutter JDK 指向 Java 17 后重跑 APK 构建 | [KNOWN] 研发负责人 |
| [KNOWN] Apple Release entitlement 需要签名证书 | P1 | [KNOWN] 当前只验证无共享 entitlement 的 macOS Debug 私有 Data Protection Keychain | [KNOWN] 发布签名前验证 Release Keychain entitlement 和读写 | [KNOWN] 发布/研发负责人 |
| [KNOWN] 跨存储无共享事务 | P1 | [KNOWN] credential 写成功而 preferences 写失败时可能留下未激活凭证 | [KNOWN] 应用状态保持旧值并允许重试；未来需要强一致时引入恢复日志 | [KNOWN] 研发负责人 |
| [KNOWN] 旧 `ai_config` box 未删除 | P2 | [KNOWN] 已知实现从未写入，但历史设备文件仍可能存在 | [KNOWN] 若有真实历史版本曾写入，另立安全迁移并在确认后清理 | [KNOWN] 产品/安全负责人 |

## 10. 上下文更新建议

| 建议位置 | 类型 | 内容摘要 | 原因 |
|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 已更新 | [KNOWN] settings preferences、Provider credential、Draft 与 SET-001..004 | [KNOWN] 用户已确认且本地行为已验证 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 已更新 | [KNOWN] Feature 索引、模块、设置流程、外部依赖和历史风险 | [KNOWN] 实现结构已形成 |
| `docs/adr/` | [KNOWN] 跳过 | [INFERRED] repository 隔离使存储插件可替换，不满足难逆条件 | [KNOWN] 无需 ADR 草案 |

## 11. Feature 文档状态

| 文档 | 状态 |
|---|---|
| `docs/features/settings-persistence/feature_context.md` | [KNOWN] 已创建并更新为 `PARTIAL_VERIFICATION` |
| `docs/features/settings-persistence/scope-plan.md` | [KNOWN] 已创建，`TDD_INPUT_READY` |
| `docs/features/settings-persistence/tdd-report.md` | [KNOWN] 已创建 |
