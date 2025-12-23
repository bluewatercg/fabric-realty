# OpenAPI快速使用指南 ⚡

## 🎯 一分钟快速开始

### 1. 启动服务

```bash
cd application/server
go run main.go
```

你会看到：
```
服务器启动于 :8080
Swagger文档地址: http://localhost:8080/swagger/index.html
```

### 2. 访问Swagger UI

在浏览器打开：
```
http://localhost:8080/swagger/index.html
```

### 3. 开始测试

1. 选择一个API（例如：`GET /api/oem/order/list`）
2. 点击 **Try it out**
3. 填写参数（如果需要）
4. 点击 **Execute**
5. 查看响应结果

就这么简单！🎉

---

## 📋 所有API端点一览

### 🏭 主机厂 (OEM)

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/oem/order/create` | 创建订单 |
| PUT | `/api/oem/order/:id/receive` | 确认收货 |
| GET | `/api/oem/order/:id` | 查询订单详情 |
| GET | `/api/oem/order/list` | 查询订单列表 |

### 🏭 零部件厂商 (Manufacturer)

| 方法 | 路径 | 描述 |
|------|------|------|
| PUT | `/api/manufacturer/order/:id/accept` | 接受订单 |
| PUT | `/api/manufacturer/order/:id/status` | 更新生产状态 |
| GET | `/api/manufacturer/order/list` | 查询订单列表 |

### 🚚 承运商 (Carrier)

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/carrier/shipment/pickup` | 取货并生成物流单 |
| PUT | `/api/carrier/shipment/:id/location` | 更新物流位置 |
| GET | `/api/carrier/shipment/:id` | 查询物流详情 |
| GET | `/api/carrier/order/list` | 查询订单列表 |

### 👁️ 平台监管 (Platform)

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/platform/order/list` | 查询全部订单列表 |

---

## 💡 常用操作

### 测试创建订单

在Swagger UI中：

1. 找到 `POST /api/oem/order/create`
2. 点击 **Try it out**
3. 修改请求体：
```json
{
  "id": "ORDER001",
  "manufacturerId": "MFG001",
  "items": [
    {
      "partNumber": "PART-12345",
      "partName": "发动机缸体",
      "quantity": 100,
      "unitPrice": 125.50,
      "specification": "标准规格"
    }
  ]
}
```
4. 点击 **Execute**

### 查询订单列表

1. 找到 `GET /api/oem/order/list`
2. 点击 **Try it out**
3. 设置参数：
   - `pageSize`: 10
   - `bookmark`: (留空)
4. 点击 **Execute**

### 更新生产状态

1. 找到 `PUT /api/manufacturer/order/{id}/status`
2. 点击 **Try it out**
3. 设置参数：
   - `id`: ORDER001
4. 修改请求体：
```json
{
  "status": "InProduction"
}
```
5. 点击 **Execute**

---

## 🔄 修改API后更新文档

### Step 1: 修改代码和注释

编辑 `api/supply_chain.go` 或 `api/models.go`

### Step 2: 重新生成文档

```bash
cd application/server
swag init
```

输出：
```
Generate swagger docs....
Generate general API Info
Generating api.CreateOrderRequest
...
create docs.go at docs/docs.go
create swagger.json at docs/swagger.json
create swagger.yaml at docs/swagger.yaml
```

### Step 3: 重启服务

```bash
go run main.go
```

刷新浏览器，文档已更新！✨

---

## 📦 导出OpenAPI文档

生成的文档文件位于 `application/server/docs/`：

- **swagger.json** - JSON格式（机器可读）
- **swagger.yaml** - YAML格式（人类可读）

你可以：
- 导入到Postman进行测试
- 导入到API网关（Kong/Traefik）
- 使用swagger-codegen生成客户端SDK
- 提交到API文档平台

---

## 🔒 安全认证说明

API使用 `X-Org-ID` Header标识组织身份。

### 在Swagger UI中设置

1. 点击右上角 **Authorize** 🔓按钮
2. 在 `ApiKeyAuth (apiKey)` 中输入：
   - Value: `org1` (OEM) 或 `org2` (Manufacturer) 或 `org3` (Carrier/Platform)
3. 点击 **Authorize**
4. 点击 **Close**

现在所有请求都会携带这个Header！

### 在curl中使用

```bash
curl -X GET "http://localhost:8080/api/oem/order/list?pageSize=10" \
  -H "X-Org-ID: org1"
