package main

import (
    "encoding/json"
    "fmt"
    "log"
    "time"

    "github.com/hyperledger/fabric-chaincode-go/v2/pkg/cid"
    "github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

// SmartContract 为汽配供应链提供智能合约功能
type SmartContract struct {
    contractapi.Contract
}

// 资产类型常量
const (
    ORDER    = "ORDER"    // 采购订单
    SHIPMENT = "SHIPMENT" // 物流信息
)

// OrderStatus 订单状态
type OrderStatus string

const (
    ORDER_CREATED   OrderStatus = "CREATED"   // 主机厂已发布
    ORDER_ACCEPTED  OrderStatus = "ACCEPTED"  // 零部件厂已接受
    ORDER_PRODUCING OrderStatus = "PRODUCING" // 生产中
    ORDER_PRODUCED  OrderStatus = "PRODUCED"  // 生产完成
    ORDER_READY     OrderStatus = "READY"     // 待取货
    ORDER_SHIPPED   OrderStatus = "SHIPPED"   // 运输中
    ORDER_DELIVERED OrderStatus = "DELIVERED" // 已送达
    ORDER_RECEIVED  OrderStatus = "RECEIVED"  // 已签收确认
)

// Order 订单信息
type Order struct {
    ID             string      `json:"id"`             // 订单ID
    ObjectType     string      `json:"objectType"`     // 资产类型 (ORDER)
    OEMID          string      `json:"oemId"`          // 主机厂组织 ID
    ManufacturerID string      `json:"manufacturerId"` // 零部件厂商 ID
    Items          []OrderItem `json:"items"`          // 零件清单
    Status         OrderStatus `json:"status"`         // 当前状态
    TotalPrice     float64     `json:"totalPrice"`     // 总价
    ShipmentID     string      `json:"shipmentId"`     // 关联物流单ID
    CreateTime     time.Time   `json:"createTime"`     // 创建时间
    UpdateTime     time.Time   `json:"updateTime"`     // 更新时间
}

// OrderItem 零件明细
type OrderItem struct {
    Name     string  `json:"name"`     // 零件名称
    Quantity int     `json:"quantity"` // 数量
    Price    float64 `json:"price"`    // 单价
}

// Shipment 物流信息
type Shipment struct {
    ID         string    `json:"id"`         // 物流单ID
    ObjectType string    `json:"objectType"` // 资产类型 (SHIPMENT)
    OrderID    string    `json:"orderId"`    // 关联订单ID
    CarrierID  string    `json:"carrierId"`  // 承运商 ID
    Location   string    `json:"location"`   // 当前位置
    Status     string    `json:"status"`     // 运输状态
    UpdateTime time.Time `json:"updateTime"` // 更新时间
}

// QueryResponse 分页查询封装
type QueryResponse struct {
    Records             []interface{} `json:"records"`
    RecordsCount        int32         `json:"recordsCount"`
    Bookmark            string        `json:"bookmark"`
    FetchedRecordsCount int32         `json:"fetchedRecordsCount"`
}

// 组织 MSP ID 常量 (3个物理组织)
const (
    OEM_ORG_MSPID          = "Org1MSP" // 主机厂
    MANUFACTURER_ORG_MSPID = "Org2MSP" // 零部件厂商
    PLATFORM_ORG_MSPID     = "Org3MSP" // 平台方 & 承运商 (共用 Org3)
)

// 获取客户端身份 MSP ID
func (s *SmartContract) getClientIdentityMSPID(ctx contractapi.TransactionContextInterface) (string, error) {
    clientID, err := cid.New(ctx.GetStub())
    if err != nil {
        return "", fmt.Errorf("获取客户端身份失败: %v", err)
    }
    return clientID.GetMSPID()
}

// 获取事务时间 (确定性时间)
func (s *SmartContract) getTxTimestamp(ctx contractapi.TransactionContextInterface) (time.Time, error) {
    txTimestamp, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return time.Time{}, fmt.Errorf("获取事务时间失败: %v", err)
    }
    return time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos)), nil
}

// InitLedger 链码初始化 (兼容脚本)
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
    return nil
}

// Hello 链码测试 (兼容脚本)
func (s *SmartContract) Hello(ctx contractapi.TransactionContextInterface) (string, error) {
    return "hello supply chain", nil
}

