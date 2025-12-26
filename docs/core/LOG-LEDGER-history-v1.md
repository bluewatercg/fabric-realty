# 账本历史数据查询功能说明

## 📋 功能概述

`QueryAllLedgerData` 功能用于**查询账本上所有资产的完整历史变更记录**，实现区块链数据的完整追溯和审计。

### 核心特性

✅ **完整历史追溯** - 返回每个资产的所有历史版本  
✅ **分页支持** - 支持大数据量场景的分页查询  
✅ **多类型资产** - 同时查询订单(ORDER)和物流单(SHIPMENT)  
✅ **时间线完整** - 包含每次变更的交易ID、时间戳和具体内容  
✅ **审计友好** - 提供不可篡改的历史记录用于合规审计

---

## 🔧 技术实现

### Chaincode 层实现

**文件：** `chaincode/chaincode.go`

**核心逻辑：**

```go
// 第一步：使用分页查询获取所有 key 的当前状态
resultsIterator, responseMetadata, err := ctx.GetStub().GetStateByRangeWithPagination("", "", pageSize, bookmark)

// 第二步：对每个 key 查询其完整历史
for resultsIterator.HasNext() {
    // 获取 key 和当前值
    queryResponse, err := resultsIterator.Next()
    
    // 查询该 key 的历史记录
    historyIterator, err := ctx.GetStub().GetHistoryForKey(key)
    
    // 遍历所有历史版本
    for historyIterator.HasNext() {
        historyData, err := historyIterator.Next()
        // 提取 txId, timestamp, value, isDelete
    }
}
```

**关键 API：**
- `GetStateByRangeWithPagination()` - 分页获取当前状态
- `GetHistoryForKey()` - 获取单个 key 的完整历史

---

## 📊 数据结构

### 返回数据格式

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "key": "ORDER-001",
        "current": {
          "id": "ORDER-001",
          "objectType": "ORDER",
          "status": "RECEIVED",
          "oemId": "Org1MSP",
          "manufacturerId": "Org2MSP",
          "totalPrice": 15000,
          "createTime": "2024-01-01T10:00:00Z",
          "updateTime": "2024-01-05T16:30:00Z"
        },
        "history": [
          {
            "txId": "a1b2c3d4...",
            "timestamp": "2024-01-01T10:00:00Z",
            "isDelete": false,
            "value": {
              "id": "ORDER-001",
              "status": "CREATED",
              ...
            }
          },
          {
            "txId": "e5f6g7h8...",
            "timestamp": "2024-01-02T11:30:00Z",
            "isDelete": false,
            "value": {
              "id": "ORDER-001",
              "status": "ACCEPTED",
              ...
            }
          },
          {
            "txId": "i9j0k1l2...",
            "timestamp": "2024-01-03T14:20:00Z",
            "isDelete": false,
            "value": {
              "id": "ORDER-001",
              "status": "PRODUCING",
              ...
            }
          },
          {
            "txId": "m3n4o5p6...",
            "timestamp": "2024-01-04T09:15:00Z",
            "isDelete": false,
            "value": {
              "id": "ORDER-001",
              "status": "SHIPPED",
              ...
            }
          },
          {
            "txId": "q7r8s9t0...",
            "timestamp": "2024-01-05T16:30:00Z",
            "isDelete": false,
            "value": {
              "id": "ORDER-001",
              "status": "RECEIVED",
              ...
            }
          }
        ]
      },
      {
        "key": "SHIPMENT-001",
        "current": {
          "id": "SHIPMENT-001",
          "objectType": "SHIPMENT",
          "orderId": "ORDER-001",
          "location": "主机厂仓库",
          "status": "已送达"
        },
        "history": [
          {
            "txId": "u1v2w3x4...",
            "timestamp": "2024-01-04T09:15:00Z",
            "isDelete": false,
            "value": {
              "location": "零部件仓库",
              "status": "运输中"
            }
          },
          {
            "txId": "y5z6a7b8...",
            "timestamp": "2024-01-04T15:30:00Z",
            "isDelete": false,
            "value": {
              "location": "高速服务区",
              "status": "运输中"
            }
          },
          {
            "txId": "c9d0e1f2...",
            "timestamp": "2024-01-05T10:00:00Z",
            "isDelete": false,
            "value": {
              "location": "主机厂仓库",
              "status": "已送达"
            }
          }
        ]
      }
    ],
    "recordsCount": 2,
    "bookmark": "g1AAAAG...",
    "fetchedRecordsCount": 2
  }
}
```

### 数据结构说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `key` | string | 资产的唯一标识符 (订单ID或物流单ID) |
| `current` | object | 资产的当前最新状态 |
| `history` | array | 资产的完整历史变更记录（时间顺序） |
| `history[].txId` | string | 交易ID（区块链交易哈希） |
| `history[].timestamp` | string | 变更时间（ISO 8601格式） |
| `history[].isDelete` | boolean | 是否为删除操作 |
| `history[].value` | object | 变更后的完整数据 |
| `recordsCount` | number | 本次返回的资产数量 |
| `bookmark` | string | 分页书签（用于获取下一页） |
| `fetchedRecordsCount` | number | 实际获取的记录数 |

---

## 🚀 API 使用

### 请求

**端点：** `GET /api/platform/all`

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `pageSize` | int | 否 | 10 | 每页返回的资产数量 |
| `bookmark` | string | 否 | "" | 分页书签（首次查询留空） |

**权限：** 平台方 (Org3MSP)

### 请求示例

```bash
# 首次查询（获取前10条）
curl "http://localhost:8000/api/platform/all?pageSize=10"

