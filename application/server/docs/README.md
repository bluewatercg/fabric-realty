# API 文档说明

本项目提供了完整的 OpenAPI/Swagger 规范文档，支持多种格式和标准。

> ## ⚠️ 重要提示：URL 格式
> 
> **基础 URL**: `http://192.168.1.41:8080`  
> **API 路径**: 已包含 `/api` 前缀
> 
> ✅ **正确**: `http://192.168.1.41:8080/api/oem/order/create`  
> ❌ **错误**: `http://192.168.1.41:8080/api/api/oem/order/create`
> 
> **不要在路径中重复 `/api`！**
> 
> 如遇到 404 错误，请先检查 URL 格式是否正确。详见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)


## 📚 文档格式

### 1. Swagger 2.0 (自动生成)
- **swagger.json** - JSON 格式的 Swagger 2.0 文档
- **swagger.yaml** - YAML 格式的 Swagger 2.0 文档
- **docs.go** - Go 代码格式的文档定义

这些文件由 `swag` 工具自动生成，基于代码中的注释。

### 2. OpenAPI 3.0 (手动维护)
- **openapi.yaml** - 完整的 OpenAPI 3.0 规范文档

OpenAPI 3.0 是更现代的标准，提供了更丰富的功能：
- 更好的请求/响应示例
- 多服务器支持
- 更灵活的认证方式
- 更详细的错误处理

## 🚀 访问 API 文档

### 在线 Swagger UI

启动服务器后，访问以下地址查看交互式 API 文档：

```
http://192.168.1.41:8080/swagger/index.html
```

或本地开发环境：

```
http://localhost:8080/swagger/index.html
```

### 使用第三方工具

#### Swagger Editor
1. 访问 [Swagger Editor](https://editor.swagger.io/)
2. 导入 `swagger.yaml` 或 `swagger.json`
3. 在线编辑和测试 API

#### Postman
1. 打开 Postman
2. Import → 选择 `swagger.json` 或 `openapi.yaml`
3. 自动生成完整的 API 集合

#### VS Code 插件
推荐安装以下插件：
- **Swagger Viewer** - 预览 Swagger/OpenAPI 文档
- **OpenAPI (Swagger) Editor** - 编辑和验证 OpenAPI 文档

## 🔄 更新文档

### 自动生成 Swagger 2.0 文档

当修改了 API 代码或注释后，运行以下命令重新生成文档：

```bash
cd application/server
swag init -g main.go --output ./docs
```

### 手动更新 OpenAPI 3.0 文档

编辑 `openapi.yaml` 文件，确保与实际 API 保持同步。

## 📖 API 概览

### 主要功能模块

#### 1. OEM (主机厂)
- `POST /api/oem/order/create` - 创建采购订单
- `GET /api/oem/order/{id}` - 查询订单详情
- `GET /api/oem/order/{id}/history` - 查询订单历史
- `PUT /api/oem/order/{id}/receive` - 确认收货
- `GET /api/oem/order/list` - 查询订单列表

#### 2. Manufacturer (零部件厂商)
- `PUT /api/manufacturer/order/{id}/accept` - 接受订单
- `PUT /api/manufacturer/order/{id}/status` - 更新生产状态
- `GET /api/manufacturer/order/list` - 查询订单列表

#### 3. Carrier (承运商)
- `POST /api/carrier/shipment/pickup` - 取货并生成物流单
- `GET /api/carrier/shipment/{id}` - 查询物流详情
- `GET /api/carrier/shipment/{id}/history` - 查询物流历史
- `PUT /api/carrier/shipment/{id}/location` - 更新物流位置
- `GET /api/carrier/order/list` - 查询订单列表

#### 4. Platform (平台方)
- `GET /api/platform/all` - 查询所有账本数据
- `GET /api/platform/order/list` - 查询订单列表

## 🔐 认证

API 使用 API Key 认证方式。在请求头中添加：

```
Authorization: your-api-key
```

## 📝 请求示例

### 创建订单

```bash
curl -X POST http://192.168.1.41:8080/api/oem/order/create \
  -H "Content-Type: application/json" \
  -H "Authorization: your-api-key" \
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

### 更新生产状态

```bash
curl -X PUT http://192.168.1.41:8080/api/manufacturer/order/ORDER_2024_001/status \
  -H "Content-Type: application/json" \
  -H "Authorization: your-api-key" \
  -d '{
    "status": "PRODUCING"
  }'
```

### 查询订单列表

```bash
curl -X GET "http://192.168.1.41:8080/api/oem/order/list?pageSize=10" \
  -H "Authorization: your-api-key"
```

## 🎯 响应格式

所有 API 响应都遵循统一的格式：

### 成功响应
```json
{
  "code": 200,
  "message": "操作成功",
  "data": {
    // 响应数据
  }
}
```

### 错误响应
```json
{
  "code": 400,
  "message": "无效的请求参数",
  "data": null
}
```

## 🛠️ 开发工具

### 代码生成

使用 OpenAPI 文档可以自动生成客户端代码：

#### JavaScript/TypeScript
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/openapi.yaml \
  -g typescript-axios \
  -o ./client
```

#### Python
```bash
openapi-generator-cli generate \
  -i docs/openapi.yaml \
  -g python \
  -o ./client
```

#### Java
```bash
openapi-generator-cli generate \
  -i docs/openapi.yaml \
  -g java \
  -o ./client
```

## 📚 相关资源

- [OpenAPI 规范](https://swagger.io/specification/)
- [Swagger 文档](https://swagger.io/docs/)
- [swag 工具文档](https://github.com/swaggo/swag)
- [OpenAPI Generator](https://openapi-generator.tech/)

## 🔍 验证文档

### 在线验证
访问 [Swagger Validator](https://validator.swagger.io/) 验证文档的正确性。

### 命令行验证
```bash
# 安装 swagger-cli
npm install -g @apidevtools/swagger-cli

# 验证 Swagger 2.0
swagger-cli validate docs/swagger.yaml

# 验证 OpenAPI 3.0
swagger-cli validate docs/openapi.yaml
```

## 📞 支持

如有问题，请联系：
- Email: support@swagger.io
- URL: http://www.swagger.io/support
