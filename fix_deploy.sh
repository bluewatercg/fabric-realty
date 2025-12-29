#!/bin/bash
# 这是一个用于 Linux/macOS/WSL 环境的 Shell 脚本。
# 最终版：旨在创建一个最小化的部署包，以适配现有的 remote_install.sh 脚本。
# 新增功能：支持 "upload" 参数，跳过本地打包，直接执行上传和远程部署。

set -e

# --- 日志和颜色配置 ---
LOG_FILE="deploy.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${CYAN}[INFO] $1${NC}"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]   $1${NC}"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK]   $1" >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERR]  $1${NC}" >&2; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERR]  $1" >> "$LOG_FILE"; exit 1; }

# --- 配置区 ---
REMOTE_IP="192.168.1.41"
REMOTE_USER="root"
REMOTE_PATH="/home/deploy-fabric"

SERVER_IMAGE="togettoyou/fabric-realty.server:latest"
WEB_IMAGE="togettoyou/fabric-realty.web:latest"

BUILD_DIR="build"
PACKAGE="deploy_package.tar.gz"
# ================

# ====================================================================
# === [核心修改] Step 0: 解析参数，判断是否跳过打包 ===
# ====================================================================
UPLOAD_ONLY=false
if [ "$1" == "upload" ]; then
    UPLOAD_ONLY=true
    log_info "检测到 'upload' 参数，将跳过本地构建和打包环节。"
fi

echo "=== 部署开始 $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOG_FILE"


# ====================================================================
# === 仅在没有 'upload' 参数时执行本地构建和打包 ===
# ====================================================================
if [ "$UPLOAD_ONLY" = false ]; then

    # Step 1: 清理并创建构建目录
    log_info "Step 1: 清理 build 目录"
    rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
log_success "build 目录已准备好"

    # Step 2 & 3: 构建前后端镜像
    log_info "Step 2 & 3: 构建前后端镜像"
    (cd application/server && docker build -t "$SERVER_IMAGE" .) || log_error "后端镜像构建失败！"
    (cd application/web && docker build -t "$WEB_IMAGE" .) || log_error "前端镜像构建失败！"
log_success "前后端镜像构建完成"

    # Step 4: 导出镜像
    log_info "Step 4: 导出镜像"
    docker save -o "$BUILD_DIR/server_image.tar" "$SERVER_IMAGE" || log_error "导出后端镜像失败！"
    docker save -o "$BUILD_DIR/web_image.tar" "$WEB_IMAGE" || log_error "导出前端镜像失败！"
log_success "镜像导出完成"

    # Step 5: 创建最小化的 project.tar.gz
    log_info "Step 5: 创建最小化的 project.tar.gz"
    PROJECT_SOURCE_DIR="$BUILD_DIR/project_source"
mkdir -p "$PROJECT_SOURCE_DIR/application"
cp -r "network" "$PROJECT_SOURCE_DIR/"
cp -r "chaincode" "$PROJECT_SOURCE_DIR/"
cp "application/docker-compose.yml" "$PROJECT_SOURCE_DIR/application/"
cp "install.sh" "$PROJECT_SOURCE_DIR/"
cp "uninstall.sh" "$PROJECT_SOURCE_DIR/"
    (cd "$PROJECT_SOURCE_DIR" && tar -zcvf "../project.tar.gz" .) || log_error "创建 project.tar.gz 失败"
rm -rf "$PROJECT_SOURCE_DIR"
log_success "已创建干净的 project.tar.gz"

    # Step 6: 生成最终部署包
    log_info "Step 6: 生成最终部署包 $PACKAGE"
rm -f "$PACKAGE"
cp "remote_install.sh" "$BUILD_DIR/"
    (cd "$BUILD_DIR" && tar -zcvf "../$PACKAGE" server_image.tar web_image.tar project.tar.gz remote_install.sh) || log_error "生成最终部署包失败！"
log_success "最终部署包生成完成"

else
    # 在 upload-only 模式下，检查部署包是否存在
    if [ ! -f "$PACKAGE" ]; then
        log_error "在 'upload' 模式下, 部署包 $PACKAGE 未找到。请先执行一次完整的打包 (不带任何参数)。"
    fi
fi


# ====================================================================
# === Step 7 & 8: 上传和远程部署 (始终执行) ===
# ====================================================================
log_info "Step 7: 上传到 Linux ($REMOTE_IP)"
scp -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' "$PACKAGE" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_PATH}/" || log_error "上传部署包失败！"
log_success "上传完成"

log_info "Step 8: 远程解压并执行 remote_install.sh"
RemoteCommand="cd ${REMOTE_PATH} && tar -zxvf ${PACKAGE} && chmod +x remote_install.sh && ./remote_install.sh"
ssh -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' "${REMOTE_USER}@${REMOTE_IP}" "$RemoteCommand" || log_error "远程执行部署脚本失败！"
log_success "远程部署执行完成"


echo -e "\n${GREEN}=== 部署包构建和远程执行完成！ ===${NC}"
echo "=== 部署完成 ===" >> "$LOG_FILE"