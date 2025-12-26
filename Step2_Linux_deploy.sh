#!/bin/bash
set -e

BASE_DIR="/home/deploy-fabric"

echo "=== 1. 解压部署包 ==="
tar -zxvf deploy_package.tar.gz -C $BASE_DIR

cd $BASE_DIR

echo "=== 2. 加载 Docker 镜像 ==="
docker load -i server_image.tar
docker load -i web_image.tar

echo "=== 3. 解压项目源码 ==="
tar -zxvf project.tar.gz -C $BASE_DIR

echo "=== 4. 执行安装 ==="
chmod +x *.sh network/*.sh 2>/dev/null || true

./uninstall.sh || true

./install.sh <<EOF
n
y
EOF

echo "=== 部署成功 ==="
