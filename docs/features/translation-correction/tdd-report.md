# TDD 与辅助编码报告

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `LOCAL_VERIFIED` |
| 最高风险等级 | [KNOWN] P1 |
| 模式 | [KNOWN] 本地修改 |
| 置信度 | [KNOWN] HIGH |

## 2. 测试目标与范围

| 项 | 内容 |
|---|---|
| 测试目标 | [KNOWN] 在一次主翻译 AI 响应中返回可选更正与译文；保留输入框原文；在译文区提示有效更正；让三类扩展内容使用同一 adopted source |
| 测试范围 | [KNOWN] 输出协议、Prompt、展示模型、安全 token 校验、状态、控制器、缓存、扩展请求参数、结果区和复制内容 |
| 不覆盖范围 | [KNOWN] 独立校对模式、风格润色、事实核查、第二次纠错请求、个人词典、真实模型纠错准确率 |

## 3. 测试场景

| 编号 | 场景 | 类型 | 优先级 | 风险等级 |
|---|---|---|---|---|
| TC-TDD-001 | [KNOWN] 有效拼写更正与译文分离解析 | model | P1 | P1 |
| TC-TDD-002 | [KNOWN] 更正修改数字、URL 或标识符时拒绝采用 | safety | P1 | P1 |
| TC-TDD-003 | [KNOWN] 同一提示词响应同时包含纠错判断与译文 | contract | P1 | P1 |
| TC-TDD-004 | [KNOWN] 完成态与缓存命中均用 corrected adopted source 请求扩展内容 | controller/cache | P1 | P1 |
| TC-TDD-005 | [KNOWN] 缓存写失败仍保留完成译文 | failure | P1 | P1 |
| TC-TDD-006 | [KNOWN] 缺失译文时进入错误态且不加载扩展内容 | malformed response | P1 | P1 |
| TC-TDD-007 | [KNOWN] 更正提示与主译文并存且协议标记不可见 | widget | P1 | P1 |
| TC-TDD-008 | [KNOWN] 复制内容排除 `CORRECTION:` 协议行 | widget | P1 | P1 |
| TC-TDD-009 | [KNOWN] 无更正时不显示空提示 | widget | P1 | P1 |
| TC-TDD-010 | [KNOWN] 流式展示不泄漏完整纠错协议行 | widget | P1 | P1 |

## 4. Given-When-Then 用例

| 编号 | Given | When | Then |
|---|---|---|---|
| TC-TDD-001 | [KNOWN] 原输入为 `teh cat` | [KNOWN] 响应为 `CORRECTION: the cat` 加译文 | [KNOWN] `correctedSource` 与 `adoptedSource` 为 `the cat`，主译文独立解析 |
| TC-TDD-002 | [KNOWN] 原输入包含虚构 URL、数字和标识符 | [KNOWN] 候选更正改变受保护 token | [KNOWN] 忽略更正并回退原输入 |
| TC-TDD-004 | [KNOWN] 实时响应或缓存含有效更正 | [KNOWN] 用户立即翻译 | [KNOWN] 只在翻译完成后用更正文本触发一次扩展内容加载 |
| TC-TDD-005 | [KNOWN] 缓存存储抛出合成异常 | [KNOWN] 翻译流正常完成 | [KNOWN] 状态仍为 `TranslateComplete`，异步异常不冒泡 |
| TC-TDD-006 | [KNOWN] 响应只有 correction、没有译文 | [KNOWN] 翻译流完成 | [KNOWN] 状态为 `TranslateError`，不缓存且不加载扩展内容 |
| TC-TDD-007 | [KNOWN] 完成态携带原输入和有效更正 | [KNOWN] 结果区渲染 | [KNOWN] 显示“已更正为”、更正文本与主译文，不显示协议行 |
| TC-TDD-009 | [KNOWN] 响应不含有效更正 | [KNOWN] 结果区渲染 | [KNOWN] 保持原译文体验且不显示更正提示 |

## 5. Mock、数据与断言

| 项 | 规则 | 风险 |
|---|---|---|
| AI Provider | [KNOWN] 使用可控内存 Stream，不发起真实网络请求 | [KNOWN] 不验证真实模型遵循 Prompt 的概率 |
| 缓存 | [KNOWN] 使用延迟、立即命中和写失败三种 fake store | [KNOWN] 不验证 Hive 文件系统损坏恢复 |
| 测试数据 | [KNOWN] 使用 `teh cat`、虚构 `.test` URL 和合成异常，不含生产数据 | [KNOWN] 无生产隐私暴露 |
| 核心断言 | [KNOWN] adopted source、状态类型、扩展请求参数、协议不可见、复制文本和主译文字号层级 | [KNOWN] 视觉像素级差异未做 golden test |

