# 供应链系统服务器启动脚本 (Windows)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  供应链协同系统服务器启动" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 检查配置文件
if (-not (Test-Path "config\config.yaml")) {
    Write-Host "❌ 错误: 配置文件 config\config.yaml 不存在" -ForegroundColor Red
    exit 1
}

# 检查可执行文件
if (-not (Test-Path "app_server.exe")) {
    Write-Host "⚠️  警告: app_server.exe 不存在，开始编译..." -ForegroundColor Yellow
    go build -o app_server.exe main.go
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 编译失败" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ 编译成功" -ForegroundColor Green
}

# 启动服务器
Write-Host ""
Write-Host "🚀 启动服务器..." -ForegroundColor Green
Write-Host "📍 Swagger UI: http://192.168.1.41:8080/swagger/index.html" -ForegroundColor Yellow
Write-Host "📍 本地访问: http://localhost:8080/swagger/index.html" -ForegroundColor Yellow
Write-Host ""
Write-Host "按 Ctrl+C 停止服务器" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

.\app_server.exe
