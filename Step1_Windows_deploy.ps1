$ErrorActionPreference = "Stop"

# === 配置区 ===
$REMOTE_IP   = "192.168.1.41"
$REMOTE_USER = "root"
$REMOTE_PATH = "/home/deploy-fabric"
$SERVER_IMAGE = "togettoyou/fabric-realty.server:latest"
$WEB_IMAGE    = "togettoyou/fabric-realty.web:latest"
$BUILD_DIR    = "build"
$PACKAGE      = "deploy_package.tar.gz"
# ==============

Write-Host ">>> Step 1: 清理 build 目录" -ForegroundColor Cyan
if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null

Write-Host ">>> Step 2: 构建后端镜像" -ForegroundColor Cyan
Push-Location application/server
docker rmi -f $SERVER_IMAGE 2>$null
docker build -t $SERVER_IMAGE .
Pop-Location

Write-Host ">>> Step 3: 构建前端镜像" -ForegroundColor Cyan
Push-Location application/web
docker build -t $WEB_IMAGE .
Pop-Location

Write-Host ">>> Step 4: 导出镜像" -ForegroundColor Cyan
docker save -o "$BUILD_DIR/server_image.tar" $SERVER_IMAGE
docker save -o "$BUILD_DIR/web_image.tar" $WEB_IMAGE

Write-Host ">>> Step 5: 打包项目源码" -ForegroundColor Cyan
tar -zcvf "$BUILD_DIR/project.tar.gz" --exclude-from ./.tarignore .

# === 文件大小检查 ===
$projectSize = (Get-Item "$BUILD_DIR/project.tar.gz").Length
if ($projectSize -eq 0) {
    Write-Host "❌ project.tar.gz 为 0 KB，打包失败！" -ForegroundColor Red
    exit 1
}

Write-Host ">>> Step 6: 生成最终部署包 deploy_package.tar.gz" -ForegroundColor Cyan
if (Test-Path $PACKAGE) { Remove-Item $PACKAGE -Force }

tar -zcvf $PACKAGE `
    -C $BUILD_DIR server_image.tar `
    -C $BUILD_DIR web_image.tar `
    -C $BUILD_DIR project.tar.gz `
    Step2_Linux_deploy.sh

Write-Host ">>> Step 7: 上传到 Linux ($REMOTE_IP)" -ForegroundColor Cyan
scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" `
    $PACKAGE "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_PATH}"

Write-Host ">>> Step 8: 远程执行 Linux 部署脚本" -ForegroundColor Cyan
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" `
    "${REMOTE_USER}@${REMOTE_IP}" "bash ${REMOTE_PATH}/Step2_Linux_deploy.sh"

Write-Host "`n=== Windows 部署完成！ ===" -ForegroundColor Green
