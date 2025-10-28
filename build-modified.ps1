# OnlyOffice Server - 增量打包脚本
# 用途：只打包修改过的服务（Common 代码的修改）

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  OnlyOffice Server 增量打包" -ForegroundColor Cyan  
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$OUTPUT_DIR = "E:\onlyoffice-server-build"
$SOURCE_DIR = "E:\onlyoffice-server-build-source"  # 老镜像目录
$TARGET = "node18-linux-x64"
$COMPRESS = "GZip"  # 使用压缩减小体积

Write-Host "配置:" -ForegroundColor Yellow
Write-Host "  输出目录: $OUTPUT_DIR" -ForegroundColor Gray
Write-Host "  参考镜像: $SOURCE_DIR" -ForegroundColor Gray
Write-Host "  目标平台: $TARGET" -ForegroundColor Gray
Write-Host "  压缩方式: $COMPRESS" -ForegroundColor Gray
Write-Host ""

# 检查参考镜像
if (-not (Test-Path $SOURCE_DIR)) {
    Write-Host "错误: 找不到参考镜像目录 $SOURCE_DIR" -ForegroundColor Red
    Write-Host "请修改脚本中的 `$SOURCE_DIR 变量" -ForegroundColor Yellow
    exit 1
}

# 清理并创建输出目录
Write-Host "[1/6] 准备输出目录..." -ForegroundColor Yellow
Remove-Item -Path $OUTPUT_DIR -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

# 打包 DocService (包含 storage-s3.js 修改)
Write-Host "[2/6] 打包 DocService (包含 Common 修改)..." -ForegroundColor Yellow
Set-Location DocService
pkg ./package.json `
    --targets $TARGET `
    --output "$OUTPUT_DIR\DocService\docservice" `
    --compress $COMPRESS `
    --options "max-old-space-size=4096"
Set-Location ..
Write-Host "  ✓ DocService 打包完成" -ForegroundColor Green

# 打包 FileConverter (包含 storage-s3.js 修改)
Write-Host "[3/6] 打包 FileConverter (包含 Common 修改)..." -ForegroundColor Yellow
Set-Location FileConverter
pkg ./package.json `
    --targets $TARGET `
    --output "$OUTPUT_DIR\FileConverter\converter" `
    --compress $COMPRESS `
    --options "max-old-space-size=4096"
Set-Location ..
Write-Host "  ✓ FileConverter 打包完成" -ForegroundColor Green

# 从老镜像复制 Metrics (未修改，无需重新打包)
Write-Host "[4/6] 复制 Metrics (未修改)..." -ForegroundColor Yellow
Copy-Item -Path "$SOURCE_DIR\Metrics" -Destination $OUTPUT_DIR -Recurse -Force
Write-Host "  ✓ Metrics 已复制" -ForegroundColor Green

# 从老镜像复制 FileConverter/bin (C++ core 组件)
Write-Host "[5/6] 复制 Core 组件..." -ForegroundColor Yellow
Copy-Item -Path "$SOURCE_DIR\FileConverter\bin" -Destination "$OUTPUT_DIR\FileConverter\" -Recurse -Force
Write-Host "  ✓ FileConverter/bin 已复制" -ForegroundColor Green

# 从老镜像复制其他必需文件
Write-Host "[6/6] 复制配置和脚本..." -ForegroundColor Yellow
Copy-Item -Path "$SOURCE_DIR\tools" -Destination $OUTPUT_DIR -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$SOURCE_DIR\schema" -Destination $OUTPUT_DIR -Recurse -Force
Copy-Item -Path "$SOURCE_DIR\Common" -Destination $OUTPUT_DIR -Recurse -Force
Copy-Item -Path "$SOURCE_DIR\welcome" -Destination $OUTPUT_DIR -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$SOURCE_DIR\info" -Destination $OUTPUT_DIR -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ 配置和脚本已复制" -ForegroundColor Green

