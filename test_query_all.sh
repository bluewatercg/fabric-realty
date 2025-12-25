#!/bin/bash

echo "=========================================="
echo "测试 QueryAllLedgerData 功能"
echo "=========================================="

# 检查网络是否运行
echo -e "\n[1] 检查 Fabric 网络状态..."
docker ps --filter "name=peer" --format "table {{.Names}}\t{{.Status}}" | head -5

# 检查后端服务
echo -e "\n[2] 检查后端服务..."
docker ps --filter "name=server" --format "table {{.Names}}\t{{.Status}}"

# 测试 API 端点
echo -e "\n[3] 测试 QueryAllLedgerData API..."
echo "请求: GET http://localhost:8000/api/platform/all?pageSize=5"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8000/api/platform/all?pageSize=5")
http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d':' -f2)
body=$(echo "$response" | sed '/HTTP_CODE/d')

echo "HTTP 状态码: $http_code"
echo -e "\n响应数据:"
echo "$body" | jq '.' 2>/dev/null || echo "$body"

# 解析结果
if [ "$http_code" = "200" ]; then
    echo -e "\n✅ API 调用成功"
    
    records_count=$(echo "$body" | jq '.data.recordsCount' 2>/dev/null)
    bookmark=$(echo "$body" | jq -r '.data.bookmark' 2>/dev/null)
    
    echo "   - 返回记录数: $records_count"
    echo "   - 分页书签: $bookmark"
    
    echo -e "\n记录详情:"
    echo "$body" | jq '.data.records[0:2]' 2>/dev/null
else
    echo -e "\n❌ API 调用失败"
    echo "   错误信息: $(echo "$body" | jq -r '.message' 2>/dev/null)"
fi

echo -e "\n=========================================="
echo "测试完成"
echo "=========================================="
