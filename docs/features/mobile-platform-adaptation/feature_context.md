# Mobile Platform Adaptation Feature Context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] iPhone 与 Android 首版适配 |
| 需求编号 | [KNOWN] `mobile-platform-adaptation` |
| 需求链接 | [KNOWN] 当前 Codex 任务；无外部链接 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 发布负责人 | [KNOWN] 待确认 |
| 当前状态 | [KNOWN] `PARTIAL_VERIFICATION`；Android Debug、iOS 26.5 Simulator 与 124 项测试已通过，iPhone/Android 真机验证待补 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 移动端核心翻译流可用 | iPhone 与 Android 在窄屏、安全区、软键盘和触控输入下可完成输入、翻译、查看结果和进入设置 | 320 logical px 宽度无布局溢出；输入与主要操作可见；软键盘打开时内容仍可滚动/访问 |
| [KNOWN] 桌面能力不泄漏到移动端 | macOS 窗口拖拽、状态栏和快捷键说明不在移动端构建或界面中出现 | 移动视口测试不查找到 macOS 专属说明；非 macOS 不构建拖拽标题栏 |
| [KNOWN] 移动端原生配置可支持在线翻译 | Android Release 具备网络权限，iOS/Android 展示统一产品名 | Manifest/Info.plist 断言通过；Debug 构建完成后记录结果 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] 响应式主界面 | 320px 起适配输入条、结果文档、语言/设置操作区 | 用户确认范围；当前 UI 审计 |
| [KNOWN] 安全区与软键盘 | 尊重 iPhone 刘海/Home Indicator、Android 系统栏与 `viewInsets` | 用户确认范围；移动端可用性基线 |
| [KNOWN] 移动端设置体验 | 窄屏使用全屏/近全屏可滚动设置界面，桌面保留居中浮层 | 用户确认范围；当前固定 440x640 审计 |
| [KNOWN] 触控与平台文案 | 主要控件达到移动端可用点击面积；移动端隐藏 macOS 快捷键区 | 用户确认范围；当前 shrinkWrap 控件审计 |
| [KNOWN] 原生配置 | Android 主 Manifest 网络权限；iOS/Android 应用名统一为 AITrans | 用户确认范围；平台文件审计 |
| [KNOWN] 自动化验证 | 窄屏/横屏 Widget 测试、平台配置测试、静态分析和双平台 Debug 构建 | 项目规则；用户确认范围 |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [KNOWN] iOS Share Extension、Android `ACTION_PROCESS_TEXT` 接收入口 | 属于跨应用选中文本翻译能力，需独立原生协议和隐私 Scope | 首版只能在 App 内输入翻译 |
| [KNOWN] 局域网 Ollama 自动发现与明文 HTTP 放行 | 涉及网络发现、ATS/Network Security Config 与隐私边界 | 移动端首版主要使用 HTTPS 远程 Provider |
| [KNOWN] 商店签名、上架、发布与生产配置 | 当前任务不授权发布或生产操作 | 不形成上架就绪结论 |
| [KNOWN] iPad/Android 平板专属双栏 | 本轮只保证响应式可用，不新增平板信息架构 | 平板沿用受约束的单栏布局 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | iPhone 或 Android 用户打开 AITrans | 提供平台合适、可触控且可构建的 App 内翻译闭环 | 用户能输入、翻译、阅读结果和配置 Provider | 移动视口 Widget 测试 + 双平台 Debug 构建 | P1 | [KNOWN] 已确认 |
| MAIN-1 | 主干逻辑 | 320-767px 移动视口 | 使用紧凑水平留白、无桌面拖拽区、可伸缩命令条和底部控制 | 无 overflow；主操作可见 | 320x568、390x844、横屏用例 | P1 | [KNOWN] 已确认 |
| MAIN-2 | 主干逻辑 | 打开设置 | 移动端使用安全区内的全屏路由外观；桌面保留 440px Dialog | 字段、保存和关闭均可访问 | 窄屏设置测试、键盘 inset 测试 | P1 | [KNOWN] 已确认 |
| MAIN-3 | 主干逻辑 | Android Release 发起远程请求 | 主 Manifest 声明 INTERNET；产品名统一 | Release 包具备联网能力且品牌一致 | XML/Plist 断言 + Debug 构建 | P1 | [KNOWN] 已确认 |
| BRANCH-1 | 分支处理 | 软键盘打开或高度受限 | Scaffold 响应 inset；滚动内容保留可访问性；底部控制避免被遮挡 | 无不可达操作 | 低高度视口与 viewInsets 测试 | P1 | [KNOWN] 已确认 |
| BRANCH-2 | 分支处理 | macOS 桌面视口 | 保留拖拽标题栏、居中设置浮层和桌面快捷键说明 | 既有 macOS 行为不回退 | 既有 Widget/平台测试 | P1 | [KNOWN] 已确认 |
| BRANCH-3 | 分支处理 | Android 性能受限 | 保留现有 Android 禁用 BackdropFilter 策略 | 输入区域无额外高成本模糊 | 代码保护 + Widget 测试 | P2 | [KNOWN] 已确认 |
| BRANCH-4 | 分支处理 | 依赖或本地工具链不可用 | 记录真实阻断，不把环境失败视为行为 RED/GREEN | 结论降级为 PARTIAL_VERIFICATION | 命令与错误摘要留痕 | P1 | [KNOWN] 已确认 |

