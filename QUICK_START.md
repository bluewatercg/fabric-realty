# QueryAllLedgerData 快速开始指南

## 🎯 功能说明

查询账本上**所有资产的完整历史变更记录**，包括订单和物流单的每一次状态变化。

---

## 🚀 快速使用

### 1. 基本查询

```bash
# 查询前10条数据（默认）
curl "http://localhost:8000/api/platform/all"

# 指定每页数量
curl "http://localhost:8000/api/platform/all?pageSize=20"
```

### 2. 分页查询

```bash
# 第一页
curl "http://localhost:8000/api/platform/all?pageSize=10" > page1.json

# 提取 bookmark
BOOKMARK=$(cat page1.json | jq -r '.data.bookmark')

# 第二页
curl "http://localhost:8000/api/platform/all?pageSize=10&bookmark=$BOOKMARK"
```

### 3. 运行测试脚本

```bash
# 给脚本添加执行权限
chmod +x test_query_all.sh

# 运行测试
./test_query_all.sh
```

---

## 📊 响应数据格式

### 返回结构

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
          "status": "RECEIVED",
          ...
        },
        "history": [
          {
            "txId": "abc123...",
            "timestamp": "2024-01-01T10:00:00Z",
            "isDelete": false,
            "value": { "status": "CREATED", ... }
          },
          {
            "txId": "def456...",
            "timestamp": "2024-01-02T11:30:00Z",
            "isDelete": false,
            "value": { "status": "ACCEPTED", ... }
          }
        ]
      }
    ],
    "recordsCount": 1,
    "bookmark": "g1AAAAG...",
    "fetchedRecordsCount": 1
  }
}
```

### 字段说明

- **key**: 资产唯一标识（订单ID或物流单ID）
- **current**: 资产的当前最新状态
- **history**: 完整历史变更记录（按时间顺序）
  - **txId**: 区块链交易ID
  - **timestamp**: 变更时间
  - **isDelete**: 是否为删除操作
  - **value**: 变更后的完整数据

---

## 💡 使用示例

### 示例 1: 查看订单生命周期

```javascript
// 获取数据
const response = await fetch('http://localhost:8000/api/platform/all?pageSize=5');
const data = await response.json();

// 找到订单
const order = data.data.records.find(r => r.key.startsWith('ORDER-'));

// 打印生命周期
console.log(`订单 ${order.key} 的完整生命周期：`);
order.history.forEach((h, index) => {
  console.log(`${index + 1}. ${h.timestamp} - ${h.value.status}`);
});

// 输出示例：
// 订单 ORDER-001 的完整生命周期：
// 1. 2024-01-01T10:00:00Z - CREATED
// 2. 2024-01-02T11:30:00Z - ACCEPTED
// 3. 2024-01-03T09:15:00Z - PRODUCING
// 4. 2024-01-03T18:45:00Z - PRODUCED
// 5. 2024-01-04T08:00:00Z - READY
// 6. 2024-01-04T10:30:00Z - SHIPPED
// 7. 2024-01-05T16:30:00Z - RECEIVED
```

### 示例 2: 计算订单处理时长

```javascript
order.history.forEach(order => {
  const created = new Date(order.history[0].timestamp);
  const received = new Date(order.history[order.history.length - 1].timestamp);
  const hours = (received - created) / 1000 / 60 / 60;
  
  console.log(`订单 ${order.key}: ${hours.toFixed(1)} 小时`);
});
```

### 示例 3: 追踪物流轨迹

```javascript
const shipment = data.data.records.find(r => r.key.startsWith('SHIPMENT-'));

console.log(`物流单 ${shipment.key} 的运输轨迹：`);
shipment.history.forEach((h, index) => {
  console.log(`${index + 1}. ${h.timestamp} - ${h.value.location}`);
});

// 输出示例：
// 物流单 SHIPMENT-001 的运输轨迹：
// 1. 2024-01-04T10:30:00Z - 零部件仓库
// 2. 2024-01-04T15:30:00Z - 高速服务区
// 3. 2024-01-05T09:00:00Z - 北京市配送中心
// 4. 2024-01-05T16:00:00Z - 主机厂仓库
```

### 示例 4: 导出审计报告

```bash
# 导出所有数据到 JSON 文件
curl "http://localhost:8000/api/platform/all?pageSize=100" | jq '.' > audit_report.json

# 提取所有订单的状态变更
jq '.data.records[] | select(.current.objectType == "ORDER") | {
  orderId: .key,
  status: .current.status,
  historyCount: (.history | length)
}' audit_report.json

# 统计每个状态的订单数量
jq '.data.records[] | select(.current.objectType == "ORDER") | .current.status' audit_report.json | sort | uniq -c
```

---

## ⚙️ 部署和测试

### 1. 重新部署 Chaincode

如果修改了 chaincode，需要重新部署：

```bash
# 进入网络目录
cd network

# 卸载旧的 chaincode
./install.sh uninstall

# 安装新的 chaincode
./install.sh install
```

### 2. 重启后端服务

如果修改了后端代码：

```bash
# 停止现有服务
docker-compose -f application/docker-compose.yml down

# 重新构建并启动
docker-compose -f application/docker-compose.yml up --build -d
```

### 3. 验证功能

```bash
# 运行测试脚本
./test_query_all.sh

# 或手动测试
curl "http://localhost:8000/api/platform/all?pageSize=5" | jq '.'
```

---

## 📋 参数说明

### 查询参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `pageSize` | int | 否 | 10 | 每页返回的资产数量（建议 10-50） |
| `bookmark` | string | 否 | "" | 分页书签（首次查询留空） |

### 推荐配置

- **小批量查询**: pageSize=10-20（快速响应）
- **批量导出**: pageSize=50-100（平衡性能）
- **避免**: pageSize > 200（可能超时）

---

## 🔍 故障排查

### 问题 1: 404 Not Found

**原因**: 路由未正确注册或服务未启动

**解决**:
```bash
# 检查服务状态
docker ps | grep server

# 查看服务日志
docker logs application-server-1
```

### 问题 2: 返回空数据

**原因**: 账本上没有数据

**解决**:
```bash
# 先创建一些测试数据
curl -X POST "http://localhost:8000/api/oem/order/create" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "TEST-001",
    "manufacturerId": "Org2MSP",
    "items": [{"name": "测试零件", "quantity": 10, "price": 100}]
  }'

# 再次查询
curl "http://localhost:8000/api/platform/all"
```

### 问题 3: Chaincode 未更新

**原因**: Chaincode 未重新部署

**解决**:
```bash
cd network
./install.sh uninstall
./install.sh install
```

---

## 📚 相关文档

- **LEDGER_HISTORY_QUERY.md** - 详细功能说明
- **IMPLEMENTATION_SUMMARY.md** - 实现总结
- **EXAMPLE_RESPONSE.json** - 完整响应示例
- **test_query_all.sh** - 自动化测试脚本

---

## ✅ 验证清单

在部署到生产环境前，请确认：

- [ ] Chaincode 编译成功
- [ ] 后端编译成功
- [ ] 测试脚本运行通过
- [ ] 能正确返回历史数据
- [ ] 分页功能正常
- [ ] 响应时间可接受（< 5秒）
- [ ] 查看了日志没有错误

---

## 🎉 总结

你现在已经拥有了一个完整的账本历史数据查询功能！

**关键特性**:
- ✅ 查询所有资产的历史变更
- ✅ 支持分页处理大数据量
- ✅ 提供完整的审计追踪
- ✅ 不可篡改的区块链记录

**立即开始**:
```bash
curl "http://localhost:8000/api/platform/all?pageSize=10" | jq '.data.records[0]'
```
