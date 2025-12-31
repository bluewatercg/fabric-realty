# 问题解决报告

## 📋 问题描述

用户在测试 API 时遇到 404 错误：

```bash
curl -X GET "http://192.168.1.41:8080/api/api/platform/all?pageSize=10"
# 返回: 404 page not found

curl -X GET "http://192.168.1.41:8080/api/api/oem/order/111"
# 返回: 404 page not found
```

从服务器日志可以看到：
```
[GIN] 2025/12/31 - 13:57:40 | 404 | 1.543µs | 192.168.1.41 | GET "/api/api/oem/order/111"
```

## 🔍 问题分析

### 根本原因
URL 路径中**重复了 `/api` 前缀**。

### 技术细节
在 `main.go` 中，服务器配置如下：

```go
// @BasePath /api

r := gin.Default()
apiGroup := r.Group("/api")
{
    oemGroup := apiGroup.Group("/oem")
    // ...
}
```

这意味着：
- 路由组已经设置为 `/api`
- 所有端点都会自动添加 `/api` 前缀
- 完整路径是：`/api` + `/oem/order/create` = `/api/oem/order/create`

### 错误示例
```
用户输入: /api/api/oem/order/111
实际路径: /api + /api/oem/order/111 = /api/api/oem/order/111 ❌
正确路径: /api/oem/order/111 ✅
```

## ✅ 解决方案

### 1. 正确的 URL 格式

```bash
# ✅ 正确
curl -X GET "http://192.168.1.41:8080/api/platform/all?pageSize=10"
curl -X GET "http://192.168.1.41:8080/api/oem/order/111"

# ❌ 错误
curl -X GET "http://192.168.1.41:8080/api/api/platform/all?pageSize=10"
curl -X GET "http://192.168.1.41:8080/api/api/oem/order/111"
```

### 2. URL 结构说明

```
完整 URL = 基础地址 + API 路径
         = http://192.168.1.41:8080 + /api/oem/order/111
         = http://192.168.1.41:8080/api/oem/order/111
```

### 3. 所有正确的端点

#### OEM (主机厂)
```
POST   http://192.168.1.41:8080/api/oem/order/create
GET    http://192.168.1.41:8080/api/oem/order/{id}
GET    http://192.168.1.41:8080/api/oem/order/list
GET    http://192.168.1.41:8080/api/oem/order/{id}/history
PUT    http://192.168.1.41:8080/api/oem/order/{id}/receive
```

#### Manufacturer (厂商)
```
PUT    http://192.168.1.41:8080/api/manufacturer/order/{id}/accept
PUT    http://192.168.1.41:8080/api/manufacturer/order/{id}/status
GET    http://192.168.1.41:8080/api/manufacturer/order/list
```

#### Carrier (承运商)
```
POST   http://192.168.1.41:8080/api/carrier/shipment/pickup
GET    http://192.168.1.41:8080/api/carrier/shipment/{id}
GET    http://192.168.1.41:8080/api/carrier/shipment/{id}/history
PUT    http://192.168.1.41:8080/api/carrier/shipment/{id}/location
GET    http://192.168.1.41:8080/api/carrier/order/list
```

#### Platform (平台)
```
GET    http://192.168.1.41:8080/api/platform/all
GET    http://192.168.1.41:8080/api/platform/order/list
```

## 📝 已采取的改进措施

### 1. 更新文档
- ✅ 在 `README.md` 开头添加了醒目的 URL 格式说明
- ✅ 在 `QUICK_REFERENCE.md` 添加了重要提示
- ✅ 创建了 `TROUBLESHOOTING.md` 详细说明常见问题

### 2. 创建测试工具
- ✅ `test_api.sh` - 自动化测试脚本，包含所有正确的 URL 示例
- ✅ 脚本会自动测试完整的业务流程

### 3. 文档改进
所有文档现在都明确标注：
- 基础 URL
- API 路径格式
- 正确和错误的示例对比

## 🧪 验证测试

### 测试正确的 URL

```bash
# 1. 查询所有数据（平台）
curl -X GET "http://192.168.1.41:8080/api/platform/all?pageSize=10" \
  -H "accept: application/json"

# 2. 查询订单列表（OEM）
curl -X GET "http://192.168.1.41:8080/api/oem/order/list?pageSize=10" \
  -H "accept: application/json"

# 3. 创建订单
curl -X POST "http://192.168.1.41:8080/api/oem/order/create" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ORDER_TEST_001",
    "manufacturerId": "MANUFACTURER_A",
    "items": [{"name": "test_part", "quantity": 10}]
  }'
```

### 使用自动化测试脚本

```bash
# 给脚本添加执行权限
chmod +x docs/test_api.sh

# 运行完整测试
./docs/test_api.sh
```

脚本会自动测试所有 API 端点，并显示彩色的成功/失败状态。

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| `README.md` | 完整的 API 文档使用指南（已更新） |
| `QUICK_REFERENCE.md` | 快速参考卡片（已更新） |
| `TROUBLESHOOTING.md` | 常见问题和解决方案（新建） |
| `test_api.sh` | 自动化测试脚本（新建） |
| `openapi.yaml` | OpenAPI 3.0 规范文档 |
| `swagger.json` | Swagger 2.0 文档 |

## 🎯 关键要点

1. **不要重复 `/api` 前缀**
   - 服务器已经配置了 `/api` 作为基础路径
   - 直接使用 `/api/oem/order/create` 即可

2. **使用 Swagger UI 避免错误**
   - 访问 `http://192.168.1.41:8080/swagger/index.html`
   - 直接在 UI 中测试，自动生成正确的 URL

3. **参考提供的测试脚本**
   - 所有示例都是正确的格式
   - 可以直接复制使用

4. **遇到 404 错误时**
   - 首先检查 URL 格式
   - 确认没有重复 `/api`
   - 查看 `TROUBLESHOOTING.md`

## ✅ 问题已解决

现在用户可以：
- ✅ 使用正确的 URL 格式访问所有 API
- ✅ 参考详细的文档和示例
- ✅ 使用自动化测试脚本验证 API
- ✅ 在遇到问题时快速找到解决方案

---

**创建时间**: 2025-12-31  
**问题类型**: URL 格式错误  
**状态**: ✅ 已解决
