# OpenAPI快速实施指南

基于可行性分析报告，本文档提供详细的实施步骤和代码示例。

## 一、环境准备

### 1.1 安装swag CLI工具

```bash
# 方式1: 使用go install（推荐）
go install github.com/swaggo/swag/cmd/swag@latest

# 方式2: 下载二进制文件
# 访问 https://github.com/swaggo/swag/releases

# 验证安装
swag --version
```

### 1.2 添加Go依赖

```bash
cd application/server

# 添加依赖
go get -u github.com/swaggo/swag
go get -u github.com/swaggo/gin-swagger
go get -u github.com/swaggo/files

# 更新依赖
go mod tidy
```

---

## 二、代码改造

### 2.1 创建数据模型文件

创建 `application/server/api/models.go`:

```go
package api

// CreateOrderRequest 创建订单请求
type CreateOrderRequest struct {
	ID             string      `json:"id" binding:"required" example:"ORDER001" minLength:"1"`
	ManufacturerID string      `json:"manufacturerId" binding:"required" example:"MFG001"`
	Items          []OrderItem `json:"items" binding:"required"`
}

// OrderItem 订单项
type OrderItem struct {
	PartNumber  string  `json:"partNumber" example:"PART-12345"`
	PartName    string  `json:"partName" example:"发动机缸体"`
	Quantity    int     `json:"quantity" example:"100" minimum:"1"`
	UnitPrice   float64 `json:"unitPrice" example:"125.50" minimum:"0"`
	Specification string `json:"specification,omitempty" example:"标准规格"`
}

// Order 订单详情
type Order struct {
	ID             string      `json:"id" example:"ORDER001"`
	OemID          string      `json:"oemId" example:"OEM001"`
	ManufacturerID string      `json:"manufacturerId" example:"MFG001"`
	Items          []OrderItem `json:"items"`
	Status         string      `json:"status" example:"Created" enums:"Created,Accepted,InProduction,Produced,PickedUp,InTransit,Delivered"`
	CreatedAt      string      `json:"createdAt" example:"2024-01-01T00:00:00Z"`
	UpdatedAt      string      `json:"updatedAt,omitempty" example:"2024-01-02T10:30:00Z"`
	AcceptedAt     string      `json:"acceptedAt,omitempty"`
	ProducedAt     string      `json:"producedAt,omitempty"`
	DeliveredAt    string      `json:"deliveredAt,omitempty"`
}

// UpdateStatusRequest 更新状态请求
type UpdateStatusRequest struct {
	Status string `json:"status" binding:"required" example:"InProduction" enums:"InProduction,Produced"`
}

// PickupGoodsRequest 取货请求
type PickupGoodsRequest struct {
	OrderID    string `json:"orderId" binding:"required" example:"ORDER001"`
	ShipmentID string `json:"shipmentId" binding:"required" example:"SHIP001"`
}

// UpdateLocationRequest 更新位置请求
type UpdateLocationRequest struct {
	Location string `json:"location" binding:"required" example:"北京市朝阳区"`
}

// Shipment 物流信息
type Shipment struct {
	ID        string              `json:"id" example:"SHIP001"`
	OrderID   string              `json:"orderId" example:"ORDER001"`
	CarrierID string              `json:"carrierId" example:"CARRIER001"`
	Status    string              `json:"status" example:"InTransit"`
	Locations []ShipmentLocation  `json:"locations"`
	PickupAt  string              `json:"pickupAt" example:"2024-01-03T08:00:00Z"`
	UpdatedAt string              `json:"updatedAt" example:"2024-01-03T12:00:00Z"`
}

// ShipmentLocation 物流位置记录
type ShipmentLocation struct {
	Location  string `json:"location" example:"北京市朝阳区"`
	Timestamp string `json:"timestamp" example:"2024-01-03T12:00:00Z"`
}

// OrderListResponse 订单列表响应
type OrderListResponse struct {
	Orders   []Order `json:"orders"`
	Bookmark string  `json:"bookmark,omitempty" example:"g1AAAAG..."`
}

// ErrorResponse 错误响应
type ErrorResponse struct {
	Code    int    `json:"code" example:"500"`
	Message string `json:"message" example:"操作失败"`
	Details string `json:"details,omitempty"`
}
```

