# Scope 需求梳理、准入与 TDD 计划

## 1. 建议结论

| 项 | 内容 |
|---|---|
| 建议结论 | [KNOWN] `TDD_INPUT_READY` |
| 最高风险等级 | [KNOWN] P1 |
| 一句话依据 | [KNOWN] 用户确认无口令本地 AEAD、随机安装密钥、安全边界和损坏处理规则 |
| 下一步建议 | [KNOWN] 按 S6 至 S8 进入 `hicode:tdd`，完成本地 AEAD 加密实现 |

## 2. 依据与输入缺口

| 材料 | 来源 | 是否读取 | 关键证据 | 缺口 |
|---|---|---|---|---|
| 项目规则 | `AGENTS.md`, `docs/rules/coding_rules.md` | [KNOWN] 是 | [KNOWN] API Key 明文不得进入 Hive；批准的认证密文必须有安全设计与测试 | [KNOWN] 无 |
| 项目上下文 | `docs/DOMAIN_KNOWLEDGE.md`, `docs/PROJ_CONTEXT.md` | [KNOWN] 是 | [KNOWN] 设置当前只驻留 Riverpod，`ai_config` box 未读写 | [KNOWN] 负责人待确认 |
| 当前实现 | config、settings UI、main、translate providers | [KNOWN] 是 | [KNOWN] 保存只更新内存；切换 Provider 保留旧凭证与覆盖字段 | [KNOWN] 无 |
| 当前测试 | settings、controller、widget tests | [KNOWN] 是 | [KNOWN] 测试只验证内存状态，没有重启持久化与凭证隔离 | [KNOWN] 无 |
| 本地加密实现依据 | `cryptography` AES-GCM API、`path_provider` 应用支持目录 | [KNOWN] 是 | [KNOWN] 使用 256-bit 随机主密钥、随机 nonce、认证标签和 Provider AAD | [KNOWN] 真机平台密钥隔离不在自动化单元测试内 |
| 用户确认 | 当前对话 | [KNOWN] 是 | [KNOWN] 用户确认 `settings-persistence` 并同意推荐优化方案 | [KNOWN] 无 |

## 3. 需求准入评审

| 项 | 内容 |
|---|---|
| 准入结论 | [KNOWN] `NO_BLOCKING_GAPS` |
| 需求分析输入 | [KNOWN] 目标、范围、验收、隐私边界、失败策略和平台边界明确 |
| 证据缺口 | [KNOWN] 负责人、所属版本和真机安全存储验证待后续确认，不阻断本地 TDD |

## 4. 需求分析与范围边界

| 项 | 内容 |
|---|---|
| 需求目标 | [KNOWN] 设置跨重启持久化，API Key 按 Provider 安全隔离，设置页保存前不污染生效配置 |
| 范围内 | [KNOWN] Hive 原子设置记录、本地 AES-GCM 凭证、启动加载、Draft UI、字段清除、错误回退、测试与平台配置 |
| 范围外 | [KNOWN] 翻译缓存治理、凭证同步/导入导出、生物识别、多配置档案、真实收费端点 |
| 非目标 | [KNOWN] 不把 API Key 写入 Hive，不读取任何真实密钥，不改变 Provider 协议 |
| 验收标准 | [KNOWN] 重启恢复；Hive 无明文密钥；Provider 凭证隔离；取消无副作用；空字段可清除；失败不切换全局状态 |
| feature_context 更新 | [KNOWN] 已创建 |
| ADR 处理 | [INFERRED] 不需要；第三方插件封装在可替换仓储接口后，不构成难逆公共契约 |

## 5. 设计树方案

