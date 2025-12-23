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
func (h *SupplyChainHandler) ConfirmReceipt(c *gin.Context) {
	id := c.Param("id")
	if err := h.scService.ConfirmReceipt(id); err != nil {
		utils.ServerError(c, err.Error())
		return
	}
	utils.SuccessWithMessage(c, "订单已签收完成", nil)
}

// QueryShipment 查询物流详情
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