## 4. 核心规则

| 规则编号 | 业务域 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|---|
| MPA-001 | Platform UI | macOS 专属窗口能力必须通过平台与宽度能力隔离 | 当前平台 | 合适的 AppShell 顶部结构 | 不改变 macOS 既有能力 | [KNOWN] 已确认 |
| MPA-002 | Responsive UI | 320 logical px 宽度不得出现 RenderFlex overflow | 320px 视口、系统文字比例默认值 | 可操作单栏界面 | 极端无障碍文字比例另列残余风险，不能主动裁剪文字 | [KNOWN] 已确认 |
| MPA-003 | Touch | 移动端主要交互目标使用至少 44 logical px 的可点击高度 | iOS/Android | 可触控操作 | 桌面紧凑样式可保持现状 | [KNOWN] 已确认 |
| MPA-004 | Platform config | Android 主 Manifest 必须声明 INTERNET；应用显示名为 AITrans | Release 配置 | 远程 Provider 可建立网络连接 | 不放行移动端明文 HTTP | [KNOWN] 已确认 |

## 5. 高严谨风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 领域业务逻辑严谨性 | 否 | 不改变翻译规则或 Provider 协议 | 无 | NONE |
| 金额与关键数值精度 | 否 | 无金额/计量变化 | 无 | NONE |
| 交易与数据一致性 | 否 | 不改变持久化事务 | 无 | NONE |
| 状态流转 | 是 | 设置 Draft/Save 行为必须保持 | 无 | P1 |
| 幂等与并发 | 否 | 不改变请求控制器 | 无 | NONE |
| 权限与审计 | 是 | 只新增 Android INTERNET 普通权限 | 明文局域网访问仍排除 | P1 |
| 隐私与合规 | 是 | 不新增采集或跨 App 读取；凭证存储规则保持 | 商店隐私清单未来独立处理 | P1 |
| 生产变更与回滚 | 否 | 不发布、不修改生产配置 | 无 | NONE |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| Flutter UI | `lib/app.dart` | 平台标题区、底部工具区、设置呈现策略 | P1 |
| Flutter UI | `lib/features/translate/ui/` | 窄屏命令条、页面留白、结果可滚动性 | P1 |
| Flutter UI | `lib/features/settings/ui/settings_page.dart` | 移动端尺寸、安全区、软键盘和平台说明 | P1 |
| Native config | `android/app/src/main/AndroidManifest.xml` | Release 网络权限和应用名 | P1 |
| Native config | `ios/Runner/Info.plist` | 应用显示名 | P2 |
| Tests | `test/` | 移动视口和平台配置行为测试 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| 320px 无 overflow | Widget | P0 | 最小移动宽度验收口径 |
| 软键盘/低高度可访问 | Widget | P0 | 设置与翻译输入均受影响 |
| macOS 行为回归 | Widget/Platform | P0 | 同一 AppShell 服务桌面和移动端 |
| Android Release 网络权限 | Static/Build | P0 | 当前权限仅存在于 debug/profile Manifest |
| iOS/Android Debug 构建 | Build | P0 | 本机工具链完整，但依赖获取当前受 TLS 影响 |

## 8. 待确认问题

| 问题 | 风险等级 | 影响 | 建议确认人 | 期望材料 |
|---|---|---|---|---|
| 商店支持的最低 OS 版本与设备矩阵 | P2 | 发布前兼容性声明 | 产品/发布负责人 | App Store / Play 目标策略 |
| 无障碍大字体的正式支持上限 | P2 | 极端 textScale 布局 | 产品/测试负责人 | 可访问性验收矩阵 |
