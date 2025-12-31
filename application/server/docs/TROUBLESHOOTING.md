# 常见问题和解决方案

## ❌ 404 错误 - URL 路径问题

### 问题描述
```bash
curl -X GET "http://192.168.1.41:8080/api/api/platform/all?pageSize=10"
# 返回: 404 page not found
```

### 原因分析
URL 中重复了 `/api` 前缀。服务器的 `BasePath` 已经设置为 `/api`，所以不需要在路径中再次添加。

### ✅ 正确做法
```bash
# 正确 ✓
curl -X GET "http://192.168.1.41:8080/api/platform/all?pageSize=10"

# 错误 ✗
curl -X GET "http://192.168.1.41:8080/api/api/platform/all?pageSize=10"
```

### URL 结构说明
```
完整 URL = 基础地址 + API 路径
         = http://192.168.1.41:8080 + /api/platform/all
         = http://192.168.1.41:8080/api/platform/all
```

## 📋 正确的 API 端点列表

### OEM (主机厂)
```bash
# 创建订单
POST http://192.168.1.41:8080/api/oem/order/create

# 查询订单详情
GET http://192.168.1.41:8080/api/oem/order/{id}

# 查询订单列表
GET http://192.168.1.41:8080/api/oem/order/list?pageSize=10

# 查询订单历史
GET http://192.168.1.41:8080/api/oem/order/{id}/history

# 确认收货
PUT http://192.168.1.41:8080/api/oem/order/{id}/receive
```

### Manufacturer (厂商)
```bash
# 接受订单
PUT http://192.168.1.41:8080/api/manufacturer/order/{id}/accept

# 更新生产状态
PUT http://192.168.1.41:8080/api/manufacturer/order/{id}/status

# 查询订单列表
GET http://192.168.1.41:8080/api/manufacturer/order/list?pageSize=10
```

### Carrier (承运商)
```bash
# 取货并生成物流单
POST http://192.168.1.41:8080/api/carrier/shipment/pickup

# 查询物流详情
GET http://192.168.1.41:8080/api/carrier/shipment/{id}

# 查询物流历史
GET http://192.168.1.41:8080/api/carrier/shipment/{id}/history

# 更新物流位置
PUT http://192.168.1.41:8080/api/carrier/shipment/{id}/location

# 查询订单列表
GET http://192.168.1.41:8080/api/carrier/order/list?pageSize=10
```

### Platform (平台)
```bash
# 查询所有账本数据
GET http://192.168.1.41:8080/api/platform/all?pageSize=10

# 查询订单列表
GET http://192.168.1.41:8080/api/platform/order/list?pageSize=10
```

## 🧪 测试示例

### 完整的业务流程测试

#### 1. OEM 创建订单
```bash
curl -X POST http://192.168.1.41:8080/api/oem/order/create \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ORDER_2024_001",
    "manufacturerId": "MANUFACTURER_A",
    "items": [
      {
        "name": "engine_part_xyz",
        "quantity": 100
      }
    ]
  }'
```

#### 2. Manufacturer 接受订单
```bash
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/accept
```

#### 3. Manufacturer 更新状态
```bash
# 生产中
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/status \
  -H "Content-Type: application/json" \
  -d '{"status": "PRODUCING"}'

# 已生产
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/status \
  -H "Content-Type: application/json" \
  -d '{"status": "PRODUCED"}'

# 待发货
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/status \
  -H "Content-Type: application/json" \
  -d '{"status": "READY"}'
```

#### 4. Carrier 取货
```bash
curl -X POST http://192.168.1.41:8080/api/carrier/shipment/pickup \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "ORDER_2024_001",
    "shipmentId": "SHIPMENT_2024_001"
  }'
```

#### 5. Carrier 更新位置
```bash
curl -X PUT http://192.168.1.41:8080/api/carrier/shipment/SHIPMENT_2024_001/location \
  -H "Content-Type: application/json" \
  -d '{"location": "SHANGHAI_PORT"}'
```

#### 6. OEM 确认收货
```bash
curl -X PUT http://192.168.1.41:8080/api/oem/order/ORDER_2024_001/receive
```

#### 7. 查询订单历史
```bash
curl -X GET http://192.168.1.41:8080/api/oem/order/ORDER_2024_001/history
```

## 🔍 其他常见问题

### 问题 2: 400 Bad Request - 参数错误

#### 原因
请求参数不完整或格式错误。

#### 解决方案
检查必填字段：
- `CreateOrderRequest`: 需要 `id`, `manufacturerId`, `items`
- `UpdateStatusRequest`: 需要 `status` (必须是 PRODUCING/PRODUCED/READY)
- `PickupGoodsRequest`: 需要 `orderId`, `shipmentId`
- `UpdateLocationRequest`: 需要 `location`

### 问题 3: 500 Internal Server Error

#### 可能原因
1. Fabric 网络未启动
2. 配置文件错误
3. 证书问题
4. 订单不存在

#### 解决方案
1. 检查 Fabric 网络状态
2. 查看服务器日志: `docker logs fabric-realty.server`
3. 验证配置文件: `config/config.yaml`

### 问题 4: 无法访问 Swagger UI

#### URL
```
http://192.168.1.41:8080/swagger/index.html
```

#### 检查
1. 服务器是否启动
2. 端口 8080 是否开放
3. 防火墙设置

## 📝 使用自动化测试脚本

我们提供了完整的测试脚本，可以自动测试所有 API：

```bash
# 给脚本添加执行权限
chmod +x docs/test_api.sh

# 运行测试
./docs/test_api.sh
```

脚本会自动：
- 创建订单
- 接受订单
- 更新状态
- 取货
- 更新位置
- 确认收货
- 查询历史

## 🎯 快速检查清单

在测试 API 之前，请确认：

- [ ] 服务器正在运行
- [ ] Fabric 网络已启动
- [ ] 使用正确的 URL 格式（不要重复 `/api`）
- [ ] 请求头包含 `Content-Type: application/json`
- [ ] 请求体是有效的 JSON
- [ ] 所有必填字段都已提供
- [ ] 枚举值使用正确的大写格式

## 📚 相关资源

- Swagger UI: http://192.168.1.41:8080/swagger/index.html
- 快速参考: `QUICK_REFERENCE.md`
- 完整文档: `README.md`
- 测试脚本: `test_api.sh`