### 2.2 修改main.go

```go
package main

import (
	"application/api"
	"application/config"
	"application/pkg/fabric"
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	
	_ "application/docs" // 导入生成的docs包（首次需要先运行swag init）
)

// @title           汽配供应链管理系统 API
// @version         1.0
// @description     基于Hyperledger Fabric的汽配供应链溯源管理系统，支持主机厂、零部件厂商、承运商多角色协同。
// @termsOfService  http://example.com/terms/

// @contact.name   技术支持
// @contact.url    http://example.com/support
// @contact.email  support@example.com

// @license.name  Apache 2.0
// @license.url   http://www.apache.org/licenses/LICENSE-2.0.html

// @host      localhost:8080
// @BasePath  /api

// @tag.name         OEM
// @tag.description  主机厂相关接口 - 创建订单、确认收货、查询订单
// @tag.name         Manufacturer
// @tag.description  零部件厂商接口 - 接受订单、更新生产状态
// @tag.name         Carrier
// @tag.description  承运商接口 - 取货、更新物流位置、查询物流信息
// @tag.name         Platform
// @tag.description  平台监管接口 - 全局订单查询

// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name X-Org-ID
// @description 组织身份标识 (可选值: org1-OEM, org2-Manufacturer, org3-Carrier/Platform)

func main() {
	// 初始化配置
	if err := config.InitConfig(); err != nil {
		log.Fatalf("初始化配置失败：%v", err)
	}

	// 初始化 Fabric 客户端
	if err := fabric.InitFabric(); err != nil {
		log.Fatalf("初始化Fabric客户端失败：%v", err)
	}

	// 创建 Gin 路由
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Swagger文档路由
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	apiGroup := r.Group("/api")

	// 注册路由
	scHandler := api.NewSupplyChainHandler()

	// 主机厂接口 (Org1)
	oemGroup := apiGroup.Group("/oem")
	{
		oemGroup.POST("/order/create", scHandler.CreateOrder)
		oemGroup.PUT("/order/:id/receive", scHandler.ConfirmReceipt)
		oemGroup.GET("/order/:id", scHandler.QueryOrder)
		oemGroup.GET("/order/list", scHandler.QueryOrderList)
	}

	// 零部件厂商接口 (Org2)
	manufacturerGroup := apiGroup.Group("/manufacturer")
	{
		manufacturerGroup.PUT("/order/:id/accept", scHandler.AcceptOrder)
		manufacturerGroup.PUT("/order/:id/status", scHandler.UpdateStatus)
		manufacturerGroup.GET("/order/list", scHandler.QueryOrderList)
	}

	// 承运商接口 (Org3)
	carrierGroup := apiGroup.Group("/carrier")
	{
		carrierGroup.POST("/shipment/pickup", scHandler.PickupGoods)
		carrierGroup.PUT("/shipment/:id/location", scHandler.UpdateLocation)
		carrierGroup.GET("/shipment/:id", scHandler.QueryShipment)
		carrierGroup.GET("/order/list", scHandler.QueryOrderList)
	}

	// 平台方接口 (Org3 - 监管)
	platformGroup := apiGroup.Group("/platform")
	{
		platformGroup.GET("/order/list", scHandler.QueryOrderList)
	}

	// 启动服务器
	addr := fmt.Sprintf(":%d", config.GlobalConfig.Server.Port)
	log.Printf("服务器启动于 %s", addr)
	log.Printf("Swagger文档地址: http://localhost%s/swagger/index.html", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("启动服务器失败：%v", err)
	}
}
```

### 2.3 修改supply_chain.go添加Swagger注释

创建 `application/server/api/supply_chain_swagger.go` (或直接修改原文件):

