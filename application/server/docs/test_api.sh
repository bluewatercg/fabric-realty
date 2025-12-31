#!/bin/bash

# API 测试脚本 - 正确的 URL 格式示例
# 基础 URL: http://192.168.1.41:8080
# API 前缀: /api (已包含在路径中)

BASE_URL="http://192.168.1.41:8080"
ORDER_ID="ORDER_$(date +%Y%m%d_%H%M%S)"

echo "========================================="
echo "  供应链系统 API 测试"
echo "========================================="
echo ""
echo "基础 URL: $BASE_URL"
echo "订单 ID: $ORDER_ID"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_api() {
    local name=$1
    local method=$2
    local path=$3
    local data=$4
    
    echo -e "${YELLOW}测试: $name${NC}"
    echo "请求: $method $BASE_URL$path"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$path" -H "accept: application/json")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$path" \
            -H "Content-Type: application/json" \
            -H "accept: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ 成功 (HTTP $http_code)${NC}"
        echo "响应: $body" | head -c 200
        echo "..."
    else
        echo -e "${RED}✗ 失败 (HTTP $http_code)${NC}"
        echo "响应: $body"
    fi
    echo ""
}

echo "========================================="
echo "  1. OEM (主机厂) 测试"
echo "========================================="
echo ""

# 创建订单
test_api "创建订单" "POST" "/api/oem/order/create" \
'{
  "id": "'"$ORDER_ID"'",
  "manufacturerId": "MANUFACTURER_A",
  "items": [
    {
      "name": "engine_part_xyz",
      "quantity": 100
    }
  ]
}'

sleep 1

# 查询订单列表
test_api "查询订单列表" "GET" "/api/oem/order/list?pageSize=10"

sleep 1

# 查询订单详情
test_api "查询订单详情" "GET" "/api/oem/order/$ORDER_ID"

sleep 1

echo "========================================="
echo "  2. Manufacturer (厂商) 测试"
echo "========================================="
echo ""

# 接受订单
test_api "接受订单" "PUT" "/api/manufacturer/order/$ORDER_ID/accept"

sleep 1

# 更新状态为生产中
test_api "更新状态-生产中" "PUT" "/api/manufacturer/order/$ORDER_ID/status" \
'{
  "status": "PRODUCING"
}'

sleep 1

# 更新状态为已生产
test_api "更新状态-已生产" "PUT" "/api/manufacturer/order/$ORDER_ID/status" \
'{
  "status": "PRODUCED"
}'

sleep 1

# 更新状态为待发货
test_api "更新状态-待发货" "PUT" "/api/manufacturer/order/$ORDER_ID/status" \
'{
  "status": "READY"
}'

sleep 1

echo "========================================="
echo "  3. Carrier (承运商) 测试"
echo "========================================="
echo ""

SHIPMENT_ID="SHIPMENT_$(date +%Y%m%d_%H%M%S)"

# 取货
test_api "取货并生成物流单" "POST" "/api/carrier/shipment/pickup" \
'{
  "orderId": "'"$ORDER_ID"'",
  "shipmentId": "'"$SHIPMENT_ID"'"
}'

sleep 1

# 更新位置
test_api "更新物流位置" "PUT" "/api/carrier/shipment/$SHIPMENT_ID/location" \
'{
  "location": "SHANGHAI_PORT"
}'

sleep 1

# 查询物流详情
test_api "查询物流详情" "GET" "/api/carrier/shipment/$SHIPMENT_ID"

sleep 1

echo "========================================="
echo "  4. Platform (平台) 测试"
echo "========================================="
echo ""

# 查询所有数据
test_api "查询所有账本数据" "GET" "/api/platform/all?pageSize=10"

sleep 1

echo "========================================="
echo "  5. OEM 完成流程"
echo "========================================="
echo ""

# 确认收货
test_api "确认收货" "PUT" "/api/oem/order/$ORDER_ID/receive"

sleep 1

# 查询订单历史
test_api "查询订单历史" "GET" "/api/oem/order/$ORDER_ID/history"

echo ""
echo "========================================="
echo "  测试完成！"
echo "========================================="
echo ""
echo "订单 ID: $ORDER_ID"
echo "物流单 ID: $SHIPMENT_ID"
echo ""
