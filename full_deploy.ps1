$ErrorActionPreference = "Stop"
$logFile = "deploy_error.log"

# 清理旧日志，实现覆盖效果
if (Test-Path $logFile) {
    Remove-Item $logFile
}

# --- 配置区 ---
$REMOTE_IP = "192.168.1.41"
$REMOTE_USER = "root"
$REMOTE_PATH = "/home/deploy-fabric"
# -------------

# 1. 执行本地构建和打包
Write-Host ">>> 第一步：开始本地构建与打包..." -ForegroundColor Cyan
# 将此命令的错误流重定向到日志文件
./build_and_package.ps1 2>> $logFile

# 2. 一次性流式上传到服务器 (自动同步 build 目录及远程脚本)
Write-Host "`n>>> 第二步：连接服务器并传输文件 ($REMOTE_IP)..." -ForegroundColor Cyan
Write-Host "提示：传输完成后，文件将存放在 ${REMOTE_PATH}" -ForegroundColor Yellow

# 只进行传输和解压，不再调用远程脚本进行安装
# 将整个管道的错误流重定向到日志文件
(tar -c build/server_image.tar build/web_image.tar build/project.tar.gz remote_install.sh | `
ssh "${REMOTE_USER}@${REMOTE_IP}" "mkdir -p ${REMOTE_PATH} && tar -x -C ${REMOTE_PATH} && dos2unix ${REMOTE_PATH}/remote_install.sh && chmod +x ${REMOTE_PATH}/remote_install.sh") 2>> $logFile

Write-Host "`n✅ 构建与上传完成！" -ForegroundColor Green
Write-Host "请现在登录服务器执行: cd ${REMOTE_PATH} && ./remote_install.sh"
Write-Host "系统访问地址: http://${REMOTE_IP}:8000"
