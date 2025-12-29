#!/bin/bash

# 设置错误即停止
set -e

echo "=== 1. 解压项目源码 ==="
if [ -f "project.tar.gz" ]; then
    tar -zxvf project.tar.gz
    echo "源码解压完成。"
else
    echo "错误: 未找到 project.tar.gz，请确保文件已上传到当前目录。"
    exit 1
fi

echo "=== 2. 加载 Docker 镜像 ==="
if [ -f "server_image.tar" ]; then
    docker load -i server_image.tar
fi
if [ -f "web_image.tar" ]; then
    docker load -i web_image.tar
fi
echo "镜像加载完成。"

echo "=== 3. 准备脚本权限与换行符转换 ==="
if ! command -v dos2unix &> /dev/null; then
    echo "正在安装 dos2unix..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y dos2unix
    elif command -v yum &> /dev/null; then
        sudo yum install -y dos2unix
    else
        echo "警告: 自动安装 dos2unix 失败，请手动安装。"
    fi
fi
find . -name "*.sh" -exec dos2unix {} + 2>/dev/null || true
chmod +x *.sh network/*.sh
echo "权限设置与换行符转换完成。"


# === [核心修改] 4. 以非交互方式，通过参数执行卸载和安装 ===
echo "=== 4. 清理旧环境并启动安装 ==="

# 调用 uninstall.sh 并传递 -y 参数，自动确认卸载
./uninstall.sh -y || true

# 调用 install.sh 并传递 --assume-no-accelerator 参数，自动选择不使用镜像加速
./install.sh --assume-no-accelerator

echo ""
echo "=== 部署成功！ ==="
PUBLIC_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "系统访问地址: http://${PUBLIC_IP}:8000"
echo "====================="