## 6. RED-GREEN-REFACTOR 记录

| 步骤 | 行为 | 文件 | 结果 |
|---|---|---|---|
| RED S1 | [KNOWN] 新增 correction 分离解析测试 | `translation_presentation_test.dart` | [KNOWN] 因缺少 `originalSource`、`correctedSource`、`adoptedSource` 编译失败 |
| GREEN S1 | [KNOWN] 增加 typed correction、adopted source、协议版本 4 和安全 token 校验 | `translation_presentation.dart` | [KNOWN] model tests 5 项通过 |
| RED S1-B | [KNOWN] 新增未闭合 `CORREC` 流式协议前缀测试 | `translation_presentation_test.dart` | [KNOWN] partial frame 被错误解析为主译文而失败 |
| GREEN S1-B | [KNOWN] 在 presentation 边界隐藏未闭合协议前缀 | `translation_presentation.dart` | [KNOWN] 最终 model tests 6 项通过 |
| RED S2 | [KNOWN] 要求 Prompt 包含允许纠错、禁止改写和单响应协议 | `prompts_test.dart` | [KNOWN] 旧 Prompt 缺少 `CORRECTION:` 规则而失败 |
| GREEN S2 | [KNOWN] 扩充共用翻译 Prompt，保持单次 Provider 请求 | `prompts.dart` | [KNOWN] prompt/provider tests 6 项通过 |
| RED S3 | [KNOWN] 要求完成态保留原输入且扩展内容采用更正文本 | `translate_controller_test.dart` | [KNOWN] 因状态缺少 `sourceText` 而编译失败 |
| GREEN S3 | [KNOWN] 状态携带原输入，实时与缓存路径统一解析 adopted source | `translate_state.dart`, `translate_controller.dart` | [KNOWN] 主控制器路径通过 |
| RED S3-B | [KNOWN] 注入缓存写失败 | `translate_controller_test.dart` | [KNOWN] 未处理异步异常导致测试失败 |
| GREEN S3-B | [KNOWN] 缓存写入改为捕获失败的旁路操作 | `translate_controller.dart` | [KNOWN] 控制器 tests 10 项通过 |
| RED S4 | [KNOWN] 要求显示更正、隐藏协议、清理复制内容 | `result_document_test.dart` | [KNOWN] 找不到“已更正为”而失败 |
| GREEN S4 | [KNOWN] UI 使用原输入解析 presentation，新增低权重更正区与纯译文复制 | `result_document.dart`, `translation_presentation.dart` | [KNOWN] 控制器与 UI focused tests 21 项通过 |
| RED S4-B | [KNOWN] 要求 correction-only 完成响应进入错误态 | `translate_controller_test.dart` | [KNOWN] 实际错误地进入 `TranslateComplete` |
| GREEN S4-B | [KNOWN] 缓存和实时完成路径先验证非空主译文 | `translate_controller.dart` | [KNOWN] 空译文进入安全错误态且不触发扩展内容 |
| REFACTOR | [KNOWN] 提取 `translationText` 和 `_writeCacheSafely`，复用 presentation 的 adopted source | production files | [KNOWN] 全套测试保持 GREEN |

