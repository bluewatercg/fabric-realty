# 🚀 OpenAPI 快速参考

## 📍 访问地址

### Swagger UI (在线文档)
```
http://192.168.1.41:8080/swagger/index.html
http://localhost:8080/swagger/index.html
```

## 📁 文档文件

| 文件 | 格式 | 用途 |
|------|------|------|
| `swagger.json` | Swagger 2.0 (JSON) | Postman、工具导入 |
| `swagger.yaml` | Swagger 2.0 (YAML) | 人类可读、编辑器 |
| `openapi.yaml` | OpenAPI 3.0 (YAML) | 现代标准、代码生成 |
| `postman_collection.json` | Postman | 直接导入测试 |

## 🔧 常用命令

### 重新生成文档
```bash
swag init -g main.go --output ./docs
```

### 启动服务器
```bash
# Windows
.\start_server.ps1

# Linux/Mac
./start_server.sh
```

### 验证文档
```bash
swagger-cli validate docs/swagger.yaml
swagger-cli validate docs/openapi.yaml
```

## 📝 快速测试

> ⚠️ **重要提示**: 
> - 基础 URL 是 `http://192.168.1.41:8080`
> - API 路径已经包含 `/api` 前缀
> - **不要**使用 `/api/api/...`，这是错误的！
> - **正确**: `/api/oem/order/create`
> - **错误**: `/api/api/oem/order/create` ❌

### 创建订单
```bash
curl -X POST http://192.168.1.41:8080/api/oem/order/create \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ORDER_2024_001",
    "manufacturerId": "MANUFACTURER_A",
    "items": [{"name": "engine_part", "quantity": 100}]
  }'
```

### 查询订单
```bash
curl http://192.168.1.41:8080/api/oem/order/ORDER_2024_001
```

### 更新状态
```bash
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/status \
  -H "Content-Type: application/json" \
  -d '{"status": "PRODUCING"}'
```

## 🎯 API 端点速查

### OEM (主机厂)
- `POST /api/oem/order/create` - 创建订单
- `GET /api/oem/order/{id}` - 查询订单
- `GET /api/oem/order/list` - 订单列表
- `PUT /api/oem/order/{id}/receive` - 确认收货

### Manufacturer (厂商)
- `PUT /api/manufacturer/order/{id}/accept` - 接受订单
- `PUT /api/manufacturer/order/{id}/status` - 更新状态

### Carrier (承运商)
- `POST /api/carrier/shipment/pickup` - 取货
- `PUT /api/carrier/shipment/{id}/location` - 更新位置

### Platform (平台)
- `GET /api/platform/all` - 所有数据

## 📊 状态枚举

### 订单状态
- `CREATED` - 已创建
- `ACCEPTED` - 已接受
- `PRODUCING` - 生产中
- `PRODUCED` - 已生产
- `READY` - 待发货
- `RECEIVED` - 已签收

## 🔑 认证

在请求头中添加：
```
Authorization: your-api-key
```

## 📚 更多信息

- 详细文档: `README.md`
- 完整总结: `OPENAPI_SUMMARY.md`
- Postman 集合: `postman_collection.json`
