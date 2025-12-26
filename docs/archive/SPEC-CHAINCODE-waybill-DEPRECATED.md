# Chaincode 修改方案：数字运单管理系统

> ⚠️ **此文档已归档，仅供参考**

> **废弃原因**：本方案描述的 Waybill 单资产模型已被当前 Order/Shipment 双资产模型替代。
>
> **替代方案**：请参考 `docs/core/LOG-CORE-arch-v1.md` 了解当前系统架构。

---

## 1. 核心目标
将现有的房产交易逻辑（RealEstate）替换为数字运单（Digital Waybill）逻辑，实现运单的**签发（Issuance）**、**确认（Confirmation）**和**全流程状态追踪**。

## 2. 数据模型设计

## 2. 数据模型设计

### 常量定义
```go
const (
    WAYBILL   = "WB" // 数字化运单资产
    FINANCING = "FP" // 融资申请 (Financing Proposal)
)
```

### 运单状态 (WaybillStatus)
```go
type WaybillStatus string

const (
    PENDING  WaybillStatus = "PENDING"  // 待承运方确认
    ACTIVE   WaybillStatus = "ACTIVE"   // 已生效
    FINANCED WaybillStatus = "FINANCED" // 融资中
)
```

### 运单模型 (Waybill)
```go
type Waybill struct {
    ID           string        `json:"id"`           // 运单唯一标识 (BillOfLadingID)
    Sender       string        `json:"sender"`       // 发货方 (核心企业 - Org1)
    CarrierID    string        `json:"carrierId"`    // 承运方标识 (Org2)
    HolderID     string        `json:"holderId"`     // 当前持有人 (如: 承运方ID 或 银行ID)
    Receiver     string        `json:"receiver"`     // 收货方信息
    CargoDetails string        `json:"cargoDetails"` // 货物描述
    CargoValue   float64       `json:"cargoValue"`   // 申报价值
    Status       WaybillStatus `json:"status"`       // 当前状态 (PENDING/ACTIVE/FINANCED)
    LockStatus   bool          `json:"lockStatus"`   // 锁定状态 (融资申请时锁定)
    CreateTime   time.Time     `json:"createTime"`   // 签发时间
    UpdateTime   time.Time     `json:"updateTime"`   // 最后变更时间
}

// 融资申请模型 (FinancingApplication)
type FinancingApplication struct {
    AppID         string    `json:"appId"`         // 融资申请ID
    BillIDs       []string  `json:"billIds"`       // 关联运单ID列表
    ApplicantID   string    `json:"applicantId"`   // 申请人 (承运方)
    BankID        string    `json:"bankId"`        // 目标银行
    RequestAmount float64   `json:"requestAmount"` // 申请金额
    Status        string    `json:"status"`        // 状态: PROPOSED/APPROVED/REJECTED
    CreateTime    time.Time `json:"createTime"`    // 申请时间
}
```

## 3. 功能方法实现

### `CreateWaybill` (核心企业签发)
- **RBAC**: 仅限 `Org1MSP` 调用。
- **输入**: ID, CarrierID, Receiver, CargoDetails, CargoValue, CreateTime。
- **逻辑**:
    1. 验证调用者 MSP ID。
    2. 检查运单 ID 是否重复（遍历 `PENDING` 和 `ACTIVE` 状态）。
    3. 构造 `Waybill` 实例，状态设为 `PENDING`。
    4. 存储至账本，复合键：`WAYBILL_PENDING_运单ID`。

### `ConfirmWaybill` (承运方确认)
- **RBAC**: 仅限 `Org2MSP` 调用。
- **输入**: 运单ID, UpdateTime。
- **逻辑**:
    1. 验证调用者 MSP ID。
    2. 从账本获取状态为 `PENDING` 的运单。
    3. **业务校验**: 验证运单中的 `CarrierID` 与调用者的身份信息是否匹配。
    4. 修改状态为 `ACTIVE`，更新 `UpdateTime`。
    5. **原子操作**: 删除旧的 `PENDING` 记录，写入新的 `ACTIVE` 记录。

### `QueryWaybill` (查询)
- **逻辑**: 遍历不同状态前缀查找指定 ID 的运单并返回。

### `QueryWaybillList` (分页列表)
- **参数**: pageSize, bookmark, status (可选)。
- **逻辑**: 使用 `GetStateByPartialCompositeKeyWithPagination` 实现。

---

## 4. 融资管理业务逻辑 (MVP3 预研)

### `ApplyFinancing` (承运方申请融资)
- **RBAC**: 仅限 `Org2MSP` (承运方) 调用。
- **校验**:
    - 运单状态必须为 `ACTIVE`。
    - `LockStatus` 必须为 `false` (防止双花/重复融资)。
    - `CargoValue` (货值) 必须大于 0。
- **操作**:
    1. 创建 `FinancingApplication` 对象并上链。
    2. 将涉及的运单 `LockStatus` 改为 `true`。

### `ApproveFinancing` (银行审批放款)
- **RBAC**: 仅限 `Org2MSP` (作为资金方身份，实际可扩展为独立银行 Org) 调用。
- **逻辑**:
    1. 获取申请单和关联运单。
    2. 如果审批通过 (`APPROVED`):
       - `Waybill.HolderID` = 银行ID。
       - `Waybill.Status` = `FINANCED`。
       - `Waybill.LockStatus` = `true` (保持锁定，直到融资结算)。
    3. 如果审批拒绝 (`REJECTED`):
       - `Waybill.LockStatus` = `false` (自动解锁)。

---

## 5. 验证要点
- [ ] **防双花**: 验证已锁定的运单无法再次发起 `ApplyFinancing`。
- [ ] **所有权流转**: 确认放款后，运单持有人从承运方变更为银行。
- [ ] **级联操作**: 确认申请单状态变更时，关联的所有运单状态也同步变更。
