package service

import (
	"application/pkg/fabric"
	"encoding/json"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"time"

	"github.com/hyperledger/fabric-gateway/pkg/client"
)

type SupplyChainService struct{}

const (
	OEM_ORG          = "org1"
	MANUFACTURER_ORG = "org2"
	CARRIER_ORG      = "org3"
	PLATFORM_ORG     = "org3"
	maxRetries       = 3
	retryDelay       = 100 * time.Millisecond
)

// isMVCCConflict 检查是否是 MVCC_READ_CONFLICT 错误
func isMVCCConflict(errMsg string) bool {
	return strings.Contains(errMsg, "MVCC_READ_CONFLICT") ||
		strings.Contains(errMsg, "mvcc_read_conflict") ||
		strings.Contains(errMsg, "status code 11")
}

// submitWithRetry 带重试的提交交易
func submitWithRetry(contract *client.Contract, function string, args ...string) ([]byte, error) {
	var lastErr error
	for i := 0; i < maxRetries; i++ {
		result, err := contract.SubmitTransaction(function, args...)
		if err == nil {
			return result, nil
		}
		lastErr = err
		errMsg := fabric.ExtractErrorMessage(err)
		if isMVCCConflict(errMsg) {
			time.Sleep(retryDelay * time.Duration(i+1))
			continue
		}
		return nil, lastErr
	}
	return nil, lastErr
}

