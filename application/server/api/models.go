package api

// CreateOrderRequest 创建订单请求
type CreateOrderRequest struct {
	ID             string      `json:"id" binding:"required" example:"ORDER001" minLength:"1"`
	ManufacturerID string      `json:"manufacturerId" binding:"required" example:"MFG001"`
	Items          []OrderItem `json:"items" binding:"required"`
}

// OrderItem 订单项
type OrderItem struct {
	PartNumber    string  `json:"partNumber" example:"PART-12345"`
	PartName      string  `json:"partName" example:"发动机缸体"`
	Quantity      int     `json:"quantity" example:"100" minimum:"1"`
	UnitPrice     float64 `json:"unitPrice" example:"125.50" minimum:"0"`
	Specification string  `json:"specification,omitempty" example:"标准规格"`
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
	ID        string             `json:"id" example:"SHIP001"`
	OrderID   string             `json:"orderId" example:"ORDER001"`
	CarrierID string             `json:"carrierId" example:"CARRIER001"`
	Status    string             `json:"status" example:"InTransit"`
	Locations []ShipmentLocation `json:"locations"`
	PickupAt  string             `json:"pickupAt" example:"2024-01-03T08:00:00Z"`
	UpdatedAt string             `json:"updatedAt" example:"2024-01-03T12:00:00Z"`
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
