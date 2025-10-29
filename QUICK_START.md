# 快速开始：Server 重新打包

## 🚀 5 分钟快速上手

### 前提条件

```powershell
# 1. 检查 Node.js 是否已安装（需要 16.x 或更高）
node --version

# 2. 检查 npm 是否已安装
npm --version

# 3. 安装 pkg（如果未安装）
npm install -g pkg
```

### Windows 用户快速指南

如果您在 **Windows** 上开发，但要部署到 **Linux** 服务器：

```powershell
# 进入 server 目录
cd "d:\工作\【0】code-极狐\14、server\OnlyOffice-DocumentServer\server"

# 打包（会自动打包成 Linux 格式）
python rebuild_server.py

# 或者指定目标目录
python rebuild_server.py --target-dir e:/onlyoffice-server-build
```

**注意**：
- ✅ 在 Windows 上打包 Linux 可执行文件是**正常的**
- ✅ pkg 工具支持跨平台打包
- ⚠️ 打包后的文件只能在 Linux 上运行

### Linux 用户快速指南

如果您在 **Linux** 上开发和部署：

```bash
# 进入 server 目录
cd server

# 打包并部署
python rebuild_server.py --target-dir /path/to/deployment

# 重启服务
sudo systemctl restart ds-docservice ds-converter ds-metrics
```

## 🎯 常用命令

### 只打包 DocService

```powershell
python rebuild_server.py --services docservice
```

### 只打包不部署（测试打包）

```powershell
python rebuild_server.py --no-deploy
```

### 打包所有服务

```powershell
python rebuild_server.py --services all
```

### 打包成 Windows 格式（在 Windows 上运行）

```powershell
python rebuild_server.py --pkg-target node20-win-x64
```

## 📋 完整流程示例

### 场景 1: 在 Windows 上开发，部署到 Linux

```powershell
# 1. 修改代码
# 编辑 DocService/sources/DocsCoServer.js

# 2. 打包（自动打包成 Linux 格式）
cd server
python rebuild_server.py --services docservice

# 3. 文件会自动部署到目标目录
# e:/onlyoffice-server-build/DocService/docservice

# 4. 在 Linux 服务器上重启服务
ssh user@linux-server
sudo systemctl restart ds-docservice
```

### 场景 2: 快速开发调试

```powershell
# 只打包，不部署
python rebuild_server.py --services docservice --no-deploy

# 手动复制文件测试
copy DocService\docservice e:\onlyoffice-server-build-source\DocService\

# 在 Linux 上测试
# cd /path/to/DocService
# NODE_ENV=production-linux NODE_CONFIG_DIR=../Common/config ./docservice
```

## ⚠️ 常见问题

### Q1: `pkg: command not found`

**解决**：
```powershell
npm install -g pkg
```

### Q2: 打包失败 - 内存不足

**解决**：
```powershell
# 增加 Node.js 内存
$env:NODE_OPTIONS="--max-old-space-size=8192"
python rebuild_server.py
```

### Q3: 在 Windows 上打包的 Linux 文件能运行吗？

**答**：可以！pkg 支持跨平台打包。您可以：
- 在 Windows 上打包 → 在 Linux 上运行 ✅
- 在 Linux 上打包 → 在 Windows 上运行 ✅
- 在 macOS 上打包 → 在 Linux 上运行 ✅

### Q4: 如何验证打包结果？

**在 Windows 上查看**：
```powershell
# 查看文件大小
dir DocService\docservice

# 文件类型会显示为 "application" 或无扩展名
```

**在 Linux 上验证**：
```bash
file docservice
# 输出应该是: ELF 64-bit LSB executable

# 测试运行
./docservice --version
```

### Q5: 部署后服务无法启动

**检查步骤**：

1. **确认可执行权限**：
```bash
chmod +x /path/to/docservice
```

2. **查看日志**：
```bash
sudo journalctl -u ds-docservice -n 50
```

3. **手动运行测试**：
```bash
cd /path/to/DocService
NODE_ENV=production-linux NODE_CONFIG_DIR=../Common/config ./docservice
```

## 🔧 高级用法

### 自定义 pkg 目标

```powershell
# ARM64 Linux
python rebuild_server.py --pkg-target node20-linux-arm64

# Windows
python rebuild_server.py --pkg-target node20-win-x64

# macOS
python rebuild_server.py --pkg-target node20-macos-x64
```

### 批处理脚本（Windows）

创建 `build.bat`:

```batch
@echo off
echo 开始打包 OnlyOffice Server...

cd /d "%~dp0"
python rebuild_server.py --services docservice converter metrics

if %ERRORLEVEL% EQU 0 (
    echo 打包成功！
) else (
    echo 打包失败，错误代码: %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo 完成！文件已部署到 e:/onlyoffice-server-build
pause
```

### PowerShell 脚本

创建 `build.ps1`:

```powershell
# OnlyOffice Server 快速打包脚本
$ErrorActionPreference = "Stop"

Write-Host "开始打包 OnlyOffice Server..." -ForegroundColor Green

Push-Location $PSScriptRoot

try {
    python rebuild_server.py --services docservice converter metrics
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ 打包成功！" -ForegroundColor Green
    } else {
        Write-Host "✗ 打包失败" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Write-Host "完成！文件已部署到 e:/onlyoffice-server-build" -ForegroundColor Cyan
```

使用方法：
```powershell
# 允许运行脚本（首次需要）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行
.\build.ps1
```

## 📊 性能参考

### 打包时间（Windows 10, i7 CPU）

| 服务 | 首次打包 | 增量打包 | 文件大小 |
|------|---------|---------|---------|
| DocService | ~40秒 | ~30秒 | 45 MB |
| Converter | ~30秒 | ~25秒 | 35 MB |
| Metrics | ~25秒 | ~20秒 | 30 MB |
| **总计** | **~95秒** | **~75秒** | 110 MB |

### 部署时间

- 复制文件：< 5 秒（本地磁盘）
- 通过网络：取决于带宽（100MB 约需 10-30 秒）

## 📖 更多信息

- [详细文档](./README_REBUILD.md) - 完整的使用说明
- [构建指南](../docs/development/build.md) - 完整构建流程
- [打包配置](../docs/development/docservice-packaging.md) - 打包配置详解

---

**祝您开发顺利！** 🎉

