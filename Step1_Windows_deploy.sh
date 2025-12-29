#!/bin/bash

# =================配置区=================
# 遇到错误立即退出
set -e

# 远程服务器信息
REMOTE_IP="192.168.1.41"
REMOTE_USER="root"
REMOTE_PATH="/home/deploy-fabric"

# 镜像名称
SERVER_IMAGE="togettoyou/fabric-realty.server:latest"
WEB_IMAGE="togettoyou/fabric-realty.web:latest"

# 临时目录和包名
BUILD_DIR="build"
PACKAGE_NAME="deploy_package.tar.gz"
REMOTE_SCRIPT_NAME="Step2_Linux_deploy.sh"

# 日志颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${CYAN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}
# ========================================

# === 核心函数定义 ===

# 1. 构建流程
run_build() {
    log "=== 进入构建阶段 ==="

    # 清理环境
    log "Step 1: 清理 build 目录..."
    rm -rf ${BUILD_DIR}
    mkdir -p ${BUILD_DIR}

    # 构建 Docker 镜像
    log "Step 2: 构建后端镜像..."
    if [ -d "application/server" ]; then
        cd application/server
        docker build -t ${SERVER_IMAGE} . || error "后端镜像构建失败"
        cd ../..
    else
        error "找不到 application/server 目录"
    fi

    log "Step 3: 构建前端镜像..."
    if [ -d "application/web" ]; then
        cd application/web
        docker build -t ${WEB_IMAGE} . || error "前端镜像构建失败"
        cd ../..
    else
        error "找不到 application/web 目录"
    fi

    # 导出镜像
    log "Step 4: 导出镜像到文件 (这可能需要几分钟)..."
    docker save -o "${BUILD_DIR}/server_image.tar" ${SERVER_IMAGE}
    docker save -o "${BUILD_DIR}/web_image.tar" ${WEB_IMAGE}

    # 打包项目源码
    log "Step 5: 打包项目源码..."
    tar --exclude='./build' \
        --exclude='./.git' \
        --exclude='./.idea' \
        --exclude='./deploy.log' \
        --exclude='./*.tar.gz' \
        -zcvf "${BUILD_DIR}/project.tar.gz" . > /dev/null

    # 生成远程执行脚本
    log "Step 6: 生成远程部署脚本..."
    cat > "${BUILD_DIR}/${REMOTE_SCRIPT_NAME}" << 'EOF'
#!/bin/bash
set -e

echo "=== [Remote] 开始远程部署 ==="

# 1. 解压资源
echo "--> [1/5] 解压部署包..."
# 此时所有文件都在当前目录，直接解压
tar -zxvf deploy_package.tar.gz server_image.tar web_image.tar project.tar.gz > /dev/null

# 2. 加载镜像
echo "--> [2/5] 加载 Docker 镜像..."
docker load -i server_image.tar
docker load -i web_image.tar

# 3. 覆盖源码
echo "--> [3/5] 更新项目源码..."
tar -zxvf project.tar.gz > /dev/null

# 4. 部署 Fabric 网络 (自动确认)
echo "--> [4/5] 部署/重启 Fabric 网络..."
if [ -d "network" ]; then
    cd network
    chmod +x install.sh
    
    echo "------------------------------------------------"
    echo "执行 install.sh (自动确认清理旧环境)..."
    echo "y" | ./install.sh
    echo "------------------------------------------------"
    
    cd ..
else
    echo "错误：找不到 network 目录，无法部署区块链网络"
    exit 1
fi

# 5. 重启应用服务
echo "--> [5/5] 重启应用服务..."
if [ -f "application/docker-compose.yaml" ]; then
    # 强制重新创建容器
    docker-compose -f application/docker-compose.yaml down
    docker-compose -f application/docker-compose.yaml up -d
    echo "应用服务已启动"
else
    echo "警告：找不到 application/docker-compose.yaml"
fi

# 清理临时文件
rm -f server_image.tar web_image.tar project.tar.gz

echo "=== [Remote] 部署全部完成！ ==="
EOF

    # 赋予脚本执行权限
    chmod +x "${BUILD_DIR}/${REMOTE_SCRIPT_NAME}"

    # 打包最终部署包
    log "Step 7: 生成最终部署包 (${PACKAGE_NAME})..."
    cd ${BUILD_DIR}
    # 使用 * 打包，确保不带 ./ 前缀
    tar -zcvf ../${PACKAGE_NAME} * > /dev/null
    cd ..
    
    # 移动最终包到 build 目录内部（方便逻辑统一）
    mv ${PACKAGE_NAME} ${BUILD_DIR}/
}

# 2. 上传部署流程
run_deploy() {
    log "=== 进入上传部署阶段 ==="
    
    # 检查包是否存在
    if [ ! -f "${BUILD_DIR}/${PACKAGE_NAME}" ]; then
        error "找不到部署包：${BUILD_DIR}/${PACKAGE_NAME}。请先运行构建。"
    fi

    log "Step 8: 上传部署包到 ${REMOTE_IP}..."
    # 确保远程目录存在
    ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_IP} "mkdir -p ${REMOTE_PATH}"
    
    scp -o StrictHostKeyChecking=no "${BUILD_DIR}/${PACKAGE_NAME}" ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_PATH}/

    log "Step 9: 远程解压并执行部署脚本..."
    # 逻辑：
    # 1. cd 进目录
    # 2. tar -zxvf 解压指定文件 (现在包里文件没有 ./ 前缀了，应该能精准匹配)
    # 3. 运行脚本
    REMOTE_CMD="cd ${REMOTE_PATH} && tar -zxvf ${PACKAGE_NAME} ${REMOTE_SCRIPT_NAME} && chmod +x ${REMOTE_SCRIPT_NAME} && ./${REMOTE_SCRIPT_NAME}"

    ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_IP} "${REMOTE_CMD}"

    log "Step 10: 清理本地临时文件..."
    # 这里的清理可以保留，如果你想保留包以便下次快速上传，可以注释掉这行
    # rm -rf ${BUILD_DIR}

    success "=== 部署流程结束！请检查远程服务器状态 ==="
}

# ========================================
# === 主逻辑 ===
# ========================================

log "=== 开始 WSL 部署流程 ==="

if [ "$1" == "upload" ]; then
    warn "🚀 模式：直接上传 (跳过构建)"
    run_deploy
else
    log "🐢 模式：全量构建 + 部署"
    run_build
    run_deploy
fi