```go
package api

import (
	"application/service"
	"application/utils"
	"github.com/gin-gonic/gin"
	"log"
	"strconv"
)

type SupplyChainHandler struct {
	scService *service.SupplyChainService
}

func NewSupplyChainHandler() *SupplyChainHandler {
	return &SupplyChainHandler{
		scService: &service.SupplyChainService{},
	}
}

// CreateOrder godoc
// @Summary      创建订单
// @Description  主机厂(OEM)发布零部件采购订单到指定制造商
// @Tags         OEM
// @Accept       json
// @Produce      json
// @Param        request  body      CreateOrderRequest  true  "订单信息"
// @Success      200      {object}  utils.Response{data=string}  "订单创建成功"
// @Failure      400      {object}  utils.Response  "请求参数错误"
// @Failure      500      {object}  utils.Response  "服务器内部错误"
// @Router       /oem/order/create [post]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) CreateOrder(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, "无效的请求参数")
		return
	}

	if err := h.scService.CreateOrder(req.ID, req.ManufacturerID, req.Items); err != nil {
		log.Printf("CreateOrder Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}

	utils.SuccessWithMessage(c, "订单已发布", nil)
}

// AcceptOrder godoc
// @Summary      接受订单
// @Description  零部件厂商接受主机厂发布的订单
// @Tags         Manufacturer
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "订单ID"  example:"ORDER001"
// @Success      200  {object}  utils.Response{data=string}  "订单接受成功"
// @Failure      500  {object}  utils.Response  "服务器内部错误"
// @Router       /manufacturer/order/{id}/accept [put]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) AcceptOrder(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.AcceptOrder(id); err != nil {
		log.Printf("AcceptOrder Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已接受", nil)
}

// UpdateStatus godoc
// @Summary      更新生产状态
// @Description  零部件厂商更新订单的生产进度状态
// @Tags         Manufacturer
// @Accept       json
// @Produce      json
// @Param        id       path      string                 true  "订单ID"  example:"ORDER001"
// @Param        request  body      UpdateStatusRequest    true  "状态信息"
// @Success      200      {object}  utils.Response{data=string}  "状态更新成功"
// @Failure      400      {object}  utils.Response  "请求参数错误"
// @Failure      500      {object}  utils.Response  "服务器内部错误"
// @Router       /manufacturer/order/{id}/status [put]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) UpdateStatus(c *gin.Context) {
	id := c.Param("id")
	var req UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, "参数错误")
		return
	}

	log.Printf("DEBUG: Updating Order Status - ID: [%s], NewStatus: [%s]", id, req.Status)

	if err := h.scService.UpdateProductionStatus(id, req.Status); err != nil {
		log.Printf("UpdateStatus Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "状态已更新", nil)
}

// PickupGoods godoc
// @Summary      取货并生成物流单
// @Description  承运商从制造商处取货，创建物流跟踪单
// @Tags         Carrier
// @Accept       json
// @Produce      json
// @Param        request  body      PickupGoodsRequest  true  "取货信息"
// @Success      200      {object}  utils.Response{data=string}  "取货成功"
// @Failure      400      {object}  utils.Response  "请求参数错误"
// @Failure      500      {object}  utils.Response  "服务器内部错误"
// @Router       /carrier/shipment/pickup [post]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) PickupGoods(c *gin.Context) {
	var req PickupGoodsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, "参数错误")
		return
	}

	if err := h.scService.PickupGoods(req.OrderID, req.ShipmentID); err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "已取货并生成物流单", nil)
}

// UpdateLocation godoc
// @Summary      更新物流位置
// @Description  承运商上报货物当前位置信息
// @Tags         Carrier
// @Accept       json
// @Produce      json
// @Param        id       path      string                   true  "物流单ID"  example:"SHIP001"
// @Param        request  body      UpdateLocationRequest    true  "位置信息"
// @Success      200      {object}  utils.Response{data=string}  "位置更新成功"
// @Failure      400      {object}  utils.Response  "请求参数错误"
// @Failure      500      {object}  utils.Response  "服务器内部错误"
// @Router       /carrier/shipment/{id}/location [put]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) UpdateLocation(c *gin.Context) {
	id := c.Param("id")
	var req UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, "参数错误")
		return
	}

	if err := h.scService.UpdateLocation(id, req.Location); err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "位置已更新", nil)
}

// ConfirmReceipt godoc
// @Summary      确认收货
// @Description  主机厂确认收到货物，订单完成
// @Tags         OEM
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "订单ID"  example:"ORDER001"
// @Success      200  {object}  utils.Response{data=string}  "签收成功"
// @Failure      500  {object}  utils.Response  "服务器内部错误"
// @Router       /oem/order/{id}/receive [put]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) ConfirmReceipt(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.ConfirmReceipt(id); err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已签收完成", nil)
}

// QueryShipment godoc
// @Summary      查询物流详情
// @Description  根据物流单ID查询物流跟踪信息
// @Tags         Carrier
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "物流单ID"  example:"SHIP001"
// @Success      200  {object}  utils.Response{data=Shipment}  "查询成功"
// @Failure      500  {object}  utils.Response  "服务器内部错误"
// @Router       /carrier/shipment/{id} [get]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) QueryShipment(c *gin.Context) {
	id := c.Param("id")
	shipment, err := h.scService.QueryShipment(id)
	if err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, shipment)
}

// QueryOrder godoc
// @Summary      查询订单详情
// @Description  根据订单ID查询订单的完整信息
// @Tags         OEM
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "订单ID"  example:"ORDER001"
// @Success      200  {object}  utils.Response{data=Order}  "查询成功"
// @Failure      500  {object}  utils.Response  "服务器内部错误"
// @Router       /oem/order/{id} [get]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) QueryOrder(c *gin.Context) {
	id := c.Param("id")
	order, err := h.scService.QueryOrder(id)
	if err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, order)
}

// QueryOrderList godoc
// @Summary      分页查询订单列表
// @Description  支持分页查询订单列表，使用bookmark实现翻页
// @Tags         OEM, Manufacturer, Carrier, Platform
// @Accept       json
// @Produce      json
// @Param        pageSize  query     int     false  "每页数量"  default(10)  minimum(1)  maximum(100)
// @Param        bookmark  query     string  false  "分页书签（上次查询返回的bookmark）"
// @Success      200       {object}  utils.Response{data=OrderListResponse}  "查询成功"
// @Failure      500       {object}  utils.Response  "服务器内部错误"
// @Router       /oem/order/list [get]
// @Router       /manufacturer/order/list [get]
// @Router       /carrier/order/list [get]
// @Router       /platform/order/list [get]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) QueryOrderList(c *gin.Context) {
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "10"))
	bookmark := c.DefaultQuery("bookmark", "")

	result, err := h.scService.QueryOrderList(int32(pageSize), bookmark)
	if err != nil {
		log.Printf("QueryOrderList Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}

	utils.Success(c, result)
}
```