## 7. 修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/core/ai/prompts.dart` | [KNOWN] 修改 | [KNOWN] 单响应纠错与翻译协议、安全边界 |
| `lib/features/translate/models/translation_presentation.dart` | [KNOWN] 修改 | [KNOWN] 更正解析、adopted source、纯译文文本、安全 token 校验、缓存协议版本 4 |
| `lib/features/translate/models/translate_state.dart` | [KNOWN] 修改 | [KNOWN] streaming/complete 状态保留原输入 |
| `lib/features/translate/logic/translate_controller.dart` | [KNOWN] 修改 | [KNOWN] adopted source、缓存命中一致性、空译文和缓存写失败处理 |
| `lib/features/translate/ui/result_document.dart` | [KNOWN] 修改 | [KNOWN] 更正提示、协议隔离和纯译文复制 |
| `test/core/ai/prompts_test.dart` | [KNOWN] 修改 | [KNOWN] Prompt 契约测试 |
| `test/features/translate/models/translation_presentation_test.dart` | [KNOWN] 修改 | [KNOWN] 解析与安全边界测试 |
| `test/features/translate/translate_controller_test.dart` | [KNOWN] 修改 | [KNOWN] 控制器、缓存、错误和扩展参数测试 |
| `test/features/translate/ui/result_document_test.dart` | [KNOWN] 修改 | [KNOWN] 更正展示、流式、复制和无更正回归测试 |
| `docs/features/translation-correction/feature_context.md` | [KNOWN] 新增 | [KNOWN] 需求上下文与业务规则 |
| `docs/features/translation-correction/scope-plan.md` | [KNOWN] 新增 | [KNOWN] Scope 准入与 S1-S4 设计树 |
| `docs/features/translation-correction/tdd-report.md` | [KNOWN] 新增 | [KNOWN] 本报告 |

## 8. 受限命令执行记录

| 命令 | 范围 | 是否执行 | 结果 | 未执行原因 |
|---|---|---|---|---|
| `dart format --output=none --set-exit-if-changed <本任务 9 个 Dart 文件>` | [KNOWN] 本任务修改 | [KNOWN] 是 | [KNOWN] 9 个文件，0 个变化 | [KNOWN] 不适用 |
| `dart format --output=none --set-exit-if-changed lib test` | [KNOWN] 全应用与测试 | [KNOWN] 是 | [KNOWN] 发现两个本任务外文件存在既有格式差异；命令改写后已立即恢复，未混入本任务 | [KNOWN] 不适用 |
| `flutter analyze` | [KNOWN] 全项目 | [KNOWN] 是 | [KNOWN] `No issues found` | [KNOWN] 不适用 |
| `flutter test` | [KNOWN] 全测试套件 | [KNOWN] 是 | [KNOWN] 最终 101 项全部通过 | [KNOWN] 不适用 |
| `flutter build macos --debug` | [KNOWN] macOS Debug | [KNOWN] 是 | [KNOWN] 首次因并发 build database 锁失败；确认无存活构建进程后重试成功，生成 `aitrans.app` | [KNOWN] 不适用 |
| `git diff --check` | [KNOWN] 当前 diff | [KNOWN] 是 | [KNOWN] 通过，无空白错误 | [KNOWN] 不适用 |

## 9. 风险与待确认问题

| 问题 | 等级 | 影响 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [INFERRED] 真实模型仍可能不遵循纠错范围，尤其是不确定专有名词 | P1 | [INFERRED] 可能生成语义不当的更正；本地仅能确定性保护数字、URL、snake_case 与 camelCase 标识符 | [KNOWN] 保持原输入可见；发布前用各已配置 Provider 做脱敏验收样例；不要宣称纠错绝对准确 | [KNOWN] 产品与测试负责人 |
| [INFERRED] 通用“代码”片段无法仅靠正则完整识别 | P1 | [INFERRED] 非 snake/camel 标识符的代码片段主要依赖 Prompt 约束 | [KNOWN] 若需要强安全保证，应在后续 Scope 中定义代码块/标识符词法规则，而不是继续扩张猜测式正则 | [KNOWN] 产品与研发负责人 |
| [KNOWN] 3 个 macOS 插件尚不支持 Swift Package Manager | P2 | [KNOWN] 当前仅警告，Flutter 提示未来版本会升级为错误 | [KNOWN] 单独跟踪插件升级或替换，不与本功能混改 | [KNOWN] 研发负责人 |
| [KNOWN] `lib/features/translate/ui/translate_page.dart` 与 `lib/main.dart` 存在本任务外格式差异 | P3 | [KNOWN] 全目录 format check 会产生无关 diff | [KNOWN] 在独立格式化变更中处理 | [KNOWN] 研发负责人 |

## 10. 上下文更新建议

| 建议位置 | 类型 | 内容摘要 | 原因 |
|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 建议更新 | [KNOWN] 增加 corrected source、adopted source、允许纠错范围和敏感 token 规则 | [KNOWN] 已形成跨 Provider 的稳定 Translation 领域规则，但按项目规则需负责人确认后写入长期上下文 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 建议更新 | [KNOWN] 将 `translation-correction` 加入 Feature 索引并标记本地验证完成 | [KNOWN] 当前未指派负责人，故本轮不直接更新长期索引 |
