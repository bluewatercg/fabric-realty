#!/bin/bash
# Step2_Linux_deploy.sh - 在目标服务器上执行

# 如果任何命令失败，则立即退出
set -e

echo ">>> 1. 加载Docker镜像..."
docker load -i server_image.tar || { echo "加载 server_image.tar 失败"; exit 1; }
docker load -i web_image.tar || { echo "加载 web_image.tar 失败"; exit 1; }
echo "Docker镜像加载成功。"

echo ""
echo ">>> 2. 启动Fabric网络服务..."
# 所有网络文件都在解压后的 network/ 目录中
docker-compose -f network/docker-compose.yaml up -d || { echo "启动Fabric网络失败"; exit 1; }
echo "Fabric网络服务已启动。"

echo ""
echo ">>> 3. 启动业务应用服务..."
# 应用的compose文件在 application/ 目录中
docker-compose -f application/docker-compose.yml up -d || { echo "启动业务应用失败"; exit 1; }
echo "业务应用服务已启动。"

echo ""
echo ">>> 部署成功！所有服务正在后台运行。"