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

$PackageName = "deploy_package.tar.gz"

# 2. 将所有构建产物打包成一个单独的压缩文件
Write-Host "`n>>> 第二步：创建部署压缩包 ($PackageName)..." -ForegroundColor Cyan
tar -zc -C build -f $PackageName . 2>> $logFile
Write-Host "部署包创建成功."

# 3. 上传压缩包到服务器
Write-Host "`n>>> 第三步：使用 scp 上传文件 ($REMOTE_IP)..." -ForegroundColor Cyan
Write-Host "提示：传输完成后，文件将存放在 ${REMOTE_PATH}" -ForegroundColor Yellow
# 使用 -o 选项避免主机密钥检查的交互提示
scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" $PackageName "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_PATH}/" 2>> $logFile
Write-Host "上传成功."

# 4. 在服务器上解压
Write-Host "`n>>> 第四步：在服务器上解压并清理..." -ForegroundColor Cyan
$remoteCommand = "cd ${REMOTE_PATH} && tar -zxf ${PackageName} && rm ${PackageName} && dos2unix ./remote_install.sh && chmod +x ./remote_install.sh"
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "${REMOTE_USER}@${REMOTE_IP}" $remoteCommand 2>> $logFile
Write-Host "远程解压和准备工作完成."

Write-Host "`n✅ 构建与上传完成！" -ForegroundColor Green
Write-Host "请现在登录服务器执行: cd ${REMOTE_PATH} && ./remote_install.sh"
Write-Host "系统访问地址: http://${REMOTE_IP}:8000"
