$ErrorActionPreference = "Stop"

# === 覆盖 deploy.log ===
Set-Content -Path "deploy.log" -Value "=== 部署开始 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$LOG_FILE = "deploy.log"

# === 日志增强模块 ===
function Write-LogFile {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LOG_FILE -Value "[$timestamp] $Message"
}

function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Write-LogFile "[INFO] $Message"
}

function Log-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
    Write-LogFile "[OK]   $Message"
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    Write-LogFile "[WARN] $Message"
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERR]  $Message" -ForegroundColor Red
    Write-LogFile "[ERR]  $Message"
    exit 1
}

# === 核心命令执行模块（捕获 stdout + stderr + 写入日志） ===
function Run-Command {
    param(
        [string]$Command,
        [string]$ErrorMessage
    )

    Log-Info "执行命令：$Command"

    # 捕获 stdout + stderr，并写入 deploy.log
    $output = Invoke-Expression $Command 2>&1 | Tee-Object -FilePath $LOG_FILE -Append

    if ($LASTEXITCODE -ne 0) {
        Log-Error "$ErrorMessage`n命令输出：`n$output"
    }
}

# === 配置区 ===
$REMOTE_IP   = "192.168.1.41"
$REMOTE_USER = "root"
$REMOTE_PATH = "/home/deploy-fabric"

$SERVER_IMAGE = "togettoyou/fabric-realty.server:latest"
$WEB_IMAGE    = "togettoyou/fabric-realty.web:latest"

$BUILD_DIR    = "build"
$PACKAGE      = "deploy_package.tar.gz"
# ==============


# === Step 1: 清理 build 目录 ===
Log-Info "Step 1: 清理 build 目录"
if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
Log-Success "build 目录已准备好"


# === Step 2: 构建后端镜像 ===
Log-Info "Step 2: 构建后端镜像"
Push-Location application/server

Run-Command `
    "docker build -t $SERVER_IMAGE ." `
    "后端镜像构建失败！请检查 Dockerfile 或代码。"

Pop-Location
Log-Success "后端镜像构建完成"


# === Step 3: 构建前端镜像 ===
Log-Info "Step 3: 构建前端镜像"
Push-Location application/web

Run-Command `
    "docker build -t $WEB_IMAGE ." `
    "前端镜像构建失败！请检查前端代码或 Dockerfile。"

Pop-Location
Log-Success "前端镜像构建完成"


# === Step 4: 导出镜像 ===
Log-Info "Step 4: 导出镜像"

Run-Command `
    "docker save -o '$BUILD_DIR/server_image.tar' $SERVER_IMAGE" `
    "导出后端镜像失败！"

Run-Command `
    "docker save -o '$BUILD_DIR/web_image.tar' $WEB_IMAGE" `
    "导出前端镜像失败！"

Log-Success "镜像导出完成"


# === Step 5: 打包项目源码 ===
Log-Info "Step 5: 打包项目源码"

Run-Command `
    "tar -zcvf '$BUILD_DIR/project.tar.gz' --exclude-from ./.tarignore ." `
    "项目源码打包失败！"

$projectSize = (Get-Item "$BUILD_DIR/project.tar.gz").Length
if ($projectSize -eq 0) {
    Log-Error "project.tar.gz 为 0 KB，打包失败！"
}

Log-Success "项目源码打包完成"


# === Step 6: 生成最终部署包 ===
Log-Info "Step 6: 生成最终部署包 deploy_package.tar.gz"

if (Test-Path $PACKAGE) { Remove-Item $PACKAGE -Force }

Copy-Item "Step2_Linux_deploy.sh" "$BUILD_DIR/Step2_Linux_deploy.sh" -Force

Run-Command `
    "tar -zcvf $PACKAGE -C $BUILD_DIR server_image.tar web_image.tar project.tar.gz Step2_Linux_deploy.sh" `
    "生成最终部署包失败！"

Log-Success "最终部署包生成完成"


# === Step 7: 上传到 Linux（手动输入密码） ===
Log-Info "Step 7: 上传到 Linux ($REMOTE_IP)"

Run-Command `
    "scp -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' $PACKAGE ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_PATH}" `
    "上传部署包失败！"

Log-Success "上传完成"


# === Step 8: 远程执行 Linux 部署脚本（手动输入密码） ===
# === Step 8: 远程解压并执行部署脚本 ===
Log-Info "Step 8: 远程解压并执行部署脚本"

# 逻辑说明：
# 1. cd 到目录
# 2. tar 命令仅单独解压出 Step2_Linux_deploy.sh 这个文件
# 3. 给脚本加执行权限
# 4. 执行脚本
$RemoteCommand = "cd ${REMOTE_PATH} && tar -zxvf deploy_package.tar.gz Step2_Linux_deploy.sh && chmod +x Step2_Linux_deploy.sh && ./Step2_Linux_deploy.sh"

Run-Command `
    "ssh -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' ${REMOTE_USER}@${REMOTE_IP} '$RemoteCommand'" `
    "远程执行部署脚本失败！"

Log-Success "远程部署执行完成"


Write-Host "`n=== Windows 部署完成！ ===" -ForegroundColor Green
Write-LogFile "=== Windows 部署完成 ==="
