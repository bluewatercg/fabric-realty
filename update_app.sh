#!/bin/bash

# 设置错误即停止
set -e

# --- 配置区 ---
# 请根据您的服务器信息修改
REMOTE_IP="192.168.1.41"
REMOTE_USER="root"
REMOTE_PATH="/home/deploy-fabric" # 项目在服务器上的部署路径
SERVER_IMAGE="togettoyou/fabric-realty.server:latest"
WEB_IMAGE="togettoyou/fabric-realty.web:latest"
# -------------

# 颜色定义 (可选，用于美化输出)
GREEN='\033[0;32m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${MAGENTA}>>> 第一步：开始本地预编译检查...${NC}"
echo "正在检查后端服务..."
(cd application/server && go build ./...)
echo "正在检查并构建前端..."
(cd application/web && npm run build)
echo -e "${GREEN}预编译检查通过！${NC}"

echo -e "${CYAN}\n>>> 第二步：开始本地构建镜像...${NC}"
(cd application/server && docker build -t $SERVER_IMAGE .)
(cd application/web && docker build -t $WEB_IMAGE .)
echo "镜像构建完成。"

echo -e "${CYAN}\n>>> 第三步：流式上传并加载镜像到服务器...${NC}"
echo "正在上传后端镜像 ($SERVER_IMAGE)..."
docker save $SERVER_IMAGE | ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
echo "正在上传前端镜像 ($WEB_IMAGE)..."
docker save $WEB_IMAGE | ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
echo "镜像上传并加载完成。"

echo -e "${CYAN}\n>>> 第四步：在服务器上重启应用服务...${NC}"
remoteCommand="cd ${REMOTE_PATH}/application && docker-compose stop fabric-realty.server fabric-realty.web && docker-compose rm -f fabric-realty.server fabric-realty.web && docker-compose up -d fabric-realty.server fabric-realty.web"
ssh -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\" \"${REMOTE_USER}@${REMOTE_IP}\" \"$remoteCommand\"
echo "服务重启完成。"

echo -e "\n✅ ${GREEN}应用更新成功！${NC}"
PUBLIC_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}' | head -n 1) # Added head -n 1 for consistency
echo "系统访问地址: http://${REMOTE_IP}:8000"
echo "====================="
