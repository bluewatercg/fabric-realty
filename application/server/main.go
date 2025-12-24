package main

import (
    "application/api"
    "application/config"
    "application/pkg/fabric"
    "fmt"
    "log"

    "github.com/gin-gonic/gin"
    swaggerFiles "github.com/swaggo/gin-swagger"
    "github.com/swaggo/gin-swagger/assets"
)

// @title 供应链协同系统 API 文档
// @version 1.0
// @description 基于 Hyperledger Fabric 的汽配供应链协同系统 API 文档
// @host localhost:8080
// @BasePath /api

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

    // Swagger 路由
    r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.NewHandler(
        ginSwagger.InstanceName("swagger"),
        ginSwagger.PathPrefix("/swagger"),
    )))

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
    if err := r.Run(addr); err != nil {
        log.Fatalf("启动服务器失败：%v", err)
    }
}
