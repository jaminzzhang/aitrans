# feature_context

## 1. 需求基本信息

| 字段 | 内容 |
|---|---|
| 需求名称 | [KNOWN] 设置持久化与 Provider 凭证隔离 |
| feature-id | [KNOWN] `settings-persistence` |
| 需求来源 | [KNOWN] 用户确认优化当前仅驻留 Riverpod 内存的设置 |
| 所属版本 | [KNOWN] 待确认 |
| 业务负责人 | [KNOWN] 待确认 |
| 研发负责人 | [KNOWN] 待确认 |
| 测试负责人 | [KNOWN] 待确认 |
| 当前状态 | [KNOWN] `PARTIAL_VERIFICATION`；本地加密与审查修复已实现，移动端构建仍待验证 |
| 确认日期 | [KNOWN] 2026-07-14 |

## 2. 需求目标与范围

| 目标 | 说明 | 验收口径 |
|---|---|---|
| [KNOWN] 设置跨重启保留 | [KNOWN] Provider、Base URL、模型写入非敏感本地配置存储 | [KNOWN] 重新创建仓储后可加载相同配置 |
| [KNOWN] 凭证安全隔离 | [KNOWN] API Key 仅以 AES-256-GCM 密文进入原子设置记录，并按稳定 Provider ID 隔离 | [KNOWN] Hive 中无明文 API Key；不同 Provider 读取不同凭证 |
| [KNOWN] Draft 后提交 | [KNOWN] 设置页编辑、切换 Provider、测试连接不提前修改全局生效配置 | [KNOWN] 取消不改变配置；保存全部成功后才切换全局状态 |
| [KNOWN] 字段可清除 | [KNOWN] 空 Base URL/模型表示删除自定义覆盖并恢复 preset | [KNOWN] 保存空字段后重新加载仍为空 |

### 范围内

| 范围项 | 说明 | 依据 |
|---|---|---|
| [KNOWN] 非敏感设置仓储 | [KNOWN] 使用 Hive 保存 schema version、Provider、Base URL、模型 | [KNOWN] 项目已有 Hive 依赖与初始化 |
| [KNOWN] Provider 凭证仓储 | [KNOWN] 使用本地随机主密钥、认证密文、稳定 Provider ID 和 keyId 绑定 | [KNOWN] 用户确认无口令本地加密方案；项目规则禁止明文凭证落盘 |
| [KNOWN] 启动加载 | [KNOWN] `runApp` 前加载当前配置，失败时使用 Ollama 默认配置并保留可诊断状态 | [KNOWN] 当前启动流程已在 `main.dart` 初始化本地依赖 |
| [KNOWN] 设置页 Draft | [KNOWN] 本地编辑、按 Provider 加载凭证、测试 Draft、保存后更新全局配置 | [KNOWN] 用户确认推荐优化方案 |
| [KNOWN] 自动化测试 | [KNOWN] 仓储、隔离、清除、取消、保存失败、启动回退 | [KNOWN] 项目测试规则 |

### 范围外

| 范围项 | 排除原因 | 影响 |
|---|---|---|
| [KNOWN] 翻译缓存加密与保留策略 | [KNOWN] 属于用户文本数据治理，不是设置持久化 | [KNOWN] 既有缓存风险仍保留 |
| [KNOWN] 凭证云同步、导入或导出 | [KNOWN] 未获用户需求 | [KNOWN] 凭证仅在本设备应用安全域使用 |
| [KNOWN] 生物识别强制解锁 | [KNOWN] 会改变每次调用的交互与平台最低要求 | [KNOWN] 当前方案不使用生物识别或系统凭证库 |
| [KNOWN] 多配置档案与账号体系 | [KNOWN] 当前产品只有一个生效 Provider | [KNOWN] 每个 Provider 只保存一个本机凭证 |
| [KNOWN] 真实厂商连接验证 | [KNOWN] 不读取真实凭证、不调用收费端点 | [KNOWN] 使用 fake 仓储和 fake Provider 测试 |

