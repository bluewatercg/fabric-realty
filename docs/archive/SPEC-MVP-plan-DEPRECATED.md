# MVP 二开规划：数字运单管理系统

本项目将基于现有的房地产交易系统进行二次开发，实现 **MVP1（核心企业签发数字运单）** 和 **MVP2（承运方确认运单）** 功能。我们将复用现有的三组织（Org1, Org2, Org3）架构，并将其业务逻辑从“房产交易”转向“物流/供应链运单流转”。

## 业务角色映射

为了尽可能复用现有网络结构，我们进行如下角色映射：
- **Org1 (不动产登记机构) -> 核心企业 (Core Enterprise)**: 负责运单的初始录入与签发。
- **Org2 (银行) -> 承运方 (Carrier)**: 负责运单的核实与确认。
- **Org3 (交易平台) -> 监管/平台方 (Platform)**: 提供系统支持，并对数据完整性进行算法背书（Hash）。

## 方案设计

### 1. 智能合约层 (Chaincode)

#### 数据结构 (DigitalBill)
- `BillOfLadingID`: 运单唯一标识（主键）
- `Sender`: 发货方（核心企业）
- `CarrierID`: 承运方标识
- `Receiver`: 收货方信息
- `CargoDetails`: 货物详情（名称、重量、货物价值 hash/佐证等）
- `Status`: 状态：
    - `PENDING`: 待承运方确认
    - `ACTIVE`: 已生效/可流转
- `Hash`: 存证哈希，由平台方签名背书

#### 核心逻辑
- `CreateWaybill`: 仅限 Org1 调用。
    - 输入：货物详情、承运方ID、收货人信息。
    - 逻辑：生成 ID，设置状态为 `PENDING`，上链。
- `ConfirmWaybill`: 仅限 Org2 调用。
    - 输入：`BillOfLadingID`。
    - 逻辑：验证 `CarrierID` 与调用者身份一致，将状态改为 `ACTIVE`。
- `QueryWaybill`: 通用查询逻辑。

### 2. 后端应用层 (Server)

#### 接口扩展
- 新增 `api/waybill.go`：
    - `POST /api/core-enterprise/waybill/create`: 核心企业发起。
    - `POST /api/carrier/waybill/confirm`: 承运方确认。
- 新增 `service/waybill_service.go`: 封装 Fabric SDK 调用逻辑。

### 3. 前端应用层 (Web)

#### 页面组件
- `WaybillManagement.vue`:
    - **核心企业视角**: 录入表单（带有“申报货物价值”、“上传附件”等字段模拟），显示已签发列表。
    - **承运方视角**: 显示待确认列表，点击“确认”触发上链操作。

---

## 具体修改路径

### [Component] Chaincode
#### [MODIFY] [chaincode.go](file:///d:/Project/Aventura/fabric/fabric-realty/chaincode/chaincode.go)
- 引入新的数据结构 `Waybill`。
- 替换现有的 `RealEstate` 相关逻辑。

### [Component] Server
#### [NEW] [waybill.go](file:///d:/Project/Aventura/fabric/fabric-realty/application/server/api/waybill.go)
#### [NEW] [waybill_service.go](file:///d:/Project/Aventura/fabric/fabric-realty/application/server/service/waybill_service.go)

### [Component] Web
#### [NEW] [WaybillManagement.vue](file:///d:/Project/Aventura/fabric/fabric-realty/application/web/src/views/WaybillManagement.vue)

---

## 验证计划

### 自动化测试 (Scripts)
1. **签发流程**: 执行脚本以 Org1 身份创建运单，检查账本状态。
2. **确认流程**: 执行脚本以 Org2 身份确认运单，验证状态流转。
3. **权限验证**: 尝试以 Org3 身份执行 `ConfirmWaybill`，预期失败。

### 手动验证
1. 启动区块链网络并安装链码。
2. 以核心企业登录 Web 端，提交一张数字运单。
3. 退出，以承运方身份登录，查看待办并点击确认。
4. 验证运单状态在 Web 端实时更新为“已生效”。