| 节点 | 类型 | 触发条件/输入 | 处理方案 | 输出/状态变化 | 范围边界 | 验证点 | 风险等级 |
|---|---|---|---|---|---|---|---|
| ROOT | 业务目标 | [KNOWN] 用户配置 Provider | [KNOWN] 设置/凭证分仓并通过仓储装配 | [KNOWN] 重启恢复且凭证不明文落盘 | [KNOWN] 单一当前 Provider | [KNOWN] 端到端仓储测试 | P1 |
| MAIN-1 | 启动 | [KNOWN] 本地存储已初始化 | [INFERRED] 读取偏好和当前 Provider 凭证 | [KNOWN] 初始配置注入 Riverpod | [KNOWN] 失败回退 Ollama | [KNOWN] load/fallback tests | P1 |
| MAIN-2 | Draft | [KNOWN] 打开设置 | [KNOWN] 本地持有全部输入 | [KNOWN] 全局状态不变 | [KNOWN] 单设置窗口 | [KNOWN] cancel test | P1 |
| MAIN-3 | 切换 Provider | [KNOWN] Draft 选择类型 | [KNOWN] 读取目标 Provider 凭证并清除 endpoint/model 覆盖 | [KNOWN] Draft 更新 | [KNOWN] 不保存即不生效 | [KNOWN] isolation test | P1 |
| MAIN-4 | 保存 | [KNOWN] Draft 合法 | [KNOWN] 一次 Hive 写提交偏好与认证密文，成功后更新全局状态 | [KNOWN] 新配置生效 | [KNOWN] 主密钥只在首次凭证创建时单独生成 | [KNOWN] success/failure tests | P1 |
| MAIN-5 | 测试连接 | [KNOWN] 用户点击测试 | [KNOWN] 临时 Provider 使用 Draft | [KNOWN] 连接提示 | [KNOWN] 不调用真实端点的自动化测试 | [KNOWN] state isolation test | P1 |
| BRANCH-1 | 空值 | [KNOWN] key/base/model 为空 | [KNOWN] 删除凭证或覆盖 | [KNOWN] preset/未配置状态 | [KNOWN] 其他 Provider 不变 | [KNOWN] clear tests | P1 |
| BRANCH-2 | 存储失败 | [KNOWN] 任一仓储失败 | [KNOWN] 不切换全局状态，显示脱敏错误 | [KNOWN] Draft 保留可重试 | [KNOWN] 不承诺跨仓储持久化原子回滚 | [KNOWN] fake error tests | P1 |
| BRANCH-3 | 数据损坏 | [KNOWN] 非法 schema/type/index | [INFERRED] 回退默认值并允许覆盖保存 | [KNOWN] 应用可用 | [KNOWN] 不暴露原始异常 | [KNOWN] malformed test | P1 |

## 6. 澄清问题队列

| 问题 | 状态 | 推荐答案 | 推荐理由 | 影响 | 建议确认人 |
|---|---|---|---|---|---|
| [KNOWN] feature-id | [KNOWN] 已关闭 | [KNOWN] `settings-persistence` | [KNOWN] 用户明确确认 | [KNOWN] 文档与实现路径固定 | [KNOWN] 用户 |
| [KNOWN] 安全存储方案 | [KNOWN] 已关闭 | [KNOWN] 本地随机主密钥文件 + AES-256-GCM + 可替换仓储接口 | [KNOWN] 用户确认无口令本地加密方案 | [KNOWN] 同一用户可同时读取密钥文件和密文，边界已确认 | [KNOWN] 用户 |
| [KNOWN] 设置原子性 | [KNOWN] 已关闭 | [KNOWN] 偏好与认证密文使用单一版本化状态记录一次提交 | [KNOWN] 修复审查发现的部分提交问题 | [KNOWN] 主密钥首次创建仍单独执行并有 pending 恢复 | [KNOWN] 研发负责人 |
| [KNOWN] 负责人和版本 | [KNOWN] 待负责人确认 | [KNOWN] 后续补充 | [KNOWN] 不影响本地行为实现 | [KNOWN] 影响正式验收和发布 | [KNOWN] 项目负责人 |

## 7. 关键规则与影响范围

| 对象 | 影响说明 | 证据来源 | 确认状态 | 风险等级 |
|---|---|---|---|---|
| API Key | [KNOWN] 仅以 AES-256-GCM 认证密文保存，按稳定 Provider ID 隔离 | [KNOWN] 项目规则与用户确认 | [KNOWN] 已确认 | P1 |
| Hive preferences | [KNOWN] 只保存 schema/provider/base/model | [KNOWN] 当前 Hive 基础设施 | [KNOWN] 已确认 | P1 |
| Riverpod state | [KNOWN] 启动注入，保存成功后切换 | [KNOWN] 当前状态边界 | [KNOWN] 已确认 | P1 |
| 本地密钥文件权限 | [KNOWN] macOS/Linux 收紧为 600；移动端依赖应用私有目录 | [KNOWN] 实现与平台目录模型 | [KNOWN] 已确认范围 | P1 |