// CreateOrder 主机厂创建订单 (仅 Org1 可调用)
func (s *SmartContract) CreateOrder(ctx contractapi.TransactionContextInterface, id string, manufacturerId string, itemsJson string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != OEM_ORG_MSPID {
        return fmt.Errorf("无权限: 仅限主机厂创建订单")
    }

    var items []OrderItem
    if err := json.Unmarshal([]byte(itemsJson), &items); err != nil {
        return fmt.Errorf("解析零件清单失败: %v", err)
    }

    var totalPrice float64
    for _, item := range items {
        totalPrice += float64(item.Quantity) * item.Price
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }

    order := Order{
        ID:             id,
        ObjectType:     ORDER,
        OEMID:          clientMSPID,
        ManufacturerID: manufacturerId,
        Items:          items,
        Status:         ORDER_CREATED,
        TotalPrice:     totalPrice,
        CreateTime:     now,
        UpdateTime:     now,
    }

    orderBytes, err := json.Marshal(order)
    if err != nil {
        return fmt.Errorf("序列化订单失败: %v", err)
    }
    return ctx.GetStub().PutState(id, orderBytes)
}

// AcceptOrder 零部件厂接受订单 (仅 Org2 可调用)
func (s *SmartContract) AcceptOrder(ctx contractapi.TransactionContextInterface, id string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != MANUFACTURER_ORG_MSPID {
        return fmt.Errorf("无权限: 仅限零部件厂商接受订单")
    }

    orderBytes, err := ctx.GetStub().GetState(id)
    if err != nil || orderBytes == nil {
        return fmt.Errorf("订单 %s 不存在", id)
    }

    var order Order
    json.Unmarshal(orderBytes, &order)

    if order.Status != ORDER_CREATED {
        return fmt.Errorf("当前状态 %s 无法接受订单", order.Status)
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }
    order.Status = ORDER_ACCEPTED
    order.UpdateTime = now

    newOrderBytes, _ := json.Marshal(order)
    return ctx.GetStub().PutState(id, newOrderBytes)
}

// UpdateProductionStatus 更新生产状态 (仅 Org2 可调用)
func (s *SmartContract) UpdateProductionStatus(ctx contractapi.TransactionContextInterface, id string, status string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != MANUFACTURER_ORG_MSPID {
        return fmt.Errorf("无权限")
    }

    if id == "" {
        return fmt.Errorf("订单 ID 不能为空")
    }

    orderBytes, err := ctx.GetStub().GetState(id)
    if err != nil {
        return fmt.Errorf("读取订单失败: %v", err)
    }
    if orderBytes == nil {
        return fmt.Errorf("订单 %s 不存在", id)
    }

    var order Order
    if err := json.Unmarshal(orderBytes, &order); err != nil {
        return fmt.Errorf("解析订单失败: %v", err)
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }
    order.Status = OrderStatus(status)
    order.UpdateTime = now

    newOrderBytes, err := json.Marshal(order)
    if err != nil {
        return fmt.Errorf("序列化订单失败: %v", err)
    }
    return ctx.GetStub().PutState(id, newOrderBytes)
}

// PickupGoods 承运商取货 (仅 Org3 可调用)
func (s *SmartContract) PickupGoods(ctx contractapi.TransactionContextInterface, orderId string, shipmentId string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != PLATFORM_ORG_MSPID {
        return fmt.Errorf("无权限: 仅限承运商取货")
    }

    orderBytes, _ := ctx.GetStub().GetState(orderId)
    var order Order
    json.Unmarshal(orderBytes, &order)

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }

    order.Status = ORDER_SHIPPED
    order.ShipmentID = shipmentId
    order.UpdateTime = now

    shipment := Shipment{
        ID:         shipmentId,
        ObjectType: SHIPMENT,
        OrderID:    orderId,
        CarrierID:  clientMSPID,
        Location:   "零部件仓库",
        Status:     "运输中",
        UpdateTime: now,
    }
    
    orderBytes, err = json.Marshal(order)
    if err != nil {
        return fmt.Errorf("序列化订单失败: %v", err)
    }
    if err := ctx.GetStub().PutState(orderId, orderBytes); err != nil {
        return err
    }

    shipmentBytes, err := json.Marshal(shipment)
    if err != nil {
        return fmt.Errorf("序列化物流单失败: %v", err)
    }
    return ctx.GetStub().PutState(shipmentId, shipmentBytes)
}

// UpdateLocation 更新物流位置 (仅 Org3 可调用)
func (s *SmartContract) UpdateLocation(ctx contractapi.TransactionContextInterface, shipmentId string, location string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != PLATFORM_ORG_MSPID {
        return fmt.Errorf("无权限")
    }

    shipmentBytes, _ := ctx.GetStub().GetState(shipmentId)
    var shipment Shipment
    json.Unmarshal(shipmentBytes, &shipment)

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }
    shipment.Location = location
    shipment.UpdateTime = now

    newShipmentBytes, err := json.Marshal(shipment)
    if err != nil {
        return fmt.Errorf("序列化物流单失败: %v", err)
    }
    return ctx.GetStub().PutState(shipmentId, newShipmentBytes)
}

