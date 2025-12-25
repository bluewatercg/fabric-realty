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

// CreateOrder 主机厂发布订单
// @Summary 主机厂创建采购订单
// @Description OEM 创建新的采购订单，订单状态为 CREATED
// @Tags OEM
// @Accept json
// @Produce json
// @Param order body CreateOrderRequest true "订单信息"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/create [post]
func (h *SupplyChainHandler) CreateOrder(c *gin.Context) {
	var req struct {
		ID             string      `json:"id"`
		ManufacturerID string      `json:"manufacturerId"`
		Items          interface{} `json:"items"`
	}
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

// AcceptOrder 零部件厂接受订单
// @Summary 零部件厂商接受订单
// @Description Manufacturer 接受 OEM 创建的订单，状态变为 ACCEPTED
// @Tags Manufacturer
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /api/manufacturer/order/{id}/accept [put]
func (h *SupplyChainHandler) AcceptOrder(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.AcceptOrder(id); err != nil {
		log.Printf("AcceptOrder Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已接受", nil)
}

// UpdateStatus 更新状态
// @Summary 更新生产状态
// @Description Manufacturer 更新订单的生产状态 (PRODUCING/PRODUCED/READY)
// @Tags Manufacturer
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Param status body UpdateStatusRequest true "新状态"
// @Success 200 {object} utils.Response
// @Router /api/manufacturer/order/{id}/status [put]
func (h *SupplyChainHandler) UpdateStatus(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Status string `json:"status"`
	}
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

// PickupGoods 承运商取货
// @Summary 承运商取货
// @Description Carrier 取货并生成物流单，订单状态变为 READY
// @Tags Carrier
// @Accept json
// @Produce json
// @Param data body PickupGoodsRequest true "取货信息"
// @Success 200 {object} utils.Response
// @Router /api/carrier/shipment/pickup [post]
func (h *SupplyChainHandler) PickupGoods(c *gin.Context) {
	var req struct {
		OrderID    string `json:"orderId"`
		ShipmentID string `json:"shipmentId"`
	}
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

// UpdateLocation 更新物流位置
// @Summary 更新物流位置
// @Description Carrier 更新物流单的位置信息
// @Tags Carrier
// @Accept json
// @Produce json
// @Param id path string true "物流单ID"
// @Param location body UpdateLocationRequest true "位置信息"
// @Success 200 {object} utils.Response
// @Router /api/carrier/shipment/{id}/location [put]
func (h *SupplyChainHandler) UpdateLocation(c *gin.Context) {
	id := c.Param("id") // shipmentId
	var req struct {
		Location string `json:"location"`
	}
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

// ConfirmReceipt 主机厂签收
// @Summary OEM 确认收货
// @Description OEM 确认收货，订单状态变为 RECEIVED
// @Tags OEM
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/{id}/receive [put]
func (h *SupplyChainHandler) ConfirmReceipt(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.ConfirmReceipt(id); err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已签收完成", nil)
}

// QueryShipment 查询物流详情
// @Summary 查询物流详情
// @Description 查询物流单的详细信息
// @Tags Carrier
// @Accept json
// @Produce json
// @Param id path string true "物流单ID"
// @Success 200 {object} utils.Response
// @Router /api/carrier/shipment/{id} [get]
func (h *SupplyChainHandler) QueryShipment(c *gin.Context) {
	id := c.Param("id")
	shipment, err := h.scService.QueryShipment(id)
	if err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, shipment)
}

// QueryOrder 查询详情
// @Summary 查询订单详情
// @Description 根据订单ID查询订单详细信息
// @Tags OEM
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/{id} [get]
func (h *SupplyChainHandler) QueryOrder(c *gin.Context) {
	id := c.Param("id")
	order, err := h.scService.QueryOrder(id)
	if err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, order)
}

// QueryOrderList 分页列表
// @Summary 查询订单列表
// @Description 分页查询订单列表，支持根据角色过滤
// @Tags OEM
// @Accept json
// @Produce json
// @Param pageSize query int false "每页数量" default(10)
// @Param bookmark query string false "分页书签"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/list [get]
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

// QueryOrderHistory 查询订单历史
// @Summary 查询订单历史记录
// @Description 查询订单的完整状态变更历史，展示区块链不可篡改的审计追踪
// @Tags OEM
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /api/oem/order/{id}/history [get]
func (h *SupplyChainHandler) QueryOrderHistory(c *gin.Context) {
	id := c.Param("id")
	history, err := h.scService.QueryOrderHistory(id)
	if err != nil {
		log.Printf("QueryOrderHistory Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, history)
}

// QueryShipmentHistory 查询物流单历史
// @Summary 查询物流单历史记录
// @Description 查询物流单的完整位置变更历史
// @Tags Carrier
// @Accept json
// @Produce json
// @Param id path string true "物流单ID"
// @Success 200 {object} utils.Response
// @Router /api/carrier/shipment/{id}/history [get]
func (h *SupplyChainHandler) QueryShipmentHistory(c *gin.Context) {
	id := c.Param("id")
	history, err := h.scService.QueryShipmentHistory(id)
	if err != nil {
		log.Printf("QueryShipmentHistory Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, history)
}

// @Summary 查询所有数据
// @Description 查询账本上的所有数据
// @Tags Platform
// @Accept json
// @Produce json
// @Param pageSize query int false "每页数量" default(10)
// @Param bookmark query string false "分页书签"
// @Success 200 {object} utils.Response
// @Router /api/platform/all [get]
func (h *SupplyChainHandler) QueryAllLedgerData(c *gin.Context) {
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "10"))
	bookmark := c.DefaultQuery("bookmark", "")

	result, err := h.scService.QueryAllLedgerData(int32(pageSize), bookmark)
	if err != nil {
		log.Printf("QueryAllLedgerData Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.Success(c, result)
}
