#!/bin/bash
set -e

REMOTE_IP="192.168.1.41"
REMOTE_USER="root"
REMOTE_PATH="/home/deploy-fabric"
SERVER_IMAGE="togettoyou/fabric-realty.server:latest"
WEB_IMAGE="togettoyou/fabric-realty.web:latest"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}>>> 开始部署${NC}"

echo "预编译检查..."
(cd application/server && go build ./...)
(cd application/web && npm run build)
echo -e "${GREEN}✓ 预检查通过${NC}"

echo -e "${CYAN}\n>>> 构建镜像${NC}"
(cd application/server && docker build -t $SERVER_IMAGE .)
(cd application/web && docker build -t $WEB_IMAGE .)
echo -e "${GREEN}✓ 镜像构建完成${NC}"

echo -e "${CYAN}\n>>> 上传镜像${NC}"
docker save $SERVER_IMAGE | ssh -o "StrictHostKeyChecking=no" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
docker save $WEB_IMAGE | ssh -o "StrictHostKeyChecking=no" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
echo -e "${GREEN}✓ 镜像上传完成${NC}"

echo -e "${CYAN}\n>>> 第四步：彻底清理旧容器并重启服务${NC}"
ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${REMOTE_USER}@${REMOTE_IP}" << 'EOF'
set -e
cd /home/deploy-fabric/application

echo "正在强制删除顽固旧容器..."
docker rm -f fabric-realty.server fabric-realty.web 2>/dev/null || true
docker rm -f /fabric-realty.server /fabric-realty.web 2>/dev/null || true

echo "清理项目环境..."
docker-compose -p fabric-realty down --remove-orphans --volumes -t 10

echo "启动新容器..."
docker-compose -p fabric-realty up -d

echo "服务状态："
docker-compose -p fabric-realty ps
EOF

echo -e "${GREEN}✓ 服务重启完成${NC}"

echo -e "\n✅ ${GREEN}🎉 恭喜！部署完全成功！${NC}"
echo "   前端访问: http://${REMOTE_IP}:8000"
echo "   API访问:   http://${REMOTE_IP}:8080"
echo "====================="