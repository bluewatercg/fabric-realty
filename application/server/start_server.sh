#!/bin/bash

# 供应链系统服务器启动脚本

echo "========================================="
echo "  供应链协同系统服务器启动"
echo "========================================="
echo ""

# 检查配置文件
if [ ! -f "config/config.yaml" ]; then
    echo "❌ 错误: 配置文件 config/config.yaml 不存在"
    exit 1
fi

# 检查可执行文件
if [ ! -f "app_server" ]; then
    echo "⚠️  警告: app_server 不存在，开始编译..."
    go build -o app_server main.go
    if [ $? -ne 0 ]; then
        echo "❌ 编译失败"
        exit 1
    fi
    echo "✅ 编译成功"
fi

# 启动服务器
echo ""
echo "🚀 启动服务器..."
echo "📍 Swagger UI: http://192.168.1.41:8080/swagger/index.html"
echo "📍 本地访问: http://localhost:8080/swagger/index.html"
echo ""
echo "按 Ctrl+C 停止服务器"
echo "========================================="
echo ""

./app_server