```

---

## 📊 数据模型速查

### CreateOrderRequest (创建订单)
```json
{
  "id": "string",              // 必填
  "manufacturerId": "string",  // 必填
  "items": [                   // 必填
    {
      "partNumber": "string",
      "partName": "string",
      "quantity": 0,
      "unitPrice": 0,
      "specification": "string"
    }
  ]
}
```

### UpdateStatusRequest (更新状态)
```json
{
  "status": "InProduction"  // 可选值: InProduction, Produced
}
```

### PickupGoodsRequest (取货)
```json
{
  "orderId": "string",     // 必填
  "shipmentId": "string"   // 必填
}
```

### UpdateLocationRequest (更新位置)
```json
{
  "location": "string"  // 必填，例如："北京市朝阳区"
}
```

---

## 🎯 Swagger UI功能说明

### 主要区域

```
┌────────────────────────────────────────┐
│  🔍 Search                     Authorize│
├────────────────────────────────────────┤
│  📑 Servers: http://localhost:8080/api │
├────────────────────────────────────────┤
│  📂 OEM (4 endpoints)                  │
│    POST /oem/order/create              │
│    PUT  /oem/order/{id}/receive        │
│    GET  /oem/order/{id}                │
│    GET  /oem/order/list                │
├────────────────────────────────────────┤
│  📂 Manufacturer (3 endpoints)         │
│  📂 Carrier (4 endpoints)              │
│  📂 Platform (1 endpoint)              │
├────────────────────────────────────────┤
│  📋 Models (数据模型定义)               │
└────────────────────────────────────────┘
```

### 按钮说明

- **Try it out** - 启用测试模式，可以修改参数
- **Execute** - 执行API请求
- **Cancel** - 取消测试模式
- **Download** - 下载OpenAPI规范文件

### 响应代码

- **200** - 成功
- **400** - 请求参数错误
- **500** - 服务器内部错误

---

## 💻 命令速查表

### 服务操作
```bash
# 启动服务
cd application/server && go run main.go

# 编译服务
go build -o supplychain-server

# 运行编译后的服务
./supplychain-server
```

### 文档操作
```bash
# 生成/更新OpenAPI文档
cd application/server && swag init

# 或使用完整路径
~/go/bin/swag init

# 验证文档（需要npm）
swagger-cli validate docs/swagger.yaml
```

### 依赖管理
```bash
# 更新依赖
go mod tidy

# 查看依赖
go list -m all

# 更新swag工具
go install github.com/swaggo/swag/cmd/swag@latest
```

---

## 🐛 常见问题

### Q: 访问/swagger/显示404？
**A:** 确保访问的是 `/swagger/index.html`（注意末尾的index.html）

### Q: Swagger UI加载很慢？
**A:** 这是正常的，首次加载需要下载Swagger UI资源

### Q: API测试报错"Network Error"？
**A:** 检查服务是否正在运行，端口是否正确

### Q: 某个API不显示？
**A:** 检查Handler方法是否有完整的godoc注释和@Router标签

### Q: 修改后文档没更新？
**A:** 需要运行 `swag init` 重新生成，然后重启服务

---

## 📚 相关文档

- **OPENAPI_IMPLEMENTATION_COMPLETED.md** - 完整实施报告
- **OPENAPI_FEASIBILITY_ANALYSIS.md** - 可行性分析
- **application/server/docs/README.md** - 文档目录说明

---

## 🎉 开始使用吧！

1. 启动服务：`go run main.go`
2. 访问：http://localhost:8080/swagger/index.html
3. 选择API并点击"Try it out"
4. 测试你的第一个API调用！

**享受自动化API文档带来的便利！** ✨

---

**文档版本**: v1.0  
**更新日期**: 2024-12-23  
**适用对象**: 开发人员、测试人员、前端工程师