## 8. 风险与阻断建议

| 风险 | 等级 | 证据 | 建议动作 | 建议确认人 |
|---|---|---|---|---|
| [KNOWN] 凭证误入 Hive | P1 | [KNOWN] 现有 `AIConfig` 是 Hive model 且含 apiKey | [KNOWN] 新偏好模型不得包含 key；测试 box key 集合 | [KNOWN] 研发/安全负责人 |
| [KNOWN] Provider 间复用凭证 | P1 | [KNOWN] 当前单一 apiKey 随 Provider 切换保留 | [KNOWN] 安全存储 key 加稳定 Provider ID | [KNOWN] 研发负责人 |
| [KNOWN] 跨仓储部分成功 | P1 | [KNOWN] 已由单一状态记录原子写修复 | [KNOWN] 保留失败时旧状态不变测试 | [KNOWN] 研发负责人 |
| [KNOWN] 同用户文件读取风险 | P1 | [KNOWN] 无口令方案无法防御同时取得密钥文件和密文的同用户攻击者 | [KNOWN] 保持密钥文件与密文分离并限制文件权限；如需更强边界再引入 OS vault/口令 | [KNOWN] 研发负责人 |
| [KNOWN] 移动端备份边界 | P1 | [KNOWN] Android 已禁止应用备份；iOS 已加入文件不备份调用 | [KNOWN] 移动工具链可用后执行构建与真机恢复验证 | [KNOWN] 研发负责人 |

[KNOWN] P1 阻断状态：无；全部 P1 风险已有实现切片和验证点。

## 9. 推荐设计树方案与取舍

| 方案 | 是否推荐 | 主干逻辑 | 分支处理 | 范围边界 | 收益 | 代价或风险 | 不选原因 |
|---|---|---|---|---|---|---|---|
| A. 单一 Hive 状态记录（偏好 + AES-GCM envelopes）+ 独立主密钥文件 + repository | [KNOWN] 是 | [KNOWN] 一次写入原子提交当前偏好与所有 Provider 认证密文 | [KNOWN] 存储失败保留旧状态 | [KNOWN] 单当前 Provider | [KNOWN] 修复部分提交且保持明文不落盘 | [KNOWN] 同用户可读取密钥与密文 | [KNOWN] 已实现 |
| B. 全部字段加密后写入 Hive | [KNOWN] 否 | [INFERRED] 自管加密 key 与 box | [INFERRED] 需要额外主密钥生命周期 | [KNOWN] 本地单库 | [INFERRED] 可实现事务式写入 | [KNOWN] 非敏感字段加密无额外安全收益，主密钥问题仍存在 | [KNOWN] 增加无必要复杂度 |
| C. 全部只用系统安全存储 | [INFERRED] 备选 | [INFERRED] provider/base/model/key 都写安全存储 | [INFERRED] 每字段 key-value | [KNOWN] 小规模设置可行 | [INFERRED] 单依赖 | [INFERRED] 非敏感结构、schema 与迁移表达较弱 | [KNOWN] 不利于配置演进和测试 |

## 10. 设计树到 TDD 任务计划

| 项 | 内容 |
|---|---|
| 任务计划结论 | [KNOWN] `TDD_INPUT_READY` |
| 下一步路由 | [KNOWN] `hicode:tdd` |
| 未覆盖设计树节点 | [KNOWN] 无 |

### TDD 切片

