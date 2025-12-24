#!/bin/bash

# 设置错误即停止
set -e

echo "=== 1. 准备项目源码 ==="
# 优先检查是否已是 Git 仓库
if [ -d ".git" ]; then
    echo "检测到 Git 仓库，正在拉取最新代码..."
    git pull
    echo "代码拉取完成。"
# 其次检查是否有压缩包
elif [ -f "project.tar.gz" ]; then
    echo "正在解压 project.tar.gz..."
    if tar -zxvf project.tar.gz; then
        echo "源码解压完成。"
    else
        echo "错误: project.tar.gz 解压失败，文件可能不完整或损坏 (unexpected end of file)。"
        if command -v git &> /dev/null; then
            echo "尝试通过 Git 重新拉取代码..."
            git init
            git remote add origin https://github.com/bluewatercg/fabric-realty.git || true
            git fetch origin
            git reset --hard origin/main
            echo "代码通过 Git 修复完成。"
        else
            exit 1
        fi
    fi
# 如果都没有，尝试直接克隆
else
    if command -v git &> /dev/null; then
        echo "未找到源码且未发现压缩包，正在通过 Git 克隆最新代码..."
        git init
        git remote add origin https://github.com/bluewatercg/fabric-realty.git || true
        git fetch origin
        git reset --hard origin/main
        echo "代码克隆完成。"
    else
        echo "错误: 未找到 .git 目录且未找到 project.tar.gz，且系统未安装 git。"
        exit 1
    fi
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