## 3. 设计树

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 验证点 | 风险等级 | 状态 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户配置 AI Provider | [KNOWN] 偏好与认证密文进入单一原子状态记录，主密钥独立保存 | [KNOWN] 重启后恢复且凭证不明文落盘 | [KNOWN] 重建仓储与跨 Provider 测试 | P1 | [KNOWN] 已确认 |
| MAIN-1 | 启动加载 | [KNOWN] 应用启动 | [INFERRED] 加载非敏感偏好，再按当前 Provider 读取凭证 | [KNOWN] 初始 `AIConfig` 或安全默认值 | [KNOWN] 成功、缺失、损坏和读取失败测试 | P1 | [KNOWN] 已确认 |
| MAIN-2 | Draft 编辑 | [KNOWN] 打开设置页 | [KNOWN] 从当前配置复制到本地 Draft | [KNOWN] 全局配置保持不变 | [KNOWN] 切换、编辑、关闭测试 | P1 | [KNOWN] 已确认 |
| MAIN-3 | Provider 切换 | [KNOWN] Draft 选择其他 Provider | [KNOWN] 清空 endpoint/model 覆盖并读取该 Provider 独立凭证 | [KNOWN] Draft 显示目标 Provider 数据 | [KNOWN] 凭证隔离测试 | P1 | [KNOWN] 已确认 |
| MAIN-4 | 保存 | [KNOWN] 点击保存且 Draft 合法 | [KNOWN] 一次 Hive `put` 原子提交偏好与认证密文；成功后更新全局状态并关闭 | [KNOWN] 新配置生效 | [KNOWN] 成功与失败不改变旧状态测试 | P1 | [KNOWN] 已确认 |
| MAIN-5 | 测试连接 | [KNOWN] 点击测试连接 | [KNOWN] 用 Draft 临时创建 Provider，完成后关闭 | [KNOWN] 只更新连接提示 | [KNOWN] 全局状态不变测试 | P1 | [KNOWN] 已确认 |
| BRANCH-1 | 清除字段 | [KNOWN] Base URL/模型输入为空 | [KNOWN] 删除自定义覆盖，不使用 `copyWith(null)` 保留旧值 | [KNOWN] preset 再次生效 | [KNOWN] 保存与重载测试 | P1 | [KNOWN] 已确认 |
| BRANCH-2 | 清除凭证 | [KNOWN] API Key 输入为空 | [KNOWN] 删除当前 Provider 的安全存储条目 | [KNOWN] 其他 Provider 凭证不变 | [KNOWN] 删除与隔离测试 | P1 | [KNOWN] 已确认 |
| BRANCH-3 | 存储失败 | [KNOWN] Hive 或安全存储抛错 | [KNOWN] 不更新全局状态、不关闭设置页、显示脱敏错误 | [KNOWN] 用户可重试 | [KNOWN] fake failure 测试 | P1 | [KNOWN] 已确认 |
| BRANCH-4 | 损坏数据 | [KNOWN] Hive schema/index/字段非法 | [INFERRED] 忽略损坏值并回退 Ollama 默认配置 | [KNOWN] 应用可启动 | [KNOWN] malformed fixture 测试 | P1 | [KNOWN] 已确认 |

## 4. 核心业务规则

| 规则编号 | 业务域 | 规则说明 | 输入 | 输出 | 边界/例外 | 状态 |
|---|---|---|---|---|---|---|
| SET-001 | Provider configuration | [KNOWN] 非敏感配置可持久化，API Key 明文不得写入 Hive，只允许认证密文 envelope | [KNOWN] Draft | [KNOWN] 原子状态记录 | [KNOWN] 日志和错误不得包含凭证 | [KNOWN] 已确认 |
| SET-002 | Credential isolation | [KNOWN] API Key 以稳定 Provider ID 分区 | [KNOWN] ProviderType + API Key | [KNOWN] 单 Provider 凭证 | [KNOWN] 空值表示删除 | [KNOWN] 已确认 |
| SET-003 | Draft commit | [KNOWN] 编辑与测试不改变全局配置 | [KNOWN] 本地 Draft | [KNOWN] 保存成功后一次性更新 | [KNOWN] 偏好与认证密文使用单记录原子提交 | [KNOWN] 已确认 |
| SET-004 | Explicit clear | [KNOWN] Base URL 和模型支持显式清除 | [KNOWN] 空输入 | [KNOWN] `null` 覆盖值 | [KNOWN] 工厂 preset 负责默认值 | [KNOWN] 已确认 |
| SET-005 | Safe fallback | [KNOWN] 本地设置不可读时应用仍以 Ollama 默认配置启动 | [KNOWN] 存储错误 | [KNOWN] 默认配置 | [KNOWN] 不吞掉设置页后续重试能力 | [KNOWN] 已确认 |

## 5. 高严谨业务系统风险基线

