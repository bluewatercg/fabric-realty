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
// @Param        id   path      string  true  "订单ID"  example(ORDER001)
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
// @Param        id       path      string                 true  "订单ID"  example(ORDER001)
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
// @Param        id       path      string                   true  "物流单ID"  example(SHIP001)
// @Param        request  body      UpdateLocationRequest    true  "位置信息"
// @Success      200      {object}  utils.Response{data=string}  "位置更新成功"
// @Failure      400      {object}  utils.Response  "请求参数错误"
// @Failure      500      {object}  utils.Response  "服务器内部错误"
// @Router       /carrier/shipment/{id}/location [put]
// @Security     ApiKeyAuth
func (h *SupplyChainHandler) UpdateLocation(c *gin.Context) {
	id := c.Param("id") // shipmentId
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
// @Param        id   path      string  true  "订单ID"  example(ORDER001)
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
// @Param        id   path      string  true  "物流单ID"  example(SHIP001)
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
// @Param        id   path      string  true  "订单ID"  example(ORDER001)
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
// @Tags         OEM
// @Tags         Manufacturer
// @Tags         Carrier
// @Tags         Platform
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