---

## 三、生成文档

### 3.1 执行生成命令

```bash
cd application/server

# 生成swagger文档
swag init

# 输出示例：
# 2024/12/23 15:30:00 Generate swagger docs....
# 2024/12/23 15:30:00 Generate general API Info
# 2024/12/23 15:30:00 Generating utils.Response
# 2024/12/23 15:30:00 Generating api.Order
# 2024/12/23 15:30:00 create docs.go at  docs/docs.go
# 2024/12/23 15:30:00 create swagger.json at  docs/swagger.json
# 2024/12/23 15:30:00 create swagger.yaml at  docs/swagger.yaml
```

### 3.2 验证生成结果

```bash
ls -la docs/
# 应该看到：
# docs.go
# swagger.json
# swagger.yaml
```

### 3.3 将docs目录添加到git（首次）

```bash
# 如果.gitignore中忽略了docs，需要调整
echo "!application/server/docs/" >> .gitignore
git add application/server/docs/
```

---

## 四、启动和测试

### 4.1 启动服务

```bash
cd application/server
go run main.go
```

### 4.2 访问Swagger UI

浏览器打开：
```
http://localhost:8080/swagger/index.html
```

### 4.3 测试API

在Swagger UI中：
1. 点击任意API端点
2. 点击 "Try it out"
3. 填写参数
4. 点击 "Execute"
5. 查看响应结果