// DeliverGoods 承运商送达货物 (仅 Org3 可调用)
func (s *SmartContract) DeliverGoods(ctx contractapi.TransactionContextInterface, orderId string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != PLATFORM_ORG_MSPID {
        return fmt.Errorf("无权限: 仅限承运商操作")
    }

    orderBytes, err := ctx.GetStub().GetState(orderId)
    if err != nil || orderBytes == nil {
        return fmt.Errorf("订单 %s 不存在", orderId)
    }

    var order Order
    if err := json.Unmarshal(orderBytes, &order); err != nil {
        return fmt.Errorf("解析订单失败: %v", err)
    }

    // 状态校验：只有 SHIPPED 状态才能送达
    if order.Status != ORDER_SHIPPED {
        return fmt.Errorf("当前状态 %s 无法执行送达操作，只有运输中状态才能送达", order.Status)
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }
    order.Status = ORDER_DELIVERED
    order.UpdateTime = now

    newOrderBytes, err := json.Marshal(order)
    if err != nil {
        return fmt.Errorf("序列化订单失败: %v", err)
    }
    return ctx.GetStub().PutState(orderId, newOrderBytes)
}

// ConfirmReceipt 主机厂签收 (仅 Org1 可调用)
func (s *SmartContract) ConfirmReceipt(ctx contractapi.TransactionContextInterface, orderId string) error {
    clientMSPID, err := s.getClientIdentityMSPID(ctx)
    if err != nil {
        return err
    }
    if clientMSPID != OEM_ORG_MSPID {
        return fmt.Errorf("无权限")
    }

    orderBytes, _ := ctx.GetStub().GetState(orderId)
    var order Order
    json.Unmarshal(orderBytes, &order)

    // 状态校验：只有 DELIVERED 状态才能签收
    if order.Status != ORDER_DELIVERED {
        return fmt.Errorf("当前状态 %s 无法签收，只有已送达状态才能签收", order.Status)
    }

    now, err := s.getTxTimestamp(ctx)
    if err != nil {
        return err
    }
    order.Status = ORDER_RECEIVED
    order.UpdateTime = now

    newOrderBytes, err := json.Marshal(order)
    if err != nil {
        return fmt.Errorf("序列化订单失败: %v", err)
    }
    return ctx.GetStub().PutState(orderId, newOrderBytes)
}

// QueryOrder 查询订单详情
func (s *SmartContract) QueryOrder(ctx contractapi.TransactionContextInterface, id string) (*Order, error) {
    orderBytes, err := ctx.GetStub().GetState(id)
    if err != nil || orderBytes == nil {
        return nil, fmt.Errorf("订单 %s 不存在", id)
    }

    var order Order
    json.Unmarshal(orderBytes, &order)
    return &order, nil
}

// QueryShipment 查询物流详情
func (s *SmartContract) QueryShipment(ctx contractapi.TransactionContextInterface, id string) (*Shipment, error) {
    shipmentBytes, err := ctx.GetStub().GetState(id)
    if err != nil || shipmentBytes == nil {
        return nil, fmt.Errorf("物流单 %s 不存在", id)
    }

    var shipment Shipment
    json.Unmarshal(shipmentBytes, &shipment)
    return &shipment, nil
}

// LedgerDataWithHistory 账本数据及其历史记录
type LedgerDataWithHistory struct {
    Key     string                   `json:"key"`
    Current interface{}              `json:"current"`
    History []map[string]interface{} `json:"history"`
}

// QueryAllLedgerData 查询所有数据及其完整历史变更记录
func (s *SmartContract) QueryAllLedgerData(ctx contractapi.TransactionContextInterface, pageSize int32, bookmark string) (*QueryResponse, error) {
    // 第一步：获取所有 key 的当前状态
    resultsIterator, responseMetadata, err := ctx.GetStub().GetStateByRangeWithPagination("", "", pageSize, bookmark)
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()

    records := make([]interface{}, 0)
    
    // 第二步：对每个 key 查询其完整历史
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }

        key := queryResponse.Key
        
        // 解析当前值
        var currentData map[string]interface{}
        if err := json.Unmarshal(queryResponse.Value, &currentData); err != nil {
            log.Printf("解析数据失败 key=%s: %v", key, err)
            continue
        }

        // 查询该 key 的历史记录
        historyIterator, err := ctx.GetStub().GetHistoryForKey(key)
        if err != nil {
            log.Printf("查询历史失败 key=%s: %v", key, err)
            continue
        }

        history := make([]map[string]interface{}, 0)
        for historyIterator.HasNext() {
            historyData, err := historyIterator.Next()
            if err != nil {
                break
            }

            var value map[string]interface{}
            if historyData.Value != nil {
                json.Unmarshal(historyData.Value, &value)
            }

            history = append(history, map[string]interface{}{
                "txId":      historyData.TxId,
                "timestamp": historyData.Timestamp.AsTime(),
                "isDelete":  historyData.IsDelete,
                "value":     value,
            })
        }
        historyIterator.Close()

        // 组装结果
        records = append(records, LedgerDataWithHistory{
            Key:     key,
            Current: currentData,
            History: history,
        })
    }

    return &QueryResponse{
        Records:             records,
        RecordsCount:        int32(len(records)),
        Bookmark:            responseMetadata.Bookmark,
        FetchedRecordsCount: responseMetadata.FetchedRecordsCount,
    }, nil
}

