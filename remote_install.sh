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
# 安装 dos2unix (如果不存在)
if ! command -v dos2unix &> /dev/null; then
    echo "正在安装 dos2unix..."
    sudo apt-get update && sudo apt-get install -y dos2unix || echo "警告: 自动安装 dos2unix 失败，请确保手动安装。"
fi

# 转换所有脚本的换行符 (CRLF -> LF)
find . -name "*.sh" -exec dos2unix {} +
chmod +x *.sh network/*.sh
echo "权限设置与换行符转换完成。"

echo "=== 4. 清理旧环境并启动安装 ==="
# 如果之前部署过，先卸载
./uninstall.sh || true

# 执行正式安装
# 使用 heredoc 自动回答交互式询问：
# 1. 第一个询问：是否使用镜像加速？输入 n (因为我们已经本地加载了镜像)
# 2. 第二个询问：是否继续执行 network 部署？输入 y (确认数据丢失风险)
./install.sh <<EOF
n
y
EOF

echo ""
echo "=== 部署成功！ ==="
echo "系统访问地址: http://$(curl -s ifconfig.me || echo "localhost"):8000"
echo "====================="
