# 📋 文档映射与重构记录表 (Mapping Ledger)

## 重构前后对照

| 原始文件名 | 新路径 | 动作 | 逻辑依据 |
|-----------|--------|------|----------|
| TECHNICAL_DOCUMENTATION.md | docs/core/LOG-CORE-arch-v1.md | **Keep** | 系统架构核心文档，涵盖技术栈、API、数据模型 |
| IMPLEMENTATION_SUMMARY.md | docs/core/LOG-IMPLEMENTATION-queryall-v1.md | **Keep** | QueryAllLedgerData 实现总结，核心功能文档 |
| LEDGER_HISTORY_QUERY.md | docs/core/LOG-LEDGER-history-v1.md | **Keep** | 账本历史查询详细说明，核心审计功能文档 |
| Call_Flow_Analysis.md | docs/core/LOG-CALLFLOW-e2e-v1.md | **Keep** | 端到端调用链路分析，核心架构理解文档 |
| supply_chain_service_diff_logic.md | docs/core/LOG-SERVICE-logic-v1.md | **Keep** | Service 层完整实现，包含 MVCC 重试和 diff 计算 |
| CHANGES_SUMMARY.md | docs/core/LOG-CHANGES-summary-v1.md | **Keep** | 变更摘要文档，记录 QueryAllLedgerData 功能演进 |
| README.md | docs/guide/GDE-README-v1.md | **Keep** | 项目入口文档，新手必读 |
| DEVELOPMENT_GUIDE.md | docs/guide/GDE-DEVELOPMENT-guide-v1.md | **Keep** | 二次开发指南，开发者必备 |
| QUERY_COMPARISON.md | docs/guide/GDE-QUERY-comparison-v1.md | **Keep** | 查询功能对比表，便于功能选型 |
| PROJECT_STRUCTURE.md | docs/guide/GDE-STRUCTURE-v1.md | **Keep** | 项目结构分析，架构概览 |
| QUICK_START.md | docs/guide/GDE-QUICKSTART-v1.md | **Keep** | 快速开始指南，新用户入门 |
| dev.md | docs/guide/GDE-LOCALDEV-v1.md | **Keep** | 本地开发环境配置 |
| BUG_FIXES.md | docs/ops/OPS-BUGFIX-v1.md | **Keep** | Bug 修复记录，运维参考 |
| diagnostic_manual_final.md | docs/ops/OPS-DIAGNOSTIC-fabric-v1.md | **Keep** | Fabric 网络诊断手册，运维工具 |
| install.sh | docs/ops/OPS-INSTALL-v1.sh | **Keep** | 一键部署脚本，运维脚本 |
| uninstall.sh | docs/ops/OPS-UNINSTALL-v1.sh | **Keep** | 一键卸载脚本，运维脚本 |
| EXAMPLE_RESPONSE.json | docs/reference/EXAMPLE_RESPONSE.json | **Keep** | API 响应示例，参考数据 |
| MVP_IMPLEMENTATION_PLAN.md | docs/archive/SPEC-MVP-plan-DEPRECATED.md | **Archive** | MVP 实施计划已过时，保留参考 |
| chaincode_implementation_plan.md | docs/archive/SPEC-CHAINCODE-waybill-DEPRECATED.md | **Archive** | Waybill 链码方案已废弃，保留参考 |
| Domain_Change_Plan.md | docs/archive/SPEC-DOMAIN-change-DRAFT.md | **Archive** | 域名变更方案未完成，保留草稿 |
| Tasks/UI整改.md | *删除* | **Delete** | 任务草稿，无实际内容 |
| Tasks/命令行验证账本数据完整性.md | *合并至* docs/ops/OPS-DIAGNOSTIC-fabric-v1.md | **Merge** | 与诊断手册内容重复，已合并 |

---

## 分类码定义

| 分类码 | 含义 | 目录 |
|--------|------|------|
| LOG- | Logic/Logic Documentation（逻辑文档） | docs/core/ |
| GDE- | Guide/Guide Documentation（指南文档） | docs/guide/ |
| OPS- | Operations/Ops Documentation（运维文档） | docs/ops/ |
| SPC- | Specification/Design Spec（规范文档） | docs/archive/ |
| REF- | Reference Data（参考数据） | docs/reference/ |

---

## 版本号管理规则

- **v1**: 初始版本，迁移自原始文档
- **v2**: 重大更新，增加新功能说明
- **DEPRECATED**: 已废弃但保留参考
- **DRAFT**: 草稿版，待完善

---

## 重构统计

| 类别 | 数量 |
|------|------|
| Core-Logic 文档 | 6 |
| Guide 文档 | 6 |
| Ops 文档 | 4 |
| Archive 文档 | 3 |
| Reference 数据 | 1 |
| 删除文档 | 1 |
| 合并文档 | 1 |
| **总计** | **21** |
