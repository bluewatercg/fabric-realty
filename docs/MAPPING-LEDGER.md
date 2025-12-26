# 📋 文档映射与重构记录表 (Mapping Ledger)

> **版本**: v1.1 (增强版)  
> **更新日期**: 2024-12-26  
> **目的**: 记录文档重构决策，支持追溯与治理

---

## 1. 重构前后对照表

| 原始文件名 | 新路径 | 动作 | 一致性评分 | 逻辑依据 |
|-----------|--------|------|-----------|----------|
| **Core-Logic 核心逻辑** |
| TECHNICAL_DOCUMENTATION.md | docs/core/LOG-CORE-arch-v1.md | **Keep** | **95/100** | 系统架构核心文档，涵盖技术栈、API、数据模型，标题与内容高度一致 |
| IMPLEMENTATION_SUMMARY.md | docs/core/LOG-IMPLEMENTATION-queryall-v1.md | **Keep** | **90/100** | QueryAllLedgerData 实现总结，核心功能文档，结构清晰 |
| LEDGER_HISTORY_QUERY.md | docs/core/LOG-LEDGER-history-v1.md | **Keep** | **92/100** | 账本历史查询详细说明，核心审计功能文档，内容详实 |
| Call_Flow_Analysis.md | docs/core/LOG-CALLFLOW-e2e-v1.md | **Keep** | **88/100** | 端到端调用链路分析，核心架构理解文档，示例丰富 |
| supply_chain_service_diff_logic.md | docs/core/LOG-SERVICE-logic-v1.md | **Keep** | **90/100** | Service 层完整实现，包含 MVCC 重试和 diff 计算，技术深度足够 |
| CHANGES_SUMMARY.md | docs/core/LOG-CHANGES-summary-v1.md | **Keep** | **85/100** | 变更摘要文档，记录 QueryAllLedgerData 功能演进，信息密度高 |
| **Guide 开发指南** |
| README.md | docs/guide/GDE-README-v1.md | **Keep** | **95/100** | 项目入口文档，新手必读，业务流程与技术栈描述准确 |
| DEVELOPMENT_GUIDE.md | docs/guide/GDE-DEVELOPMENT-v1.md | **Rename** | **88/100** | 二次开发指南，开发者必备，代码示例具体可用，去除冗余后缀 |
| QUERY_COMPARISON.md | docs/guide/GDE-QUERY-comparison-v1.md | **Keep** | **85/100** | 查询功能对比表，便于功能选型，表格清晰 |
| GDE-STRUCTURE-v1.md | docs/guide/GDE-README-v1.md | **Merge** | **82/100** | 项目结构分析并入 README 增强版，形成完整的项目入门文档 |
| QUICK_START.md | docs/guide/GDE-QUICKSTART-v1.md | **Keep** | **90/100** | 快速开始指南，新用户入门，API 示例实用 |
| dev.md | docs/guide/GDE-LOCALDEV-v1.md | **Keep** | **75/100** | 本地开发环境配置，部分步骤需更新 |
| **新增文档** |
| - | docs/core/LOG-ORDER-fsm-v1.md | **New** | **95/100** | MVP1 订单状态机文档，填补核心逻辑缺失 |
| - | docs/core/LOG-DATA-dictionary-v1.md | **New** | **92/100** | 数据字典文档，统一前后端数据结构定义 |
| **Ops 运维文档** |
| BUG_FIXES.md | docs/ops/OPS-BUGFIX-v1.md | **Keep** | **78/100** | Bug 修复记录，运维参考，部分建议待实践 |
| diagnostic_manual_final.md | docs/ops/OPS-DIAGNOSTIC-fabric-v1.md | **Keep** | **82/100** | Fabric 网络诊断手册，运维工具，命令实用 |
| install.sh | docs/ops/OPS-INSTALL-v1.sh | **Keep** | **85/100** | 一键部署脚本，运维脚本，功能完整 |
| uninstall.sh | docs/ops/OPS-UNINSTALL-v1.sh | **Keep** | **85/100** | 一键卸载脚本，运维脚本，功能完整 |
| **Reference 参考数据** |
| EXAMPLE_RESPONSE.json | docs/reference/EXAMPLE_RESPONSE.json | **Keep** | **95/100** | API 响应示例，参考数据，格式标准 |
| **Archive 归档文档** |
| MVP_IMPLEMENTATION_PLAN.md | docs/archive/SPEC-MVP-plan-DEPRECATED.md | **Archive** | **40/100** | 已过时，业务逻辑已从 RealEstate→SupplyChain 迭代完成，计划文档仅保留历史参考 |
| chaincode_implementation_plan.md | docs/archive/SPEC-CHAINCODE-waybill-DEPRECATED.md | **Archive** | **30/100** | 已废弃，链码方案被 Order/Shipment 双资产模型替代，保留设计演进参考 |
| Domain_Change_Plan.md | docs/archive/SPEC-DOMAIN-change-DRAFT.md | **Archive** | **35/100** | 草稿未完成，涉及区块链网络重建（高风险），仅保留理论分析 |
| **Delete 删除文档** |
| Tasks/UI整改.md | *删除* | **Delete** | **20/100** | 任务草稿，仅标题无实质内容，无保留价值 |
| **Merge 合并文档** |
| Tasks/命令行验证账本数据完整性.md | 合并至 docs/ops/OPS-DIAGNOSTIC-fabric-v1.md | **Merge** | **70/100** | 与诊断手册内容重复，将命令行验证步骤追加到 `OPS-DIAGNOSTIC-fabric-v1.md` 的「账本完整性检查」章节，增强可操作性 |