| 维度 | 是否涉及 | 已知规则/证据 | 待确认问题 | 风险等级 |
|---|---|---|---|---|
| 领域业务逻辑严谨性 | [KNOWN] 是 | [KNOWN] Provider 选择决定数据发送目标 | [KNOWN] 无 | P1 |
| 金额与关键数值精度 | [KNOWN] 间接涉及 | [INFERRED] 错配 Provider 可能调用不同计费端点 | [KNOWN] 无 | P1 |
| 交易与数据一致性 | [KNOWN] 是 | [KNOWN] 偏好与认证密文一次写入；主密钥只在首次凭证创建时生成 | [KNOWN] 主密钥文件与状态记录仍需统一生命周期 | P1 |
| 状态流转 | [KNOWN] 是 | [KNOWN] Draft、保存中、成功、失败、取消 | [KNOWN] 无 | P1 |
| 幂等与并发 | [KNOWN] 是 | [INFERRED] 重复保存应产生相同最终状态 | [KNOWN] 不支持多个设置窗口并发编辑 | P2 |
| 权限与审计 | [KNOWN] 是 | [KNOWN] 主密钥文件必须独立保存并收紧文件权限 | [KNOWN] 同用户文件读取边界无法抵抗 | P1 |
| 隐私与适用监管/合规 | [KNOWN] 是 | [KNOWN] API Key 属于敏感凭证 | [KNOWN] 无 | P1 |
| 生产变更与回滚 | [KNOWN] 否 | [KNOWN] 仅本地客户端存储，不执行生产操作 | [KNOWN] 无 | NONE |

## 6. 影响范围

| 类型 | 对象 | 影响说明 | 风险等级 |
|---|---|---|---|
| 配置模型 | `lib/core/config/` | [INFERRED] 增加非敏感偏好与仓储边界，修正显式清除语义 | P1 |
| 安全存储 | `lib/core/security/` | [INFERRED] 新增本地主密钥文件与 AES-GCM 凭证仓储 | P1 |
| 状态装配 | `lib/main.dart`, translate providers | [INFERRED] 启动加载并注入仓储和初始配置 | P1 |
| 设置 UI | `lib/features/settings/ui/settings_page.dart` | [KNOWN] 改为本地 Draft、异步保存和脱敏失败提示 | P1 |
| 平台配置 | 应用支持目录、文件权限与备份边界 | [KNOWN] pending 文件原子恢复；macOS/Linux 文件 600、目录 700；Android 禁止备份，iOS 设置不备份属性 | P1 |
| 依赖 | `pubspec.yaml`, `pubspec.lock` | [KNOWN] 使用 `cryptography` 和 `path_provider` | P1 |
| 测试 | `test/core/config/`, settings widget tests | [KNOWN] 新增仓储与交互行为测试 | P1 |

## 7. 测试与发布关注点

| 关注项 | 类型 | 优先级 | 证据或说明 |
|---|---|---|---|
| [KNOWN] API Key 不进入 Hive | 安全测试 | P1 | [KNOWN] fake box 中只允许非敏感字段 |
| [KNOWN] Provider 凭证隔离 | 仓储测试 | P1 | [KNOWN] 使用虚构密钥值 |
| [KNOWN] 清除覆盖字段 | 仓储测试 | P1 | [KNOWN] 保存空值后重建仓储 |
| [KNOWN] Draft 取消/失败 | Widget/状态测试 | P1 | [KNOWN] 全局 Provider 不变化 |
| [KNOWN] 启动加载与回退 | 集成测试 | P1 | [KNOWN] fake 存储成功、缺失、损坏、抛错 |
| [KNOWN] macOS 调试构建 | 平台验证 | P1 | [KNOWN] 本地 AES-GCM 依赖注册与应用启动必须通过 |

## 8. 待确认问题

| 问题 | 风险等级 | 影响 | 建议确认人 | 期望材料 |
|---|---|---|---|---|
| [KNOWN] 加密主密钥来源与解锁方式 | P1 | [KNOWN] 用户确认每次安装生成独立随机主密钥并本地保存，不要求口令解锁 | [KNOWN] 用户 | [KNOWN] 已关闭；接受仅防止直接读取密文的边界 |
| [KNOWN] 负责人和所属版本 | P3 | [KNOWN] 不阻断本地实现，但影响正式验收与发布 | [KNOWN] 项目负责人 | [KNOWN] 版本计划 |

## 9. 2026-07-14 存储方案变更请求

- [KNOWN] 用户要求暂停 `flutter_secure_storage` / Keychain 方案，改为在本地加密保存 Provider 凭证。
- [KNOWN] API Key 仍不得以明文进入普通 Hive、日志、测试数据或文档。
- [COMMON] 密文与主密钥保存在同一可读边界时，只提供混淆，不构成可靠的静态数据保护。
- [KNOWN] 用户拒绝口令解锁，确认使用每次安装独立生成的 256-bit 随机主密钥并与密文分文件保存。
- [KNOWN] 凭证使用带随机 nonce、认证标签和版本字段的 AEAD；Provider ID 作为附加认证数据，防止密文跨 Provider 替换。
- [KNOWN] 主密钥丢失或损坏时禁止静默生成新密钥；设置页提供需要确认的“重置本地凭证”恢复入口。
- [KNOWN] 用户接受该方案不能抵抗已获得同一用户账户文件读取权限的攻击者。
