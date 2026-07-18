# Mobile Platform Adaptation Scope 与 TDD 计划

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | `TDD_INPUT_READY` |
| 最高风险等级 | P1 |
| 一句话依据 | [KNOWN] 用户已确认以 App 内移动翻译闭环为首版边界，主干、平台分支、验证口径和排除项均可定位到现有代码与配置 |
| 下一步建议 | 进入 `hicode:tdd`，按移动布局、设置体验、平台配置三个可回滚切片执行 |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| 项目规则 | `AGENTS.md`, `docs/rules/coding_rules.md` | 是 | 三平台目标、平台 guard、测试和构建要求 | 无 |
| 长期上下文 | `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | 是 | TR-004；移动构建此前因工具链/环境未完整验证 | Feature 索引待负责人确认后更新 |
| 产品简报 | `aitrans-prd.md` | 是（移动关键词定位） | 目标平台包含 macOS、iOS、Android | 未给出设备/OS 版本矩阵 |
| 相关实现 | `lib/app.dart`, translate/settings UI, platform configs | 是 | 桌面拖拽组件无条件进入 UI；设置固定 440x640；Android 主 Manifest 无 INTERNET | 真机视觉与输入法矩阵未验证 |
| 用户确认 | 当前任务 2026-07-18 | 是 | 同意推荐首版范围和 Feature ID | 无 |

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | `NO_BLOCKING_GAPS` |
| 需求分析输入 | [KNOWN] 目标、首版范围、排除项、最小宽度、平台隔离、原生配置与构建验证均已确认 |
| 证据缺口 | [KNOWN] 最低 OS、真机矩阵、极端大字体、商店签名与发布策略待确认，但不阻断本地首版适配 |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | iPhone 与 Android 用户可在安全区、软键盘和窄屏条件下完成 App 内翻译与 Provider 设置 |
| 范围内 | 响应式主界面；移动设置；触控尺寸；macOS 能力隔离；Android INTERNET；统一应用名；自动化测试与 Debug 构建 |
| 范围外 | 跨 App 扩展；局域网 Ollama 发现/HTTP；平板专属双栏；商店签名、发布和生产配置 |
| 非目标 | 不重写视觉品牌、不改变翻译业务状态、不改变凭证格式、不新增依赖 |
| 验收标准 | 320px 和横屏无 overflow；键盘/安全区下操作可达；移动端无 macOS 专属 UI；平台配置断言通过；双平台 Debug 构建有真实记录 |
| feature_context 更新 | 已创建 |
| ADR 处理 | 不需要；响应式断点与呈现策略可逆且沿用 Flutter 常规能力 |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | iPhone/Android 启动 App | 移动优先的 App 内翻译闭环 | 核心功能可用 | 不含跨 App/发布 | Widget + Build | P1 |
| MAIN-1 | 主干逻辑 | 宽度 < 600 | 移除桌面标题拖拽区；收紧页面边距；命令与工具区自适应 | 无横向溢出 | 保留单栏 | 320/390/横屏 | P1 |
| MAIN-2 | 主干逻辑 | 移动端打开设置 | 安全区内全屏可滚动设置；关闭/保存可触控 | 键盘下仍可编辑保存 | 桌面仍为 Dialog | 窄屏 + inset | P1 |
| MAIN-3 | 主干逻辑 | 原生移动构建 | Android 主 Manifest 增加 INTERNET；双平台名称统一 | 远程 Provider 有权限，品牌一致 | 不改签名/ATS | 静态断言 + Build | P1 |
| BRANCH-1 | 分支 | macOS | 保持桌面拖拽、浮层和快捷键文案 | 无桌面回归 | 不改 Service/hotkey | 既有测试 | P1 |
| BRANCH-2 | 分支 | Android | 延续禁用 blur，主配置提供 INTERNET | 性能与联网基线 | 不加 cleartext | Widget/static | P2 |
| BRANCH-3 | 分支 | 高度受限/键盘 | 页面响应 viewInsets，设置与结果可滚动 | 控件可达 | 不承诺极端大字体完全一致 | inset 测试 | P1 |
| BRANCH-4 | 分支 | 依赖环境失败 | 停止把环境失败当行为结论；保留静态证据 | `PARTIAL_VERIFICATION` | 不更换依赖源 | 命令记录 | P1 |

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| 首版范围与 Feature ID | 已关闭 | `mobile-platform-adaptation` 推荐范围 | 用户已明确同意 | 解锁 TDD | 用户 |
| 最低 OS/真机矩阵 | 待负责人确认 | 先沿用 Flutter 工程当前默认值 | 本轮不改变平台支持版本 | 影响发布声明，不阻断开发 | 产品/发布负责人 |
| 极端大字体标准 | 待负责人确认 | 后续按 200% 独立无障碍验收 | 避免本轮隐式裁剪文本 | 影响可访问性发布结论 | 产品/测试负责人 |

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| `AppShell` | 平台标题区、底部操作、安全区 | 源码审计 + 用户确认 | 已确认 | P1 |
| `CommandBar` | 320px 输入与操作布局、触控目标 | 源码审计 + UI/UX 移动规则 | 已确认 | P1 |
| `SettingsSheet` | 固定尺寸转响应式、移动端隐藏快捷键 | 源码审计 + 用户确认 | 已确认 | P1 |
| Android Manifest | Release INTERNET 权限 | debug/profile 与 main 差异 | 已确认 | P1 |
| iOS Info.plist | Display Name 统一 | 当前值 `Aitrans` | 已确认 | P2 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| Android Release 当前可能无法联网 | P1 | INTERNET 仅在 debug/profile Manifest | 首个配置切片加入主 Manifest 并做静态断言 | 研发/测试 |
| 响应式修改回归 macOS | P1 | 单一 Widget 树服务三平台 | 用能力/宽度分支且运行既有测试 | 研发/测试 |
| Flutter 依赖无法恢复 | P1 | pub.dev TLS 握手失败；本机缺 openai_dart 缓存 | 优先寻找工作区锁定缓存；否则记录 PARTIAL_VERIFICATION | 研发环境负责人 |
| 真机输入法与系统栏未覆盖 | P2 | 当前仅有桌面/Widget 证据 | 后续真机矩阵验证 | 测试负责人 |

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| 单代码树 + 平台能力/宽度适配 | 是 | LayoutBuilder/MediaQuery 驱动单栏响应式布局 | macOS 专属组件显式 guard；移动设置全屏化 | 不新增平台页面副本 | 维护面小、行为一致、易回归测试 | 条件分支需集中命名 | — |
| iOS/Android 各自独立页面 | 否 | 每平台复制主流程 | 各自原生化 | 范围大 | 最大视觉定制 | 状态与测试重复、易漂移 | 首版代价超过收益 |
| 只修原生构建不改 UI | 否 | 保持当前桌面 UI | 仅加权限/名称 | 过窄 | 改动最小 | 不能满足“适配”核心验收 | 无法解决窄屏、键盘和触控问题 |

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | `TDD_INPUT_READY` |
| 下一步路由 | `hicode:tdd` |
| 未覆盖设计树节点 | 真机矩阵与极端大字体留作后续验证，不阻断本轮 |

### 可独立 TDD 切片

| 任务 | 目标 | 对应节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点 | 验证 | 停止条件 |
|---|---|---|---|---|---|---|---|---|
| S1 | 让移动 AppShell/CommandBar 在 320px 可操作 | MAIN-1, BRANCH-1/2 | 现有 Widget 与用户范围 | 内：标题、边距、命令与底栏；外：业务状态 | `app.dart`, translate UI/tests | 320px overflow/可见性测试 | 聚焦 Widget + macOS 回归 | 需要重写控制器时停止 |
| S2 | 让设置在移动端与键盘下可访问 | MAIN-2, BRANCH-3 | 固定 440x640 现状 | 内：呈现、尺寸、滚动、平台文案；外：设置业务规则 | settings UI/tests | 窄屏打开设置和隐藏快捷键 RED | settings Widget tests | 需要改变凭证协议时停止 |
| S3 | 修复移动原生配置 | MAIN-3 | 平台配置审计 | 内：INTERNET/应用名；外：签名、HTTP、发布 | Android Manifest, iOS plist, tests | 配置断言 RED | 静态测试 + Build | 需要生产签名时停止 |
| S4 | 回归与构建验证 | ROOT, BRANCH-4 | S1-S3 GREEN | 内：format/analyze/test/debug build；外：发布 | 全量 tests/build | 既有测试 | 全量命令记录 | 依赖/网络阻断则降级并留痕 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1 | 320x568 打开主界面无 overflow，翻译/设置可见 | Widget | P0 | 虚构空状态 | S1 |
| BRANCH-1 | 桌面宽度保留既有工具与行为 | Widget | P0 | 800x450 | S1 |
| MAIN-2 | 390x844 打开设置，关闭/保存区可访问且无 macOS 快捷键 | Widget | P0 | fake repository/provider | S2 |
| BRANCH-3 | 低高度/键盘 inset 下设置可滚动 | Widget | P0 | viewInsets 模拟 | S2 |
| MAIN-3 | Android main INTERNET + 双平台 AITrans 名称 | Static | P0 | 仓库配置文件 | S3 |
| ROOT | iOS Simulator / Android Debug 构建 | Build | P0 | 本机非生产工具链 | S4 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | 否 |
| 判断理由 | 使用 Flutter 标准响应式布局与显式平台 guard，决策可逆、无新依赖、无难逆公开契约 |
| 涉及决策点 | 600px 移动断点、移动设置全屏呈现；均作为局部 UI 策略记录在 Feature 文档 |

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | 无 | 不新增稳定业务术语或规则 | 跳过 | 不适用 |
| `docs/PROJ_CONTEXT.md` | Feature 索引建议 | 完成后记录移动适配状态与验证结果 | 待本轮真实验证后建议更新 | 待负责人确认 |
| `docs/features/mobile-platform-adaptation/feature_context.md` | 创建 | 已确认范围、设计树、风险与影响面 | 已创建 | 已确认范围 |
| `docs/features/mobile-platform-adaptation/scope-plan.md` | 创建 | `TDD_INPUT_READY` 与 S1-S4 | 已创建 | 已确认范围 |
