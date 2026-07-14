# AITrans Agent Guide

## Project facts

- [KNOWN] This repository contains the `aitrans` Flutter application.
- [KNOWN] The product brief targets macOS, iOS, and Android.
- [KNOWN] Application code lives in `lib/`; tests live in `test/`.
- [KNOWN] Use `flutter analyze` for static analysis and `flutter test` for tests.
- [KNOWN] Do not read or expose `.env*`, credentials, API keys, tokens, production configuration, production data, or production logs.
- [KNOWN] Preserve user-owned worktree changes and generated artifacts unless the user explicitly authorizes changing them.

## Local engineering rules

- [KNOWN] Read `docs/rules/coding_rules.md` before changing application code.
- [KNOWN] Read `docs/DOMAIN_KNOWLEDGE.md` and `docs/PROJ_CONTEXT.md` before making product or architectural assumptions.
- [KNOWN] Treat `aitrans-prd.md` as the current product brief, not as proof that every described feature is implemented.
- [KNOWN] Prefer focused tests for changed behavior, then run the relevant broader checks.
- [KNOWN] Never hand-edit generated Dart files such as `*.g.dart`; update their source and regenerate them with the project's generator.

## hicode 使用顺序

1. [KNOWN] 先判断目标项目是否已初始化：入口文件是否有本 hicode section，`docs/rules/`、`docs/DOMAIN_KNOWLEDGE.md`、`docs/PROJ_CONTEXT.md` 是否存在。
2. [KNOWN] 未初始化或入口缺失时，优先使用 `hi` 诊断；用户明确要求初始化时使用 `hicode:init`。
3. [KNOWN] 已初始化时，按任务意图选择一个 hicode Skill 执行；意图不清时只问一个问题，不猜测业务规则。
4. [KNOWN] 执行 Skill 前读取目标项目事实文档；目标文档缺失时标注证据缺口，不用模板当事实。
5. [KNOWN] 输出只给建议、证据、风险和下一步动作，不给审批、合并、发布或生产操作许可。

## hicode Skill 路由

| 用户意图或任务信号 | 使用 Skill | 主要产物 |
|---|---|---|
| [KNOWN] 首次使用、状态诊断、不确定用哪个 hicode 能力 | `hi` | 初始化状态、路由建议 |
| [KNOWN] 初始化入口、补齐项目规则、创建项目上下文 | `hicode:init` | 入口 hicode section、`docs/rules/`、项目级上下文 |
| [KNOWN] 需求评审、范围界定、澄清问题、任务拆分 | `hicode:scope` | `docs/features/<feature-id>/` 下的 Scope 产物 |
| [KNOWN] TDD、测试先行、复现 bug、受控实现 | `hicode:tdd` | `docs/features/<feature-id>/tdd-report.md` |
| [KNOWN] 代码审查、diff/MR/PR/提交前检查、专项风险审查 | `hicode:review` | `doc/versions/review-report-<YYYYMMDD-HHmm>.md` |
| [KNOWN] 分支发布分析、验证计划、回滚计划、发布风险判断 | `hicode:release` | `doc/versions/release-report-<YYYYMMDD-HHmm>.md` |

## hicode 读取材料

1. [KNOWN] 项目规则：`AGENTS.md` 和 `docs/rules/`。
2. [KNOWN] 长期上下文：`docs/DOMAIN_KNOWLEDGE.md`、`docs/PROJ_CONTEXT.md`、`docs/adr/`。
3. [KNOWN] 单需求上下文：`docs/features/<feature-id>/`；`feature-id` 不明确时先查 `docs/PROJ_CONTEXT.md` 的 Feature 索引。
4. [KNOWN] Review/Release 证据：相关 diff、分支、Commit、MR/PR、测试、CI、配置、脚本、缺陷和既有 `doc/versions/` 报告。

[KNOWN] 不得读取 `.env*`、密钥文件、生产配置、生产凭证、未脱敏客户信息、未脱敏生产数据或生产日志原文。

## hicode 文档路径

| 路径 | 用途 |
|---|---|
| `docs/DOMAIN_KNOWLEDGE.md` | [KNOWN] 领域术语、业务域和可复用业务规则 |
| `docs/PROJ_CONTEXT.md` | [KNOWN] 项目定位、Feature 索引、模块结构、核心流程、接口依赖和历史风险 |
| `docs/adr/` | [KNOWN] 架构、治理或难逆决策记录 |
| `docs/rules/` | [KNOWN] 项目本地规则；只能补充或加严 hicode 规则 |

## hicode 单需求文档生命周期

- [KNOWN] 单需求目录固定为 `docs/features/<feature-id>/`；`feature-id` 不明确时先查 Feature 索引，仍不明确时询问用户，不得编造。
- [KNOWN] Scope 阶段可创建或更新 `feature_context.md` 和 `scope-plan.md`；证据不足时不得输出 `TDD_INPUT_READY`。
- [KNOWN] TDD 阶段可创建或更新 `tdd-report.md`，必要时补充 `feature_context.md` 的过程证据；缺少 Scope 输入时应返回 Scope 或只做测试设计。
- [KNOWN] Review 和 Release 报告属于项目级或分支级证据，统一写入 `doc/versions/`，文件名包含本地时间戳 `YYYYMMDD-HHmm`。

## hicode 写入与安全边界

1. [KNOWN] 只写已确认事实、证据、待确认问题、风险判断、真实命令和真实结果。
2. [KNOWN] 未确认内容写“待确认”；长期上下文、Feature 索引和正式 ADR 只能在负责人确认后更新。
3. [KNOWN] 阶段报告不代表最终审批、合并许可、发布许可或生产操作授权。
4. [KNOWN] 禁止读取或输出密钥、Token、Cookie、Session、连接串、生产账号、生产 IP、生产配置、生产凭证、未脱敏客户信息、未脱敏生产数据或生产日志原文。
5. [KNOWN] 禁止连接生产、执行生产 SQL、修改生产配置、自动提交、自动推送、自动合并、自动发布、自动回滚、删除测试、降低断言、跳过 Review 或替代负责人审批。