---

## 五、持续维护

### 5.1 添加新API的流程

1. **定义数据模型** (如需要)
```go
// 在api/models.go中添加
type NewFeatureRequest struct {
    Field string `json:"field" example:"value"`
}
```

2. **实现Handler方法**
```go
// NewFeature godoc
// @Summary      新功能
// @Description  新功能描述
// @Tags         OEM
// @Param        request  body  NewFeatureRequest  true  "请求参数"
// @Success      200  {object}  utils.Response
// @Router       /oem/new-feature [post]
func (h *SupplyChainHandler) NewFeature(c *gin.Context) {
    // implementation
}
```

3. **重新生成文档**
```bash
swag init
```

4. **重启服务验证**

### 5.2 文档规范检查

使用 [swagger-cli](https://www.npmjs.com/package/swagger-cli) 验证：

```bash
npm install -g swagger-cli
swagger-cli validate application/server/docs/swagger.yaml
```

### 5.3 CI/CD集成

在 `.github/workflows/api-docs.yml`:

```yaml
name: API Documentation

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.23'
      
      - name: Install swag
        run: go install github.com/swaggo/swag/cmd/swag@latest
      
      - name: Generate Swagger docs
        run: |
          cd application/server
          swag init
      
      - name: Check for changes
        run: |
          git diff --exit-code docs/ || (echo "文档未更新！请运行 swag init" && exit 1)
      
      - name: Validate OpenAPI
        run: |
          npm install -g swagger-cli
          swagger-cli validate application/server/docs/swagger.yaml
```

---

## 六、高级功能

### 6.1 自定义Swagger UI配置

```go
// main.go
url := ginSwagger.URL("http://localhost:8080/swagger/doc.json")
r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler, url))
```

### 6.2 生成客户端SDK

使用 [swagger-codegen](https://github.com/swagger-api/swagger-codegen):

```bash
# 生成TypeScript客户端
swagger-codegen generate \
  -i application/server/docs/swagger.json \
  -l typescript-fetch \
  -o clients/typescript

# 生成Python客户端
swagger-codegen generate \
  -i application/server/docs/swagger.json \
  -l python \
  -o clients/python
```

### 6.3 导出静态文档

使用 [Redoc](https://github.com/Redocly/redoc):

```bash
npx redoc-cli bundle application/server/docs/swagger.yaml \
  -o docs/api-documentation.html
```

---

## 七、常见问题

### Q1: swag init 报错 "cannot find package"

**解决**：
```bash
go mod tidy
go mod download
```

### Q2: 文档中看不到某个API

**原因**：Handler方法缺少godoc注释

**解决**：确保每个导出的Handler方法都有 `// FunctionName godoc` 注释

### Q3: 数据模型显示为 `interface{}`

**原因**：返回类型为 `map[string]interface{}`

**解决**：定义明确的struct并在@Success注释中指定

### Q4: 如何为不同环境配置不同的host

**方法1**：使用环境变量
```go
// @host ${API_HOST}
```

**方法2**：生成时指定
```bash
swag init --host api.example.com
```

---

## 八、检查清单

实施完成后，请确认：

- [ ] swag工具已安装并可用
- [ ] go.mod已添加所需依赖
- [ ] main.go包含API总体信息注释
- [ ] main.go集成了swagger UI路由
- [ ] 所有Handler方法添加了完整注释
- [ ] 定义了所有请求/响应模型
- [ ] swag init成功生成docs目录
- [ ] Swagger UI可正常访问
- [ ] 所有API在文档中可见
- [ ] API测试功能正常
- [ ] docs目录已提交到git
- [ ] 团队成员了解维护流程

---

## 参考

- [Swag 官方文档](https://github.com/swaggo/swag)
- [声明式注释格式](https://github.com/swaggo/swag#declarative-comments-format)
- [Gin-Swagger集成](https://github.com/swaggo/gin-swagger)
- [OpenAPI 3.0规范](https://swagger.io/specification/)

---

**文档版本**: v1.0  
**更新日期**: 2024-12-23
