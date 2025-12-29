#!/bin/bash

echo "=========================================="
echo "测试 QueryAllLedgerData 功能"
echo "查询所有账本数据及完整历史变更"
echo "=========================================="

# 检查网络是否运行
echo -e "\n[1] 检查 Fabric 网络状态..."
docker ps --filter "name=peer" --format "table {{.Names}}\t{{.Status}}" | head -5

# 检查后端服务
echo -e "\n[2] 检查后端服务..."
docker ps --filter "name=server" --format "table {{.Names}}\t{{.Status}}"

# 测试 API 端点
echo -e "\n[3] 测试 QueryAllLedgerData API (历史数据查询)..."
echo "请求: GET http://localhost:8000/api/platform/all?pageSize=5"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8000/api/platform/all?pageSize=5")
http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d':' -f2)
body=$(echo "$response" | sed '/HTTP_CODE/d')

echo "HTTP 状态码: $http_code"

# 解析结果
if [ "$http_code" = "200" ]; then
    echo -e "\n✅ API 调用成功"
    
    records_count=$(echo "$body" | jq '.data.recordsCount' 2>/dev/null)
    bookmark=$(echo "$body" | jq -r '.data.bookmark' 2>/dev/null)
    
    echo "   - 返回资产数: $records_count"
    echo "   - 分页书签: $bookmark"
    
    # 展示第一个资产的详细信息
    echo -e "\n[4] 第一个资产的详细信息："
    first_record=$(echo "$body" | jq '.data.records[0]' 2>/dev/null)
    
    if [ "$first_record" != "null" ] && [ -n "$first_record" ]; then
        key=$(echo "$first_record" | jq -r '.key' 2>/dev/null)
        history_count=$(echo "$first_record" | jq '.history | length' 2>/dev/null)
        
        echo "   资产 Key: $key"
        echo "   历史记录数: $history_count 条"
        
        echo -e "\n   当前状态:"
        echo "$first_record" | jq '.current' 2>/dev/null | sed 's/^/      /'
        
        echo -e "\n   历史变更记录 (最近3条):"
        echo "$first_record" | jq '.history[0:3] | .[] | {txId: .txId, timestamp: .timestamp, isDelete: .isDelete}' 2>/dev/null | sed 's/^/      /'
    fi
    
    # 统计所有资产的历史记录总数
    echo -e "\n[5] 所有资产的历史统计："
    echo "$body" | jq -r '.data.records[] | "\(.key): \(.history | length) 条历史记录"' 2>/dev/null | sed 's/^/   /'
    
else
    echo -e "\n❌ API 调用失败 (HTTP $http_code)"
    echo "   错误信息: $(echo "$body" | jq -r '.message' 2>/dev/null)"
    echo -e "\n完整响应:"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
fi

echo -e "\n=========================================="
echo "测试完成"
echo "=========================================="
