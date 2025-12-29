# MVP 二开规划：数字运单管理系统

> ⚠️ **此文档已归档，仅供参考**
>
> **废弃原因**：本计划描述的 RealEstate→SupplyChain 转型已完成，业务逻辑已从房产交易迭代为汽配供应链系统。
>
> **当前状态**：请参考 `docs/core/LOG-CORE-arch-v1.md` 了解当前汽配供应链系统架构。

---

本项目将基于现有的房地产交易系统进行二次开发，实现 **MVP1（核心企业签发数字运单）** 和 **MVP2（承运方确认运单）** 功能。我们将复用现有的三组织（Org1, Org2, Org3）架构，并将其业务逻辑从"房产交易"转向"物流/供应链运单流转"。

## 业务角色映射

为了尽可能复用现有网络结构，我们进行如下角色映射：
- **Org1 (不动产登记机构) -> 核心企业 (Core Enterprise)**: 负责运单的初始录入与签发。
- **Org2 (银行) -> 承运方 (Carrier)**: 负责运单的核实与确认。
- **Org3 (交易平台) -> 监管/平台方 (Platform)**: 提供系统支持，并对数据完整性进行算法背书（Hash）。

## 方案设计

### 1. 智能合约层 (Chaincode)

#### 1.1 数据模型重构
原方案采用 `RealEstate` 资产类型，新方案将替换为 `Waybill`（运单）资产。

**运单模型结构：**
```go
type Waybill struct {
    ID           string        `json:"id"`           // 运单号
    Sender       string        `json:"sender"`       // 发货方（核心企业）
    CarrierID    string        `json:"carrierId"`    // 承运方ID
    CargoDetails string        `json:"cargoDetails"` // 货物详情
    Status       WaybillStatus `json:"status"`       // 当前状态
    CreateTime   time.Time     `json:"createTime"`   // 创建时间
    UpdateTime   time.Time     `json:"updateTime"`   // 更新时间
}

type WaybillStatus string

const (
    PENDING  WaybillStatus = "PENDING"  // 待承运方确认
    ACTIVE   WaybillStatus = "ACTIVE"   // 已确认，运输中
    FINISHED WaybillStatus = "FINISHED" // 已送达/完成
)
```

#### 1.2 合约方法设计
- `CreateWaybill` - 核心企业签发运单（仅 Org1MSP 可调用）
- `ConfirmWaybill` - 承运方确认运单（仅 Org2MSP 可调用）
- `QueryWaybill` - 查询单个运单（所有组织可调用）
- `QueryWaybillList` - 分页查询运单列表

### 2. 后端服务层 (Application Server)

#### 2.1 组织映射调整
```go
// 原配置
ORG1 = "RealEstate Agency"
ORG2 = "Bank"
ORG3 = "Trading Platform"

// 新配置
ORG1 = "Core Enterprise (OEM)"
ORG2 = "Carrier"
ORG3 = "Logistics Platform"
```

#### 2.2 API 路由调整
```go
// 原路由
/api/agency/property/create
/api/bank/loan/approve
/api/platform/query/all

// 新路由
/api/oem/waybill/create      # OEM 签发运单
/api/carrier/waybill/confirm  # Carrier 确认运单
/api/platform/query/all       # Platform 查询全部
```

### 3. 前端界面调整

#### 3.1 页面角色映射
| 原页面 | 新页面 | 角色映射 |
|--------|--------|---------|
| Agency.vue | OEM.vue | Org1 (核心企业) |
| Bank.vue | Carrier.vue | Org2 (承运方) |
| Platform.vue | Platform.vue | Org3 (监管平台) |

#### 3.2 UI 字段调整
- "房产编号" → "运单号"
- "房产位置" → "货物详情"
- "抵押状态" → "运输状态"

## 实施步骤

### Phase 1: 智能合约改造
1. [ ] 修改 `chaincode/chaincode.go`，替换 `RealEstate` 为 `Waybill`
2. [ ] 调整状态常量和数据结构
3. [ ] 修改合约方法逻辑和权限检查
4. [ ] 重新部署链码到测试网络

### Phase 2: 后端服务改造
1. [ ] 修改 `application/server/config/` 中的组织配置
2. [ ] 更新 `service/` 层的业务逻辑
3. [ ] 调整 API 路由和请求/响应数据模型
4. [ ] 更新 Fabric Gateway 连接配置

### Phase 3: 前端界面改造
1. [ ] 重命名并调整 `application/web/src/views/` 下的页面文件
2. [ ] 修改类型定义 `application/web/src/types/index.ts`
3. [ ] 更新表单和展示组件
4. [ ] 调整 API 调用参数和响应处理

### Phase 4: 联调与测试
1. [ ] 完成端到端流程测试（签发 → 确认 → 查询）
2. [ ] 验证跨组织调用权限
3. [ ] 测试历史记录查询功能
4. [ ] 性能测试（分页查询、并发调用）

## 风险与注意事项

### 风险评估
| 风险项 | 影响等级 | 缓解措施 |
|--------|---------|---------|
| 智能合约逻辑错误导致数据不一致 | 高 | 充分单元测试 + TestNetwork 验证 |
| 跨组织权限配置错误 | 中 | 严格检查 MSPID 和通道权限 |
| 前后端数据模型不一致 | 中 | 联调前对齐类型定义 |
| 旧数据无法迁移 | 低 | 本方案为全新业务逻辑，无需迁移 |

### 注意事项
1. **MSPID 不可变**：Fabric 网络的 MSPID (`Org1MSP`, `Org2MSP`, `Org3MSP`) 保持不变，仅调整其业务角色映射。
2. **通道配置无需修改**：当前通道 `mychannel` 可直接复用，无需重新创建通道。
3. **链码版本管理**：建议新链码使用新版本号（如 `waybill-v1.0`），避免与旧链码冲突。

## 预期交付物

| 交付物 | 说明 |
|--------|------|
| 更新后的链码 | `chaincode/chaincode.go` |
| 更新后的后端服务 | `application/server/` |
| 更新后的前端应用 | `application/web/` |
| 系统使用文档 | `docs/GUIDE.md` |
| 部署运维手册 | `docs/DEPLOYMENT.md` |

---

**文档状态**：DEPRECATED（已废弃）
**创建日期**：2024-12-20
**最后更新**：2024-12-26
