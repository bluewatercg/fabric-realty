$ErrorActionPreference = "Stop"

# --- 配置区 ---
$REMOTE_IP = "192.168.1.41"
$REMOTE_USER = "root"
$REMOTE_PATH = "/home/deploy-fabric"
# -------------

# 1. 执行本地构建和打包
Write-Host ">>> 第一步：开始本地构建与打包..." -ForegroundColor Cyan
./build_and_package.ps1

# 2. 一次性流式上传到服务器 (自动同步 build 目录及远程脚本)
Write-Host "`n>>> 第二步：连接服务器并传输文件 ($REMOTE_IP)..." -ForegroundColor Cyan
Write-Host "提示：传输完成后，文件将存放在 ${REMOTE_PATH}" -ForegroundColor Yellow

# 只进行传输和解压，不再调用远程脚本进行安装
tar -zc -C build server_image.tar web_image.tar project.tar.gz -C .. remote_install.sh | `
ssh "${REMOTE_USER}@${REMOTE_IP}" "mkdir -p ${REMOTE_PATH} && tar -zx -C ${REMOTE_PATH} && dos2unix ${REMOTE_PATH}/remote_install.sh && chmod +x ${REMOTE_PATH}/remote_install.sh"

Write-Host "`n✅ 构建与上传完成！" -ForegroundColor Green
Write-Host "请现在登录服务器执行: cd ${REMOTE_PATH} && ./remote_install.sh"
Write-Host "系统访问地址: http://${REMOTE_IP}:8000"