// CreateOrder 主机厂创建订单
func (s *SupplyChainService) CreateOrder(id string, manufacturerId string, items interface{}) error {
	contract := fabric.GetContract(OEM_ORG)
	itemsBytes, _ := json.Marshal(items)
	_, err := submitWithRetry(contract, "CreateOrder", id, manufacturerId, string(itemsBytes))
	if err != nil {
		return fmt.Errorf("创建订单失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// AcceptOrder 零部件厂接受订单
func (s *SupplyChainService) AcceptOrder(id string) error {
	contract := fabric.GetContract(MANUFACTURER_ORG)
	_, err := submitWithRetry(contract, "AcceptOrder", id)
	if err != nil {
		return fmt.Errorf("接受订单失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// UpdateProductionStatus 更新生产进度
func (s *SupplyChainService) UpdateProductionStatus(id string, status string) error {
	contract := fabric.GetContract(MANUFACTURER_ORG)
	_, err := submitWithRetry(contract, "UpdateProductionStatus", id, status)
	if err != nil {
		return fmt.Errorf("更新生产进度失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// PickupGoods 承运商取货
func (s *SupplyChainService) PickupGoods(orderId string, shipmentId string) error {
	contract := fabric.GetContract(CARRIER_ORG)
	_, err := submitWithRetry(contract, "PickupGoods", orderId, shipmentId)
	if err != nil {
		return fmt.Errorf("取货失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// UpdateLocation 更新物流位置
func (s *SupplyChainService) UpdateLocation(shipmentId string, location string) error {
	contract := fabric.GetContract(CARRIER_ORG)
	_, err := submitWithRetry(contract, "UpdateLocation", shipmentId, location)
	if err != nil {
		return fmt.Errorf("更新物流位置失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// DeliverGoods 承运商送达货物
func (s *SupplyChainService) DeliverGoods(orderId string) error {
	contract := fabric.GetContract(CARRIER_ORG)
	_, err := submitWithRetry(contract, "DeliverGoods", orderId)
	if err != nil {
		return fmt.Errorf("确认送达失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// ConfirmReceipt 主机厂确认收货
func (s *SupplyChainService) ConfirmReceipt(orderId string) error {
	contract := fabric.GetContract(OEM_ORG)
	_, err := submitWithRetry(contract, "ConfirmReceipt", orderId)
	if err != nil {
		return fmt.Errorf("确认收货失败：%s", fabric.ExtractErrorMessage(err))
	}
	return nil
}

// QueryOrder 查询订单详情
func (s *SupplyChainService) QueryOrder(id string) (map[string]interface{}, error) {
	contract := fabric.GetContract(OEM_ORG)
	result, err := contract.EvaluateTransaction("QueryOrder", id)
	if err != nil {
		return nil, fmt.Errorf("查询订单失败：%s", fabric.ExtractErrorMessage(err))
	}

	var order map[string]interface{}
	if err := json.Unmarshal(result, &order); err != nil {
		return nil, fmt.Errorf("解析订单数据失败：%v", err)
	}

	return order, nil
}

// QueryOrderList 分页查询订单列表
func (s *SupplyChainService) QueryOrderList(pageSize int32, bookmark string) (map[string]interface{}, error) {
	contract := fabric.GetContract(OEM_ORG)
	result, err := contract.EvaluateTransaction("QueryOrderList", fmt.Sprintf("%d", pageSize), bookmark)
	if err != nil {
		return nil, fmt.Errorf("查询订单列表失败：%s", fabric.ExtractErrorMessage(err))
	}

	var queryResult map[string]interface{}
	if err := json.Unmarshal(result, &queryResult); err != nil {
		return nil, fmt.Errorf("解析查询结果失败：%v", err)
	}

	return queryResult, nil
}

// QueryShipment 查询物流详情
func (s *SupplyChainService) QueryShipment(id string) (map[string]interface{}, error) {
	contract := fabric.GetContract(CARRIER_ORG)
	result, err := contract.EvaluateTransaction("QueryShipment", id)
	if err != nil {
		return nil, fmt.Errorf("查询物流失败：%s", fabric.ExtractErrorMessage(err))
	}

	var shipment map[string]interface{}
	if err := json.Unmarshal(result, &shipment); err != nil {
		return nil, fmt.Errorf("解析物流数据失败：%v", err)
	}

	return shipment, nil
}

func (s *SupplyChainService) QueryAllLedgerData(pageSize int32, bookmark string) (map[string]interface{}, error) {
	contract := fabric.GetContract(PLATFORM_ORG)
	result, err := contract.EvaluateTransaction("QueryAllLedgerData", fmt.Sprintf("%d", pageSize), bookmark)
	if err != nil {
		return nil, fmt.Errorf("查询所有数据失败：%s", fabric.ExtractErrorMessage(err))
	}

	var queryResult map[string]interface{}
	if err := json.Unmarshal(result, &queryResult); err != nil {
		return nil, fmt.Errorf("解析查询结果失败：%v", err)
	}

	return queryResult, nil
}

// RawHistoryRecord 用于解析从链码返回的原始历史记录
type RawHistoryRecord struct {
	TxId      string                 `json:"txId"`
	Timestamp time.Time              `json:"timestamp"`
	IsDelete  bool                   `json:"isDelete"`
	Value     map[string]interface{} `json:"value"`
}

// DiffDetail 存储单个字段的新旧值
type DiffDetail struct {
	Old interface{} `json:"old"`
	New interface{} `json:"new"`
}

// EnhancedHistoryRecord 是最终返回给前端的、包含 diff 的丰富历史记录结构
type EnhancedHistoryRecord struct {
	TxId      string                 `json:"txId"`
	Timestamp time.Time              `json:"timestamp"`
	IsDelete  bool                   `json:"isDelete"`
	Value     map[string]interface{} `json:"value"`
	Diff      map[string]DiffDetail  `json:"diff"`
}

// generateDiff 比较两个 map 并生成字段级的差异
func generateDiff(oldState, newState map[string]interface{}) map[string]DiffDetail {
	diff := make(map[string]DiffDetail)

	// 将所有 key 收集到一个 set 中，方便遍历
	allKeys := make(map[string]bool)
	if oldState != nil {
		for key := range oldState {
			allKeys[key] = true
		}
	}
	if newState != nil {
		for key := range newState {
			allKeys[key] = true
		}
	}

	for key := range allKeys {
		oldVal, oldExists := oldState[key]
		newVal, newExists := newState[key]

		// 忽略 objectType，因为它始终不变
		if key == "objectType" {
			continue
		}

		if !oldExists && newExists { // 新增字段
			diff[key] = DiffDetail{Old: nil, New: newVal}
		} else if oldExists && !newExists { // 删除字段
			diff[key] = DiffDetail{Old: oldVal, New: nil}
		} else if oldExists && newExists && !reflect.DeepEqual(oldVal, newVal) { // 修改字段
			diff[key] = DiffDetail{Old: oldVal, New: newVal}
		}
	}

	return diff
}

// QueryOrderHistory 查询订单历史并计算版本差异
func (s *SupplyChainService) QueryOrderHistory(id string) ([]EnhancedHistoryRecord, error) {
	contract := fabric.GetContract(OEM_ORG)
	result, err := contract.EvaluateTransaction("QueryOrderHistory", id)
	if err != nil {
		return nil, fmt.Errorf("查询订单历史失败：%s", fabric.ExtractErrorMessage(err))
	}

	var rawHistory []RawHistoryRecord
	if err := json.Unmarshal(result, &rawHistory); err != nil {
		return nil, fmt.Errorf("解析订单历史数据失败：%v", err)
	}

	if len(rawHistory) == 0 {
		return []EnhancedHistoryRecord{}, nil
	}

	// 前端时间轴默认按「最新在前」展示；Diff 表示「与上一版本(更旧)对比」。
	// 不同 Fabric 版本/实现对 GetHistoryForKey 的返回顺序可能存在差异，这里统一按 timestamp 降序排序，
	// 并以“下一条记录(更旧)”作为 oldState，避免出现与更“新”版本对比导致的错乱。
	sort.SliceStable(rawHistory, func(i, j int) bool {
		return rawHistory[i].Timestamp.After(rawHistory[j].Timestamp)
	})

	enhancedHistory := make([]EnhancedHistoryRecord, 0, len(rawHistory))
	for i := 0; i < len(rawHistory); i++ {
		var oldState map[string]interface{}
		if i+1 < len(rawHistory) {
			oldState = rawHistory[i+1].Value
		} else {
			oldState = make(map[string]interface{})
		}

		newState := rawHistory[i].Value
		diff := generateDiff(oldState, newState)

		enhancedHistory = append(enhancedHistory, EnhancedHistoryRecord{
			TxId:      rawHistory[i].TxId,
			Timestamp: rawHistory[i].Timestamp,
			IsDelete:  rawHistory[i].IsDelete,
			Value:     newState,
			Diff:      diff,
		})
	}

	return enhancedHistory, nil
}

// QueryShipmentHistory 查询物流单历史并计算版本差异
func (s *SupplyChainService) QueryShipmentHistory(id string) ([]EnhancedHistoryRecord, error) {
	contract := fabric.GetContract(CARRIER_ORG)
	result, err := contract.EvaluateTransaction("QueryShipmentHistory", id)
	if err != nil {
		return nil, fmt.Errorf("查询物流历史失败：%s", fabric.ExtractErrorMessage(err))
	}

	var rawHistory []RawHistoryRecord
	if err := json.Unmarshal(result, &rawHistory); err != nil {
		return nil, fmt.Errorf("解析物流历史数据失败：%v", err)
	}

	if len(rawHistory) == 0 {
		return []EnhancedHistoryRecord{}, nil
	}

	// 与订单历史保持一致：统一按 timestamp 降序（最新在前），并将“下一条(更旧)”作为 oldState。
	sort.SliceStable(rawHistory, func(i, j int) bool {
		return rawHistory[i].Timestamp.After(rawHistory[j].Timestamp)
	})

	enhancedHistory := make([]EnhancedHistoryRecord, 0, len(rawHistory))
	for i := 0; i < len(rawHistory); i++ {
		var oldState map[string]interface{}
		if i+1 < len(rawHistory) {
			oldState = rawHistory[i+1].Value
		} else {
			oldState = make(map[string]interface{})
		}

		newState := rawHistory[i].Value
		diff := generateDiff(oldState, newState)

		enhancedHistory = append(enhancedHistory, EnhancedHistoryRecord{
			TxId:      rawHistory[i].TxId,
			Timestamp: rawHistory[i].Timestamp,
			IsDelete:  rawHistory[i].IsDelete,
			Value:     newState,
			Diff:      diff,
		})
	}

	return enhancedHistory, nil
}
