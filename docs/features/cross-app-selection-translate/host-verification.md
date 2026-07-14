# macOS 宿主验证矩阵

## 自动化证据

| 检查项 | 状态 | 证据 |
|---|---|---|
| Service bundle 声明 | [KNOWN] PASS | [COMPUTED] 编译后 `Info.plist` 含菜单“使用 AITrans 翻译”、`translateSelection`、单一 `NSStringPboardType` send type 和 10 秒系统超时 |
| macOS 10.15 baseline | [KNOWN] PASS | [COMPUTED] 编译后 `LSMinimumSystemVersion` 为 `10.15` |
| 原生载荷、bundle 与 sequence | [KNOWN] PASS | [COMPUTED] xcresult 记录 8 个 Runner XCTest 通过，覆盖编译后 Service 声明、单项纯文本、缺失文本、多项载荷、安全错误、sequence 和 cold/warm buffer；修复后启动输出未再出现 AppDelegate uncaught exception |
| Flutter bridge | [KNOWN] PASS | [COMPUTED] Dart tests 覆盖 typed payload、非法 payload、ready 握手、latest-wins、超长拒绝和安全错误 UI |
| macOS debug build | [KNOWN] PASS | [COMPUTED] x86_64、`ONLY_ACTIVE_ARCH=YES`、禁用签名的 Xcode Debug build 通过 |
| 系统 Service 数据库调用 | [KNOWN] PASS | [COMPUTED] 使用隔离公开文本调用 `NSPerformService("使用 AITrans 翻译", pasteboard)` 返回 `true` |

## 实机宿主矩阵

| 宿主 | Service 菜单出现 | 正常文本 | 5,001 字符 | 冷启动 | 热启动 | 当前状态 |
|---|---|---|---|---|---|---|
| Safari | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] `BLOCKED_ENVIRONMENT` |
| Chrome | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] `BLOCKED_ENVIRONMENT` |
| Books | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] 未验证 | [KNOWN] `BLOCKED_ENVIRONMENT` |

## 执行约束

- [KNOWN] 只使用公开、非敏感测试文本；不得读取现有标签页、书籍内容或用户剪贴板。
- [KNOWN] 每个宿主分别验证菜单发现、冷启动、热启动、连续两次触发与超长错误。
- [KNOWN] 宿主不展示系统 Service 时记录“不支持”，不得改写为通过。
- [KNOWN] 用户已授权 GUI 验证，且沙箱外 Accessibility 查询返回 `true`。
- [KNOWN] 最终签名 Debug App 在当前机器启动后无窗口；主线程采样持续停在 `_libsecinit_appsandbox` 等待 XPC，因此不能完成宿主菜单、冷启动或热启动验证。
- [KNOWN] 不得为绕过该阻断而关闭 App Sandbox；Scope 明确要求若验证依赖解除 App Sandbox 则停止并返回范围评审。
- [KNOWN] Books 测试 EPUB 已创建但未导入，并已删除；未修改 Books 资料库。
- [KNOWN] 一次全屏截图越过隔离测试边界，证据判为无效并立即删除；不得用该截图推断任何宿主结果。