# 修改配置文件示例
Write-Host ""
Write-Host "创建配置示例..." -ForegroundColor Yellow
$configExample = @"
{
  "storage": {
    "name": "storage-s3",
    "region": "cn-beijing",
    "endpoint": "https://oss-cn-beijing-internal.aliyuncs.com",
    "bucketName": "mult-test",
    "storageFolderName": "cache",
    "cacheFolderName": "data",
    "accessKeyId": "your_access_key",
    "secretAccessKey": "your_secret_key",
    "sslEnabled": true,
    "s3ForcePathStyle": false,
    "urlExpires": 86400,
    "externalHost": "https://mult-test.oss-cn-beijing.aliyuncs.com",
    "useDirectStorageUrls": true
  },
  "persistentStorage": {
    "storageFolderName": "forgotten"
  }
}
"@
$configExample | Out-File -FilePath "$OUTPUT_DIR\Common\config\storage-config-example.json" -Encoding UTF8

# 生成版本信息
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$buildInfo = @"
OnlyOffice DocumentServer - 定制版本
====================================

构建时间: $timestamp
目标平台: Linux x64 (node18-linux-x64)
压缩方式: $COMPRESS

修改内容
--------
文件: Common/sources/storage/storage-s3.js
功能: 支持 externalHost 在 useDirectStorageUrls: true 时生效

重新打包的服务
--------------
✅ DocService/docservice       - 包含 storage-s3.js 修改
✅ FileConverter/converter     - 包含 storage-s3.js 修改

从老镜像复制的组件
------------------
- Metrics/metrics              - 未修改，直接使用老版本
- FileConverter/bin/           - C++ core 组件（未修改）
- tools/                       - 工具集
- Common/config/               - 配置文件
- schema/                      - 数据库脚本

配置说明
--------
编辑 Common/config/default.json，添加 externalHost 配置：

{
  "storage": {
    "endpoint": "https://oss-cn-beijing-internal.aliyuncs.com",      // 内网
    "externalHost": "https://mult-test.oss-cn-beijing.aliyuncs.com", // 公网
    "useDirectStorageUrls": true
  }
}

效果:
- OnlyOffice 服务器通过内网访问 OSS (免费)
- 浏览器通过公网访问 OSS (正常收费)
- 服务器带宽零消耗

部署说明
--------
1. 上传到服务器: scp -r onlyoffice-server-build root@server:/opt/onlyoffice/
2. 设置权限: chmod +x DocService/docservice FileConverter/converter Metrics/metrics
3. 修改配置: vim Common/config/default.json
4. 启动服务: ./DocService/docservice

"@
$buildInfo | Out-File -FilePath "$OUTPUT_DIR\BUILD_INFO.txt" -Encoding UTF8

# 比较文件大小
Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  打包完成！" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "文件大小对比:" -ForegroundColor Cyan
Write-Host ""

$oldDocService = Get-Item "$SOURCE_DIR\DocService\docservice"
$newDocService = Get-Item "$OUTPUT_DIR\DocService\docservice"
Write-Host "DocService:" -ForegroundColor Yellow
Write-Host "  老版本: $([math]::Round($oldDocService.Length/1MB, 2)) MB" -ForegroundColor Gray
Write-Host "  新版本: $([math]::Round($newDocService.Length/1MB, 2)) MB" -ForegroundColor Gray

$oldConverter = Get-Item "$SOURCE_DIR\FileConverter\converter"
$newConverter = Get-Item "$OUTPUT_DIR\FileConverter\converter"
Write-Host "FileConverter:" -ForegroundColor Yellow
Write-Host "  老版本: $([math]::Round($oldConverter.Length/1MB, 2)) MB" -ForegroundColor Gray
Write-Host "  新版本: $([math]::Round($newConverter.Length/1MB, 2)) MB" -ForegroundColor Gray

Write-Host ""
Write-Host "输出目录: $OUTPUT_DIR" -ForegroundColor Cyan
Write-Host "配置示例: $OUTPUT_DIR\Common\config\storage-config-example.json" -ForegroundColor Cyan
Write-Host ""