# 分页查询（使用上次返回的 bookmark）
curl "http://localhost:8000/api/platform/all?pageSize=10&bookmark=g1AAAAG..."

# 大批量查询
curl "http://localhost:8000/api/platform/all?pageSize=100"
```

---

## 📈 使用场景

### 1. 合规审计

**场景：** 监管机构要求提供所有订单的完整生命周期记录

**优势：**
- ✅ 完整的时间线追溯
- ✅ 不可篡改的交易ID证明
- ✅ 精确到秒的时间戳
- ✅ 包含所有状态变更的详细数据

### 2. 数据分析

**场景：** 分析订单从创建到签收的平均时长

**数据提取：**
```javascript
records.forEach(record => {
  const created = record.history[0].timestamp;  // 首次创建
  const received = record.history[record.history.length - 1].timestamp;  // 最终签收
  const duration = new Date(received) - new Date(created);
  console.log(`订单 ${record.key} 耗时: ${duration / 1000 / 60 / 60} 小时`);
});
```

### 3. 异常检测

**场景：** 检查是否存在状态回退或异常跳转

**检测逻辑：**
```javascript
const expectedFlow = ['CREATED', 'ACCEPTED', 'PRODUCING', 'PRODUCED', 'READY', 'SHIPPED', 'RECEIVED'];