| 任务 | 目标与设计树节点 | 输入 | 范围内 / 范围外 | 涉及对象 | TDD 起点与测试重点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|---|---|
| S1 非敏感偏好仓储 | MAIN-1、BRANCH-1/3 | [KNOWN] Hive box 与 ProviderType | [KNOWN] 内：schema/provider/base/model；外：API Key | config repository、unit tests | [KNOWN] 先测重建恢复、清除、损坏回退和 box 中无 key | [KNOWN] focused tests | [KNOWN] 若必须把密钥放入模型则停止 |
| S2 Provider 凭证仓储 | MAIN-1/3、BRANCH-1/2 | [KNOWN] AES-GCM 与主密钥接口 | [KNOWN] 内：read/write/delete by Provider；外：生物识别、同步 | security store、fake adapter tests | [KNOWN] 先测隔离、删除、错误传播 | [KNOWN] focused tests | [KNOWN] 算法或平台文件系统不满足认证/原子要求时停止 |
| S3 组合仓储与启动 | ROOT、MAIN-1/4、BRANCH-2/3 | [KNOWN] S1/S2 接口 | [KNOWN] 内：load/save、初始注入、失败回退；外：跨存储事务 | repository、main/providers tests | [KNOWN] 先测 load composition、全局状态延迟提交 | [KNOWN] focused tests | [KNOWN] 需要读取真实凭证时停止 |
| S4 设置页 Draft | MAIN-2/3/4/5、BRANCH-1/2 | [KNOWN] S3 repository | [KNOWN] 内：local draft、provider switch、test/save/cancel；外：多窗口并发 | settings UI/widget tests | [KNOWN] 先测取消、失败、清除和 provider key load | [KNOWN] widget tests | [KNOWN] UI 必须持有插件类型时停止重构边界 |
| S5 平台装配与回归 | ROOT | [KNOWN] 项目平台配置与 cryptography/path_provider 文档 | [KNOWN] 内：依赖、格式/analyze/test/macOS build；外：移动真机发布验证 | pubspec/platform configs | [KNOWN] 构建失败即修复平台配置 | [KNOWN] full checks + macOS debug build | [KNOWN] 需要生产签名或凭证时停止 |

## 11. TDD 输入与测试重点

| 设计树节点 | 场景 | 类型 | 优先级 | 数据要求 | 对应任务 |
|---|---|---|---|---|---|
| MAIN-1 | [KNOWN] 重建仓储恢复当前 Provider 设置 | repository | P1 | [KNOWN] 临时/内存 box，无真实配置 | S1/S3 |
| MAIN-3 | [KNOWN] Qwen 与 OpenAI 使用不同虚构 key | security | P1 | [KNOWN] `key-qwen-test` 等虚构值 | S2/S4 |
| MAIN-4 | [KNOWN] 单记录成功提交后才更新状态 | state/widget | P1 | [KNOWN] 可控 fake store | S3/S4 |
| MAIN-5 | [KNOWN] 测试连接不修改全局状态 | widget | P1 | [KNOWN] fake Provider | S4 |
| BRANCH-1 | [KNOWN] 空 key 删除、空 endpoint/model 清除 | repository/widget | P1 | [KNOWN] 无真实凭证 | S1/S2/S4 |
| BRANCH-2 | [KNOWN] 任一写入失败 | failure | P1 | [KNOWN] 抛脱敏 fake error | S2/S3/S4 |
| BRANCH-3 | [KNOWN] 非法 schema/provider index | migration | P1 | [KNOWN] 人工损坏 map | S1/S3 |

## 12. ADR 判断

| 项 | 内容 |
|---|---|
| 是否需要 ADR | [INFERRED] 否 |
| 判断理由 | [INFERRED] 插件被仓储接口隔离，Hive 和安全存储适配器可替换；没有形成难逆公共契约 |
| 涉及决策点 | [KNOWN] 若未来引入账号同步、凭证云同步或硬件强制认证，应另立 ADR |

## 13. 知识沉淀与上下文更新

| 目标文档 | 更新类型 | 内容摘要 | 处理方式 | 确认状态 |
|---|---|---|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 待实现后更新 | [KNOWN] 增加设置偏好、Provider 凭证和 Draft 规则 | [KNOWN] 实现验证后写入 | [KNOWN] 用户已确认需求 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 待实现后更新 | [KNOWN] Feature 索引与存储模块 | [KNOWN] 实现验证后写入 | [KNOWN] 用户已确认需求 |
| `docs/adr/` | [KNOWN] 跳过 | [INFERRED] 当前不满足难逆条件 | [KNOWN] 不创建草稿 | [KNOWN] 已评估 |

## 14. 文档处理清单

