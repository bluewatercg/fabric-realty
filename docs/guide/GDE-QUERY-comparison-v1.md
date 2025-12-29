# 查询功能对比说明

## 📊 当前实现的查询功能

### 1. QueryAllLedgerData（你新增的功能）

**路径：** `GET /api/platform/all?pageSize=10&bookmark=xxx`

**功能：** 查询账本上所有资产的**当前最新状态**

**实现原理：** 使用 `GetStateByRangeWithPagination("")` 扫描整个 State DB

**返回数据示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "id": "ORDER-001",
        "objectType": "ORDER",
        "status": "READY",           // ← 只有当前状态
        "totalPrice": 15000,
        "createTime": "2024-01-01T10:00:00Z",
        "updateTime": "2024-01-03T14:30:00Z"
      },
      {
        "id": "SHIPMENT-001",
        "objectType": "SHIPMENT",
        "location": "北京仓库",       // ← 只有当前位置
        "status": "运输中"
      }
    ],
    "recordsCount": 2,
    "bookmark": "g1AAAAA...",
    "fetchedRecordsCount": 2
  }
}
```

**适用场景：**
- ✅ 平台方数据总览
- ✅ 监控所有订单和物流单的当前状态
- ✅ 统计当前有多少订单
- ✅ 导出当前所有数据快照

---

### 2. QueryOrderHistory（已有功能）

**路径：** `GET /api/oem/order/:id/history`

**功能：** 查询**单个订单**的完整历史变更记录

**实现原理：** 使用 `GetHistoryForKey(orderId)` 获取历史版本

**返回数据示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "txId": "abc123...",
      "timestamp": "2024-01-01T10:00:00Z",
      "status": "CREATED",
      "isDelete": false,
      "value": { "id": "ORDER-001", "status": "CREATED", ... }
    },
    {
      "txId": "def456...",
      "timestamp": "2024-01-02T11:30:00Z",
      "status": "ACCEPTED",
      "isDelete": false,
      "value": { "id": "ORDER-001", "status": "ACCEPTED", ... }
    },
    {
      "txId": "ghi789...",
      "timestamp": "2024-01-03T09:15:00Z",
      "status": "PRODUCING",
      "isDelete": false,
      "value": { "id": "ORDER-001", "status": "PRODUCING", ... }
    },
    {
      "txId": "jkl012...",
      "timestamp": "2024-01-03T14:30:00Z",
      "status": "READY",
      "isDelete": false,
      "value": { "id": "ORDER-001", "status": "READY", ... }
    }
  ]
}
```

**适用场景：**
- ✅ 审计单个订单的完整生命周期
- ✅ 追溯订单状态变更历史
- ✅ 不可篡改的证据链

---

### 3. QueryShipmentHistory（已有功能）

**路径：** `GET /api/carrier/shipment/:id/history`

**功能：** 查询**单个物流单**的位置变更历史

**实现原理：** 使用 `GetHistoryForKey(shipmentId)`

**返回数据示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "txId": "abc123...",
      "timestamp": "2024-01-03T15:00:00Z",
      "location": "零部件仓库",
      "status": "运输中",
      "isDelete": false
    },
    {
      "txId": "def456...",
      "timestamp": "2024-01-03T18:30:00Z",
      "location": "高速服务区",
      "status": "运输中",
      "isDelete": false
    },
    {
      "txId": "ghi789...",
      "timestamp": "2024-01-04T10:00:00Z",
      "location": "北京仓库",
      "status": "运输中",
      "isDelete": false
    }
  ]
}
```

**适用场景：**
- ✅ 追踪物流轨迹
- ✅ 物流位置历史回溯

---

## 🔍 关键概念对比

### "当前状态" vs "历史数据"

| 特性 | 当前状态 (QueryAllLedgerData) | 历史数据 (QueryOrderHistory) |
|------|------------------------------|------------------------------|
| **Fabric API** | `GetStateByRangeWithPagination` | `GetHistoryForKey` |
| **查询范围** | 所有 key | 单个 key |
| **时间维度** | 只有最新状态 | 完整时间线 |
| **数据量** | 每个 key 一条记录 | 每个 key 多条记录（每次修改一条） |
| **用途** | 数据快照、总览 | 审计追踪、历史回溯 |
| **性能** | 较好（只读最新） | 一般（需扫描区块） |

---

## 📝 你的需求判断

根据你的描述"查询账本的历史数据"，请确认你的需求是：

### 选项 A：查询所有资产的当前状态 ✅
**描述：** 我想看账本上现在有哪些订单和物流单，以及它们的最新状态
- **实现状态：** ✅ 已完成（就是你当前的实现）
- **API：** `GET /api/platform/all?pageSize=10`

### 选项 B：查询单个资产的历史变更 ✅
**描述：** 我想看某个订单的完整状态变更历史
- **实现状态：** ✅ 已完成（已有的 QueryOrderHistory）
- **API：** `GET /api/oem/order/:id/history`

### 选项 C：查询所有资产的历史变更 ❌
**描述：** 我想看所有订单的每次状态变更记录
- **实现状态：** ❌ 未实现
- **性能问题：** ⚠️ 不推荐（需要遍历所有 key 并逐个查历史，性能极差）
- **替代方案：** 
  1. 使用选项 A 获取所有订单 ID
  2. 前端根据需要对感兴趣的订单调用选项 B 查询历史

---

## 🎯 总结

### 当前代码状态：

✅ **功能正确性：** 你的代码能正确查询账本的**当前状态数据**

✅ **代码质量：** 
- Chaincode 层实现完整
- Service 层调用正确（已修复为使用 PLATFORM_ORG）
- API 层接口设计合理
- 路由注册正确

⚠️ **功能定位：**
- 如果你的需求是"查询当前所有数据" → ✅ 完美
- 如果你的需求是"查询所有历史变更" → ❌ 需要重新设计

### 建议：

1. **命名更准确：** 建议将函数改名为 `QueryAllCurrentData` 更能体现功能
2. **已有历史查询：** 如需历史数据，使用已有的 `QueryOrderHistory` 和 `QueryShipmentHistory`
3. **组合查询：** 前端可以先调用 QueryAllLedgerData 获取所有订单ID，再按需查询单个订单的历史

---

## 测试命令

```bash
# 测试查询所有当前数据
curl "http://localhost:8000/api/platform/all?pageSize=5"

# 测试查询单个订单历史（需要替换真实订单ID）
curl "http://localhost:8000/api/oem/order/ORDER-001/history"

# 测试查询单个物流单历史
curl "http://localhost:8000/api/carrier/shipment/SHIPMENT-001/history"
```