records.forEach(record => {
  const statuses = record.history.map(h => h.value.status);
  // 检查状态顺序是否符合业务流程
  if (!isValidFlow(statuses, expectedFlow)) {
    console.warn(`订单 ${record.key} 存在异常状态变更`);
  }
});
```

### 4. 物流轨迹完整追踪

**场景：** 追溯货物的完整运输路径

**数据展示：**
```javascript
shipmentRecords.forEach(record => {
  console.log(`物流单 ${record.key} 的运输轨迹：`);
  record.history.forEach((h, index) => {
    console.log(`  ${index + 1}. ${h.timestamp} - ${h.value.location}`);
  });
});
```

### 5. 性能监控

**场景：** 监控各环节的处理时效

**分析：**
- 从 CREATED 到 ACCEPTED 的响应时间（制造商响应速度）
- 从 READY 到 SHIPPED 的取货时间（承运商效率）
- 从 SHIPPED 到 RECEIVED 的运输时间（物流时效）

---

## ⚠️ 性能考量

### 性能特点

| 特性 | 说明 |
|------|------|
| **查询复杂度** | O(n * m) - n为资产数量，m为平均历史记录数 |
| **网络开销** | 较大（需要遍历历史区块） |
| **内存占用** | 随历史记录数增加而增加 |
| **适用场景** | 批量数据导出、定期审计、报表生成 |

### 优化建议

1. **合理设置 pageSize**
   - 小批量查询：`pageSize=10-20`（快速响应）
   - 批量导出：`pageSize=50-100`（平衡性能）
   - 避免：`pageSize > 200`（可能超时）

2. **使用分页查询**
   ```bash
   # 第一页
   response1=$(curl "http://localhost:8000/api/platform/all?pageSize=50")
   bookmark=$(echo $response1 | jq -r '.data.bookmark')
   
   # 第二页
   response2=$(curl "http://localhost:8000/api/platform/all?pageSize=50&bookmark=$bookmark")
   ```

3. **异步处理**
   - 对于大数据量导出，建议使用异步任务
   - 在后台分批查询并生成报告文件

4. **缓存策略**
   - 历史数据不会改变，可以缓存已查询的结果
   - 使用 Redis 缓存常用的历史查询结果

---

## 🔄 与其他查询功能的对比

| 功能 | API | 查询范围 | 时间维度 | 性能 | 适用场景 |
|------|-----|----------|----------|------|----------|
| **QueryAllLedgerData** | `/api/platform/all` | 所有资产 | 完整历史 | 较慢 | 批量审计、数据导出 |
| **QueryOrderList** | `/api/oem/order/list` | 所有订单 | 当前状态 | 快 | 订单列表展示 |
| **QueryOrder** | `/api/oem/order/:id` | 单个订单 | 当前状态 | 很快 | 订单详情查看 |
| **QueryOrderHistory** | `/api/oem/order/:id/history` | 单个订单 | 完整历史 | 快 | 单个订单追溯 |
| **QueryShipmentHistory** | `/api/carrier/shipment/:id/history` | 单个物流单 | 完整历史 | 快 | 物流轨迹追踪 |

### 使用建议

- 📊 **实时监控** → 使用 QueryOrderList（查当前状态）
- 🔍 **单个追溯** → 使用 QueryOrderHistory（查单个历史）
- 📁 **批量审计** → 使用 QueryAllLedgerData（查所有历史）
- 📈 **报表生成** → 使用 QueryAllLedgerData（完整数据）

---

## 🧪 测试

### 运行测试脚本

```bash
# 给脚本添加执行权限
chmod +x test_query_all.sh

# 运行测试
./test_query_all.sh
```

### 测试脚本功能

1. ✅ 检查 Fabric 网络状态
2. ✅ 检查后端服务状态
3. ✅ 调用 QueryAllLedgerData API
4. ✅ 展示资产详细信息和历史记录
5. ✅ 统计所有资产的历史记录数量

### 预期输出示例

```
==========================================
测试 QueryAllLedgerData 功能
查询所有账本数据及完整历史变更
==========================================

[1] 检查 Fabric 网络状态...
NAMES                   STATUS
peer0.org1.example.com  Up 2 hours
peer0.org2.example.com  Up 2 hours
peer0.org3.example.com  Up 2 hours

[2] 检查后端服务...
NAMES                   STATUS
application-server-1    Up 2 hours

[3] 测试 QueryAllLedgerData API (历史数据查询)...
请求: GET http://localhost:8000/api/platform/all?pageSize=5
HTTP 状态码: 200

✅ API 调用成功
   - 返回资产数: 3
   - 分页书签: g1AAAAG...

[4] 第一个资产的详细信息：
   资产 Key: ORDER-001
   历史记录数: 5 条

   当前状态:
      {
        "id": "ORDER-001",
        "status": "RECEIVED",
        "totalPrice": 15000
      }

   历史变更记录 (最近3条):
      {
        "txId": "a1b2c3d4...",
        "timestamp": "2024-01-01T10:00:00Z",
        "isDelete": false
      }
      ...

[5] 所有资产的历史统计：
   ORDER-001: 5 条历史记录
   ORDER-002: 3 条历史记录
   SHIPMENT-001: 4 条历史记录

==========================================
测试完成
==========================================
```

---

## 📝 总结

### ✅ 功能完整性

- ✅ **实现了账本历史数据的完整查询**
- ✅ **支持分页处理大数据量**
- ✅ **提供详细的时间线和交易信息**
- ✅ **满足审计和追溯需求**

### 🎯 核心价值

1. **不可篡改性** - 基于区块链的历史记录无法修改
2. **完整追溯** - 每个资产的所有变更都有记录
3. **时间精确** - 精确到秒的时间戳
4. **证据链完整** - 包含交易ID用于验证

### 🚀 后续优化方向

1. **性能优化** - 考虑增加异步导出功能
2. **数据过滤** - 支持按时间范围、资产类型筛选
3. **报表生成** - 基于历史数据自动生成审计报表
4. **可视化** - 提供时间线可视化展示