// QueryOrderList 分页查询订单 (示例)
func (s *SmartContract) QueryOrderList(ctx contractapi.TransactionContextInterface, pageSize int32, bookmark string) (*QueryResponse, error) {
    // 简单的全量查询，实际应使用 CouchDB Selector
    resultsIterator, responseMetadata, err := ctx.GetStub().GetStateByRangeWithPagination("", "", pageSize, bookmark)
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()

    records := make([]interface{}, 0)
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var order Order
        if err := json.Unmarshal(queryResponse.Value, &order); err == nil && order.ObjectType == ORDER {
            records = append(records, order)
        }
    }

    return &QueryResponse{
        Records:             records,
        RecordsCount:        int32(len(records)),
        Bookmark:            responseMetadata.Bookmark,
        FetchedRecordsCount: responseMetadata.FetchedRecordsCount,
    }, nil
}

// OrderHistoryRecord 订单历史记录
type OrderHistoryRecord struct {
    TxId        string    `json:"txId"`        // 交易ID
    Timestamp   time.Time `json:"timestamp"`   // 交易时间戳
    Status      string    `json:"status"`      // 状态
    IsDelete    bool      `json:"isDelete"`    // 是否是删除操作
    Value       *Order    `json:"value"`       // 状态变更后的值
}

// QueryOrderHistory 查询订单历史记录
// 使用 Fabric 内置的 GetHistoryForKey API，无需额外存储即可追踪完整历史
func (s *SmartContract) QueryOrderHistory(ctx contractapi.TransactionContextInterface, id string) ([]OrderHistoryRecord, error) {
    resultsIterator, err := ctx.GetStub().GetHistoryForKey(id)
    if err != nil {
        return nil, fmt.Errorf("查询订单历史失败: %v", err)
    }
    defer resultsIterator.Close()

    history := make([]OrderHistoryRecord, 0)
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }

        var order Order
        if queryResponse.Value != nil {
            if err := json.Unmarshal(queryResponse.Value, &order); err == nil {
                // 正常解析
            }
        }

        txTimestamp := queryResponse.Timestamp.AsTime()

        history = append(history, OrderHistoryRecord{
            TxId:      queryResponse.TxId,
            Timestamp: txTimestamp,
            Status:    string(order.Status),
            IsDelete:  queryResponse.IsDelete,
            Value:     &order,
        })
    }

    return history, nil
}

// ShipmentHistoryRecord 物流单历史记录（与订单历史格式统一）
type ShipmentHistoryRecord struct {
    TxId        string     `json:"txId"`      // 交易ID
    Timestamp   time.Time  `json:"timestamp"` // 交易时间戳
    IsDelete    bool       `json:"isDelete"`  // 是否是删除操作
    Value       *Shipment  `json:"value"`     // 状态变更后的值
}

// QueryShipmentHistory 查询物流单历史记录
func (s *SmartContract) QueryShipmentHistory(ctx contractapi.TransactionContextInterface, id string) ([]ShipmentHistoryRecord, error) {
    resultsIterator, err := ctx.GetStub().GetHistoryForKey(id)
    if err != nil {
        return nil, fmt.Errorf("查询物流历史失败: %v", err)
    }
    defer resultsIterator.Close()

    history := make([]ShipmentHistoryRecord, 0)
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }

        var shipment Shipment
        if queryResponse.Value != nil {
            if err := json.Unmarshal(queryResponse.Value, &shipment); err == nil {
                // 正常解析
            }
        }

        txTimestamp := queryResponse.Timestamp.AsTime()

        history = append(history, ShipmentHistoryRecord{
            TxId:      queryResponse.TxId,
            Timestamp: txTimestamp,
            IsDelete:  queryResponse.IsDelete,
            Value:     &shipment,
        })
    }

    return history, nil
}

func main() {
    chaincode, err := contractapi.NewChaincode(&SmartContract{})
    if err != nil {
        log.Panicf("创建智能合约失败: %v", err)
    }

    if err := chaincode.Start(); err != nil {
        log.Panicf("启动智能合约失败: %v", err)
    }
}
