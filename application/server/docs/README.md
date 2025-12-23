# OpenAPI 文档

本目录包含自动生成的OpenAPI/Swagger文档。

## 📄 文件说明

- **docs.go** - Go代码嵌入文件（由swag init自动生成）
- **swagger.json** - OpenAPI 3.0 JSON格式文档
- **swagger.yaml** - OpenAPI 3.0 YAML格式文档（人类可读）

## 🚀 访问Swagger UI

启动服务器后，访问：

```
http://localhost:8080/swagger/index.html
```

## 🔄 更新文档

当API代码发生变更时，运行以下命令重新生成文档：

```bash
cd application/server
swag init
```

或者使用完整路径：

```bash
~/go/bin/swag init
```

## 📊 API概览

### 主机厂 (OEM) - 4个端点
- `POST /api/oem/order/create` - 创建订单
- `PUT /api/oem/order/:id/receive` - 确认收货
- `GET /api/oem/order/:id` - 查询订单详情
- `GET /api/oem/order/list` - 查询订单列表

### 零部件厂商 (Manufacturer) - 3个端点
- `PUT /api/manufacturer/order/:id/accept` - 接受订单
- `PUT /api/manufacturer/order/:id/status` - 更新生产状态
- `GET /api/manufacturer/order/list` - 查询订单列表

### 承运商 (Carrier) - 4个端点
- `POST /api/carrier/shipment/pickup` - 取货并生成物流单
- `PUT /api/carrier/shipment/:id/location` - 更新物流位置
- `GET /api/carrier/shipment/:id` - 查询物流详情
- `GET /api/carrier/order/list` - 查询订单列表

### 平台监管 (Platform) - 1个端点
- `GET /api/platform/order/list` - 查询全部订单列表

## 🔒 安全认证

API使用`X-Org-ID` Header进行组织身份标识：

- `org1` - OEM（主机厂）
- `org2` - Manufacturer（零部件厂商）
- `org3` - Carrier/Platform（承运商/平台）

## 📦 数据模型

主要数据模型包括：

- `CreateOrderRequest` - 创建订单请求
- `Order` - 订单详情
- `OrderItem` - 订单项
- `UpdateStatusRequest` - 更新状态请求
- `PickupGoodsRequest` - 取货请求
- `UpdateLocationRequest` - 更新位置请求
- `Shipment` - 物流信息
- `ShipmentLocation` - 物流位置记录
- `OrderListResponse` - 订单列表响应

## 🛠️ 技术栈

- **swaggo/swag** - OpenAPI文档生成器
- **gin-swagger** - Gin框架集成
- **OpenAPI 3.0** - API规范标准

## 📚 参考资源

- [Swaggo文档](https://github.com/swaggo/swag)
- [OpenAPI规范](https://swagger.io/specification/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)

---

**生成时间**: 自动生成  
**版本**: 1.0  
**维护**: 通过swag init自动更新