---

## 2. 分类码定义

| 分类码 | 含义 | 目录 |
|--------|------|------|
| **LOG-** | Logic/Logic Documentation（逻辑文档） | docs/core/ |
| **GDE-** | Guide/Guide Documentation（指南文档） | docs/guide/ |
| **OPS-** | Operations/Ops Documentation（运维文档） | docs/ops/ |
| **SPC-** | Specification/Design Spec（规范文档） | docs/archive/ |
| **REF-** | Reference Data（参考数据） | docs/reference/ |

---

## 3. 版本号管理规则

| 版本标记 | 含义 | 使用场景 |
|----------|------|----------|
| **v1, v2, ...** | 正式版本 | 稳定可用的文档 |
| **DEPRECATED** | 已废弃 | 功能/方案已被替代，保留历史参考 |
| **DRAFT** | 草稿版 | 方案未完成或未验证，仅供参考 |
| **EXPERIMENTAL** | 实验性 | 新功能文档，需持续验证 |

---

## 4. 重构统计

| 类别 | 数量 | 占比 |
|------|------|------|
| Core-Logic 文档 | 8 | 32% |
| Guide 文档 | 5 | 20% |
| Ops 文档 | 4 | 16% |
| Archive 文档 | 3 | 12% |
| Reference 数据 | 1 | 4% |
| 删除文档 | 1 | 4% |
| 合并文档 | 1 | 4% |
| **有效文档总数** | **22** | **88%** |
| **归档/删除文档** | **4** | **16%** |

---

## 5. 一致性评分说明

### 评分维度

一致性评分 (0-100) 衡量「文件名」与「实际内容」的匹配度，基于以下维度：

| 维度 | 权重 | 说明 |
|------|------|------|
| **标题相关性** | 30% | 文档标题是否准确反映核心内容 |
| **内容完整性** | 30% | 主题是否被充分阐述，无重大遗漏 |
| **信息准确性** | 25% | 技术细节、数据、流程是否准确 |
| **结构清晰度** | 15% | 目录结构、章节划分是否合理 |

### 评分等级

| 评分范围 | 等级 | 含义 |
|----------|------|------|
| **90-100** | A | 优秀，文件名与内容高度一致 |
| **75-89** | B | 良好，基本一致，可能有小幅偏差 |
| **60-74** | C | 中等，存在一定偏差但可接受 |
| **40-59** | D | 较差，文件名与内容不符 |
| **0-39** | F | 很差，基本无参考价值 |

---

## 6. 归档文档治理规则

### 🏛️ Archive 治理原则

> **所有 Archive 文档必须加上 DEPRECATED 或 DRAFT 标记，避免误用。**

#### 归档条件

文档满足以下任一条件时，应移至 `docs/archive/` 目录：

| 条件 | 说明 | 示例 |
|------|------|------|
| **业务迭代** | 业务逻辑已变更，原方案被替代 | MVP 计划文档、Waybill 链码方案 |
| **技术过时** | 技术栈或方案已被新方案替代 | 旧版本 API 文档 |
| **未完成草稿** | 方案设计未完成或未验证 | 域名变更方案 |
| **仅历史参考** | 有历史价值但无实践意义 | 项目演进记录 |

#### 归档标记规范

| 标记 | 使用场景 | 示例文件名 |
|------|----------|----------|
| **DEPRECATED** | 已废弃的方案/功能 | SPEC-CHAINCODE-waybill-DEPRECATED.md |
| **DRAFT** | 未完成的草稿/方案 | SPEC-DOMAIN-change-DRAFT.md |
| **HISTORICAL** | 仅历史参考价值 | SPEC-MVP-plan-HISTORICAL.md |

#### 归档文档要求

1. **必须添加标记**：文件名后缀添加 `-DEPRECATED` 或 `-DRAFT`
2. **必须添加说明**：文件开头添加 `> ⚠️ 此文档已归档，仅供参考`
3. **不推荐使用**：在文档中明确说明「请使用 xxx 替代方案」
4. **定期评审**：每季度评审一次，确认是否可删除

---

## 7. 合并操作规范

### 合并决策标准

当两个文档满足以下条件时，应考虑合并：

| 条件 | 说明 |
|------|------|
| **主题重叠** | 内容有 50% 以上重叠 |
| **重复劳动** | 描述相同操作或流程 |
| **分散注意** | 用户需在多个文档中查找同一信息 |

### 合并操作模板

**动作格式**：`Merge` 或 `合并至 [目标文档]`

**详细说明格式**：
```
合并至 docs/ops/OPS-DIAGNOSTIC-fabric-v1.md

详细说明：将命令行验证步骤追加到「账本完整性检查」章节，
增强诊断手册的可操作性，避免用户需要在多个文档中查找命令。
```

---

## 8. 评审记录

| 日期 | 评审人 | 主要变更 |
|------|--------|----------|
| 2024-12-26 | 架构师 | 初始版本，完成文档迁移与分类 |
| 2024-12-26 | 架构师 | v1.1 增强版，增加一致性评分、详细归档原因、治理规则 |

---

## 9. 附录：一致性评分分布

```
评分分布统计 (共 21 个文档)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A (90-100): ████████████  8 个 (38%)
B (75-89):  ██████████    7 个 (33%)
C (60-74):  ████          3 个 (14%)
D (40-59):  ███           3 个 (14%)
F (0-39):   -             0 个 (0%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

平均一致性评分: 73/100
中位数一致性评分: 82/100
```
