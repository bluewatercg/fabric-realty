# PowerShell 脚本，用于快速更新前后端应用，而不重新部署区块链网络

$ErrorActionPreference = "Stop"

# --- 配置区 ---
# 请根据您的服务器信息修改
$REMOTE_IP = "192.168.1.41"
$REMOTE_USER = "root"
$REMOTE_PATH = "/home/deploy-fabric" # 项目在服务器上的部署路径
$SERVER_IMAGE = "togettoyou/fabric-realty.server:latest"
$WEB_IMAGE = "togettoyou/fabric-realty.web:latest"
# -------------

# 1. 本地预编译检查
Write-Host ">>> 第一步：开始本地预编译检查..." -ForegroundColor Magenta
Write-Host "正在检查后端服务..."
Push-Location application/server
go build ./...
Pop-Location

Write-Host "正在检查并构建前端..."
Push-Location application/web
# 假设本地已有 node_modules，如果环境很干净，可能需要先 npm install
npm run build
Pop-Location
Write-Host "预编译检查通过！" -ForegroundColor Green

# 2. 本地构建镜像
Write-Host "`n>>> 第二步：开始本地构建镜像..." -ForegroundColor Cyan
Push-Location application/server
docker build -t $SERVER_IMAGE .
Pop-Location

Push-Location application/web
docker build -t $WEB_IMAGE .
Pop-Location
Write-Host "镜像构建完成。"

# 3. 流式上传并加载镜像
Write-Host "`n>>> 第三步：流式上传并加载镜像到服务器..." -ForegroundColor Cyan
Write-Host "正在上传后端镜像 (fabric-realty.server)..."
docker save $SERVER_IMAGE | ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
Write-Host "正在上传前端镜像 (fabric-realty.web)..."
docker save $WEB_IMAGE | ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" "docker load"
Write-Host "镜像上传并加载完成。"

# 4. 在服务器上重启服务
Write-Host "`n>>> 第四步：在服务器上重启应用服务..." -ForegroundColor Cyan
# --no-deps 确保只重启目标服务，不重启它们依赖的其他服务
# --force-recreate 强制重新创建容器以确保使用新镜像
$remoteCommand = "cd ${REMOTE_PATH}/application && docker-compose stop fabric-realty.server fabric-realty.web && docker-compose rm -f fabric-realty.server fabric-realty.web && docker-compose up -d fabric-realty.server fabric-realty.web"
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" $remoteCommand
Write-Host "服务重启完成。"

Write-Host "`n✅ 应用更新成功！" -ForegroundColor Green
Write-Host "系统访问地址: http://${REMOTE_IP}:8000"