| 文档 | 处理结果 |
|---|---|
| `docs/features/settings-persistence/feature_context.md` | [KNOWN] 已创建 |
| `docs/features/settings-persistence/scope-plan.md` | [KNOWN] 已创建，结论为 `TDD_INPUT_READY` |
| `docs/features/settings-persistence/tdd-report.md` | [KNOWN] 待 TDD 阶段创建 |
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 暂不更新，待实现证据 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 暂不更新，待实现证据 |

## 15. 2026-07-14 加密本地存储变更评审

| 项 | 内容 |
|---|---|
| 变更请求 | [KNOWN] 停用系统 Keychain 方案，Provider 凭证改为加密本地保存 |
| 当前阻断 | [KNOWN] 无；用户接受无口令方案的安全上限 |
| 风险等级 | [KNOWN] P1 |
| 确认方案 | [KNOWN] 每次安装生成独立 256-bit 随机主密钥并与密文分文件保存；AES-256-GCM 使用随机 nonce、认证标签、版本字段和 Provider AAD |
| 不推荐方案 | [KNOWN] 硬编码密钥、与密文同目录保存随机密钥、从固定设备信息直接派生密钥 |
| 安全边界 | [KNOWN] 防止直接读取 Hive/凭证文件得到明文；不抵抗同一用户账户下能同时读取密钥与密文的攻击者 |
| 准入结论 | [KNOWN] `TDD_INPUT_READY` |

### 替换设计树

| 节点 | 触发条件 | 处理 | 可观察结果 | 验证 | 风险 |
|---|---|---|---|---|---|
| MAIN-6 | [KNOWN] 首次启动且主密钥文件不存在 | [KNOWN] 使用密码学安全随机源生成 32 bytes，独占创建并持久化 | [KNOWN] 后续重启读取相同密钥 | [KNOWN] 临时目录重建测试 | P1 |
| MAIN-7 | [KNOWN] 保存 Provider 凭证 | [KNOWN] AES-256-GCM 加密，随机 nonce，Provider key 作为 AAD | [KNOWN] 本地记录只有版本、nonce、ciphertext、MAC | [KNOWN] 明文缺失与往返测试 | P1 |
| MAIN-8 | [KNOWN] 读取 Provider 凭证 | [KNOWN] 校验版本和认证标签后解密 | [KNOWN] 返回当前 Provider 明文，仅驻留运行时内存 | [KNOWN] 跨 Provider 替换与篡改测试 | P1 |
| BRANCH-6 | [KNOWN] 主密钥文件长度错误或读取失败 | [KNOWN] 不重生成、不覆盖密文、向上抛脱敏领域错误 | [KNOWN] 保存失败且旧记录不变 | [KNOWN] 损坏 key fixture | P1 |
| BRANCH-7 | [KNOWN] 密文版本未知、字段损坏或 MAC 不匹配 | [KNOWN] 不返回部分明文，向上抛领域错误 | [KNOWN] UI 显示通用失败，可重新配置 | [KNOWN] tamper fixtures | P1 |

### 新增 TDD 切片

| 任务 | 目标 | 范围内 | TDD 起点 | 验证方式 | 停止条件 |
|---|---|---|---|---|---|
| S6 安装主密钥 | [KNOWN] 生成、复用并验证 256-bit 随机主密钥 | [KNOWN] 本地应用私有目录；不含口令和系统 Keychain | [KNOWN] 首次生成、重建复用、损坏拒绝测试 | [KNOWN] focused unit tests | [KNOWN] 需要读取设备或生产身份时停止 |
| S7 AEAD 凭证仓储 | [KNOWN] Provider 隔离加密、解密、删除与防篡改 | [KNOWN] AES-256-GCM envelope；不改 Provider 协议 | [KNOWN] 明文不落盘、round-trip、AAD swap、tamper 测试 | [KNOWN] focused repository tests | [KNOWN] 算法不提供认证标签时停止 |
| S8 装配与迁移 | [KNOWN] 启动改用本地 AEAD，移除 Keychain 依赖和平台 entitlement | [KNOWN] 当前开发版本无已验证旧方案凭证迁移 | [KNOWN] 设置保存/重启恢复和依赖扫描 | [KNOWN] full tests + macOS build/startup | [KNOWN] 发现真实历史凭证迁移要求时停止 |
