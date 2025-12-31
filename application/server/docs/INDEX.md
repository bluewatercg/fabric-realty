# 📚 文档索引

欢迎使用供应链协同系统 API 文档！这里是所有文档的快速导航。

## 🚀 快速开始

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** | 快速参考卡片 | 快速查找 API 端点和命令 |
| **[README.md](README.md)** | 完整使用指南 | 详细了解如何使用 API 文档 |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | 常见问题解决 | 遇到问题时查看 |

## 📖 API 规范文档

| 文件 | 格式 | 版本 | 用途 |
|------|------|------|------|
| **swagger.json** | JSON | Swagger 2.0 | Postman 导入、工具集成 |
| **swagger.yaml** | YAML | Swagger 2.0 | 人类可读、在线编辑器 |
| **openapi.yaml** | YAML | OpenAPI 3.0 | 现代标准、代码生成 |
| **docs.go** | Go | - | Go 代码中的文档定义 |

## 🧪 测试工具

| 文件 | 说明 |
|------|------|
| **[test_api.sh](test_api.sh)** | 自动化测试脚本，测试所有 API 端点 |
| **[postman_collection.json](postman_collection.json)** | Postman 测试集合 |

## 📝 参考文档

| 文档 | 说明 |
|------|------|
| **[OPENAPI_SUMMARY.md](OPENAPI_SUMMARY.md)** | OpenAPI 支持完成总结 |
| **[ISSUE_RESOLVED.md](ISSUE_RESOLVED.md)** | 问题解决报告（URL 格式问题） |

## 🎯 根据需求选择文档

### 我想快速测试 API
→ 查看 **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)**

### 我遇到了 404 错误
→ 查看 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** 的 "404 错误 - URL 路径问题" 部分

### 我想了解完整的 API 功能
→ 访问 **Swagger UI**: http://192.168.1.41:8080/swagger/index.html

### 我想导入到 Postman
→ 导入 **[postman_collection.json](postman_collection.json)**

### 我想生成客户端代码
→ 使用 **[openapi.yaml](openapi.yaml)** 和 OpenAPI Generator

### 我想自动化测试所有 API
→ 运行 **[test_api.sh](test_api.sh)**

### 我想了解项目的 OpenAPI 支持情况
→ 查看 **[OPENAPI_SUMMARY.md](OPENAPI_SUMMARY.md)**

## ⚠️ 重要提示

### URL 格式
```
✅ 正确: http://192.168.1.41:8080/api/oem/order/create
❌ 错误: http://192.168.1.41:8080/api/api/oem/order/create
```

**不要在路径中重复 `/api`！**

详见：[TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 📍 在线资源

| 资源 | URL |
|------|-----|
| **Swagger UI** | http://192.168.1.41:8080/swagger/index.html |
| **本地 Swagger UI** | http://localhost:8080/swagger/index.html |
| **Swagger Editor** | https://editor.swagger.io/ |
| **Swagger Validator** | https://validator.swagger.io/ |

## 🔧 常用命令

### 重新生成文档
```bash
swag init -g main.go --output ./docs
```

### 验证文档
```bash
swagger-cli validate docs/swagger.yaml
swagger-cli validate docs/openapi.yaml
```

### 运行测试
```bash
chmod +x docs/test_api.sh
./docs/test_api.sh
```

## 📊 API 统计

- **总端点数**: 15
- **OEM 端点**: 5
- **Manufacturer 端点**: 3
- **Carrier 端点**: 5
- **Platform 端点**: 2

## 🎓 学习路径

### 1. 新手入门
1. 阅读 [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
2. 访问 Swagger UI 查看交互式文档
3. 运行 [test_api.sh](test_api.sh) 了解 API 工作流程

### 2. 深入了解
1. 阅读 [README.md](README.md) 了解完整功能
2. 查看 [openapi.yaml](openapi.yaml) 了解详细规范
3. 导入 Postman 集合进行手动测试

### 3. 集成开发
1. 使用 OpenAPI Generator 生成客户端代码
2. 参考 [OPENAPI_SUMMARY.md](OPENAPI_SUMMARY.md) 了解最佳实践
3. 遇到问题查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 📞 获取帮助

如果您在使用过程中遇到问题：

1. 首先查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. 检查 [ISSUE_RESOLVED.md](ISSUE_RESOLVED.md) 中是否有类似问题
3. 查看服务器日志：`docker logs fabric-realty.server`
4. 访问 Swagger UI 进行交互式测试

## 🔄 文档更新

- **最后更新**: 2025-12-31
- **版本**: 1.0
- **状态**: ✅ 完整且最新

---

**提示**: 建议从 [QUICK_REFERENCE.md](QUICK_REFERENCE.md) 开始，它包含了最常用的信息！
