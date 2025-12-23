package main

import (
	"application/api"
	"application/config"
	_ "application/docs"
	"application/pkg/fabric"
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// @title           汽配供应链管理系统 API
// @version         1.0
// @description     基于Hyperledger Fabric的汽配供应链溯源管理系统，支持主机厂、零部件厂商、承运商多角色协同
// @termsOfService  http://swagger.io/terms/

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
