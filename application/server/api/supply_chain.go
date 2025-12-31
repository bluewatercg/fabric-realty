package api

import (
	"application/service"
	"application/utils"
	"log"
	"strconv"

	"github.com/gin-gonic/gin"
)

type SupplyChainHandler struct {
	scService *service.SupplyChainService
}

func NewSupplyChainHandler() *SupplyChainHandler {
	return &SupplyChainHandler{
		scService: &service.SupplyChainService{},
	}
}

// CreateOrderRequest 创建订单请求
type CreateOrderRequest struct {
	ID             string      `json:"id" example:"ORDER_2024_001" binding:"required"`                                       // 订单ID
	ManufacturerID string      `json:"manufacturerId" example:"MANUFACTURER_A" binding:"required"`                           // 制造商ID
	Items          interface{} `json:"items" example:"[{\"name\":\"engine_part_xyz\",\"quantity\":100}]" binding:"required"` // 订单项目列表
}

// CreateOrder 主机厂发布订单
// @Summary      主机厂创建采购订单
// @Description  OEM 创建新的采购订单，订单状态为 CREATED
// @Tags         OEM
// @Accept       json
// @Produce      json
// @Param        order  body      CreateOrderRequest  true  "订单信息"
// @Success      200    {object}  utils.Response{data=string}  "订单创建成功"
// @Failure      400    {object}  utils.Response  "请求参数错误"
// @Failure      500    {object}  utils.Response  "服务器内部错误"
// @Router       /oem/order/create [post]
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

// AcceptOrder 零部件厂接受订单
// @Summary 零部件厂商接受订单
// @Description Manufacturer 接受 OEM 创建的订单，状态变为 ACCEPTED
// @Tags Manufacturer
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /manufacturer/order/{id}/accept [put]
func (h *SupplyChainHandler) AcceptOrder(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.AcceptOrder(id); err != nil {
		log.Printf("AcceptOrder Error: %v", err)
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已接受", nil)
}

// UpdateStatusRequest 更新状态请求
type UpdateStatusRequest struct {
	Status string `json:"status" example:"PRODUCING" binding:"required" enums:"PRODUCING,PRODUCED,READY"` // 生产状态：PRODUCING(生产中)/PRODUCED(已生产)/READY(待发货)
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
// @Router /manufacturer/order/{id}/status [put]
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

// PickupGoodsRequest 取货请求
type PickupGoodsRequest struct {
	OrderID    string `json:"orderId" example:"ORDER_2024_001" binding:"required"`       // 订单ID
	ShipmentID string `json:"shipmentId" example:"SHIPMENT_2024_001" binding:"required"` // 物流单ID
}

// PickupGoods 承运商取货
// @Summary 承运商取货
// @Description Carrier 取货并生成物流单，订单状态变为 READY
// @Tags Carrier
// @Accept json
// @Produce json
// @Param data body PickupGoodsRequest true "取货信息"
// @Success 200 {object} utils.Response
// @Router /carrier/shipment/pickup [post]
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

// UpdateLocationRequest 更新位置请求
type UpdateLocationRequest struct {
	Location string `json:"location" example:"SHANGHAI_PORT" binding:"required"` // 当前位置
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
// @Router /carrier/shipment/{id}/location [put]
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

// ConfirmReceipt 主机厂签收
// @Summary OEM 确认收货
// @Description OEM 确认收货，订单状态变为 RECEIVED
// @Tags OEM
// @Accept json
// @Produce json
// @Param id path string true "订单ID"
// @Success 200 {object} utils.Response
// @Router /oem/order/{id}/receive [put]
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
// @Router /carrier/shipment/{id} [get]
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
// @Router /oem/order/{id} [get]
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
// @Router /oem/order/list [get]
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
// @Router /oem/order/{id}/history [get]
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
// @Router /carrier/shipment/{id}/history [get]
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

// QueryAllLedgerData 查询所有账本数据及历史
// @Summary 查询所有账本数据及完整历史变更记录
// @Description 查询账本上所有资产（订单和物流单）的当前状态及其完整的历史变更记录，用于审计和追溯
// @Tags Platform
// @Accept json
// @Produce json
// @Param pageSize query int false "每页数量" default(10)
// @Param bookmark query string false "分页书签"
// @Success 200 {object} utils.Response
// @Router /platform/all [get]
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
