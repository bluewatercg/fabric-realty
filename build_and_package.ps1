$ErrorActionPreference = "Stop"

$SERVER_IMAGE = "togettoyou/fabric-realty.server:latest"
$WEB_IMAGE = "togettoyou/fabric-realty.web:latest"
$BUILD_DIR = "build"

Write-Host "=== 1. 清理并准备 build 目录 ===" -ForegroundColor Cyan
if (Test-Path $BUILD_DIR) { 
    Remove-Item -Path $BUILD_DIR -Recurse -Force 
}
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
Write-Host "旧文件已清理，目录 $BUILD_DIR 已就绪。"

Write-Host "=== 2. 构建后端镜像 (Server) ===" -ForegroundColor Cyan
Push-Location application/server
# 强制删除旧镜像以确保构建最新
docker rmi -f $SERVER_IMAGE 2>$null
docker build -t $SERVER_IMAGE .
Pop-Location

Write-Host "=== 3. 构建前端镜像 (Web) ===" -ForegroundColor Cyan
Push-Location application/web
docker build -t $WEB_IMAGE .
Pop-Location

Write-Host "=== 4. 导出镜像为 .tar 文件 ===" -ForegroundColor Cyan
docker save -o "$BUILD_DIR/server_image.tar" $SERVER_IMAGE
docker save -o "$BUILD_DIR/web_image.tar" $WEB_IMAGE
Write-Host "镜像已导出至 $BUILD_DIR 目录。"

Write-Host "=== 5. 打包项目源码 (排除 build 与无关目录) ===" -ForegroundColor Cyan
# Windows 11 自带 tar 命令
tar -zcf "$BUILD_DIR/project.tar.gz" --exclude='node_modules' --exclude='.git' --exclude='temp_mvp1' --exclude="$BUILD_DIR" .

Write-Host "`n=== 大功告成！ ===" -ForegroundColor Green
Write-Host "请将 $BUILD_DIR 目录下的以下三个文件上传到服务器部署："
Write-Host "1. $BUILD_DIR/server_image.tar"
Write-Host "2. $BUILD_DIR/web_image.tar"
Write-Host "3. $BUILD_DIR/project.tar.gz"
