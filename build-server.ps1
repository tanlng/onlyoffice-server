# OnlyOffice DocumentServer - Server 打包脚本
# 用途：将 server 目录打包成独立可执行文件

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  OnlyOffice Server 打包工具" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# 配置
$TARGET = "node18-win-x64"  # Windows x64
$OUTPUT_DIR = ".\build\server"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"

# 创建输出目录
Write-Host "[1/6] 创建输出目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\Common\config" | Out-Null
New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\Common\config\log4js" | Out-Null

# 安装 pkg（如果没有）
Write-Host "[2/6] 检查 pkg 工具..." -ForegroundColor Yellow
if (-not (Get-Command pkg -ErrorAction SilentlyContinue)) {
    Write-Host "   安装 pkg..." -ForegroundColor Gray
    npm install -g pkg
}

# 打包 DocService
Write-Host "[3/6] 打包 DocService..." -ForegroundColor Yellow
Set-Location DocService
pkg ./package.json `
    --targets $TARGET `
    --output "../$OUTPUT_DIR/DocService/docservice.exe" `
    --options "max-old-space-size=4096"
Set-Location ..

# 打包 FileConverter
Write-Host "[4/6] 打包 FileConverter..." -ForegroundColor Yellow
Set-Location FileConverter
pkg ./package.json `
    --targets $TARGET `
    --output "../$OUTPUT_DIR/FileConverter/converter.exe" `
    --options "max-old-space-size=4096"
Set-Location ..

# 打包 Metrics
Write-Host "[5/6] 打包 Metrics..." -ForegroundColor Yellow
Set-Location Metrics
pkg ./package.json `
    --targets $TARGET `
    --output "../$OUTPUT_DIR/Metrics/metrics.exe" `
    --options "max-old-space-size=4096"
Set-Location ..

# 复制配置文件
Write-Host "[6/6] 复制配置文件..." -ForegroundColor Yellow
Copy-Item -Path "Common\config\*.json" -Destination "$OUTPUT_DIR\Common\config\" -Force
Copy-Item -Path "Common\config\log4js\*.json" -Destination "$OUTPUT_DIR\Common\config\log4js\" -Force

# 复制数据库脚本
Write-Host "   复制数据库脚本..." -ForegroundColor Gray
Copy-Item -Path "schema" -Destination "$OUTPUT_DIR\" -Recurse -Force

# 生成版本信息
Write-Host "   生成版本信息..." -ForegroundColor Gray
$versionInfo = @"
OnlyOffice DocumentServer - Server Build
========================================
Build Time: $TIMESTAMP
Target: $TARGET
Modified: storage-s3.js (externalHost support)

Executables:
- DocService/docservice.exe
- FileConverter/converter.exe  
- Metrics/metrics.exe

Config:
- Common/config/*.json
"@
$versionInfo | Out-File -FilePath "$OUTPUT_DIR\BUILD_INFO.txt" -Encoding UTF8

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  打包完成！" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "输出目录: $OUTPUT_DIR" -ForegroundColor Cyan
Write-Host ""
Write-Host "提示：" -ForegroundColor Yellow
Write-Host "  1. 可执行文件已生成，但还需要 core 组件（C++ 二进制文件）" -ForegroundColor Gray
Write-Host "  2. 从 E:\LarkData\Downloads\server\FileConverter\bin 复制二进制文件" -ForegroundColor Gray
Write-Host "  3. 配置文件在 Common/config/ 目录" -ForegroundColor Gray
Write-Host ""

