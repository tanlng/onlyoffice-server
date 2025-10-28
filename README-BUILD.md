# Server 打包指南

本指南说明如何只打包 server 目录（不编译 core 组件）。

## 🎯 打包方案

使用 `pkg` 工具将 Node.js 应用打包成独立可执行文件。

## 📋 前置条件

1. **已安装 Node.js** (推荐 18.x)
2. **已运行 `npm run build`** (安装所有依赖)
3. **有已编译的 core 组件** (C++ 二进制文件)

## 🚀 快速开始

### Windows

```powershell
# 在 server 目录下执行
.\build-server.ps1
```

### Linux

```bash
# 在 server 目录下执行
chmod +x build-server-linux.sh
./build-server-linux.sh
```

## 📦 打包产物

打包完成后，会在 `build/server/` 目录生成：

```
build/server/
├── DocService/
│   └── docservice.exe (或 docservice)   # 👈 Node.js 打包的可执行文件
├── FileConverter/
│   └── converter.exe (或 converter)
├── Metrics/
│   └── metrics.exe (或 metrics)
├── Common/
│   └── config/                          # 👈 配置文件
│       ├── default.json
│       └── log4js/
├── schema/                              # 👈 数据库脚本
└── BUILD_INFO.txt                       # 👈 构建信息
```

## ⚠️ 重要说明

### 1. 缺少 core 组件

打包后的文件**不包含** C++ 编译的 core 组件，需要手动复制：

```powershell
# 从已有的编译版本复制
Copy-Item -Path "E:\LarkData\Downloads\server\FileConverter\bin" `
          -Destination "build\server\FileConverter\" -Recurse
```

需要复制的文件：
- `x2t` - 文档转换工具
- `*.so` 或 `*.dll` - 共享库
- `docbuilder` - 文档构建器
- 字体文件等

### 2. 完整的 server 目录结构

完整部署需要：

```
server/
├── DocService/
│   └── docservice.exe          # pkg 打包
├── FileConverter/
│   ├── converter.exe            # pkg 打包
│   └── bin/                     # 👈 从已编译版本复制
│       ├── x2t
│       ├── libDjVuFile.so
│       └── ...
├── Metrics/
│   └── metrics.exe              # pkg 打包
├── Common/
│   └── config/
├── tools/                       # 👈 从已编译版本复制
│   ├── allfontsgen
│   └── ...
└── schema/
```

## 🔧 自定义打包

### 修改目标平台

编辑脚本中的 `TARGET` 变量：

```powershell
# Windows x64
$TARGET = "node18-win-x64"

# Linux x64
$TARGET = "node18-linux-x64"

# Linux ARM64
$TARGET = "node18-linux-arm64"

# macOS
$TARGET = "node18-macos-x64"
```

### 修改输出目录

```powershell
$OUTPUT_DIR = ".\build\server"  # 修改为你想要的路径
```

## 📝 包含你的修改

你对 `storage-s3.js` 的修改已经包含在打包中：

```javascript
// server/Common/sources/storage/storage-s3.js
async function getDirectSignedUrl(...) {
  // ✅ 支持 externalHost 配置
  let s3Client;
  if (storageCfg.externalHost) {
    const externalStorageCfg = { ...storageCfg, endpoint: storageCfg.externalHost };
    s3Client = getS3Client(externalStorageCfg);
  }
  else { 
    s3Client = getS3Client(storageCfg)
  }
  return await getSignedUrl(s3Client, command, options);
}
```

## 🎯 完整打包流程

如果你想生成完全可用的发行版：

### 方式 1：基于已有编译版本

```powershell
# 1. 打包 server
.\build-server.ps1

# 2. 复制 core 组件
Copy-Item -Path "E:\LarkData\Downloads\server\FileConverter\bin" `
          -Destination "build\server\FileConverter\" -Recurse
Copy-Item -Path "E:\LarkData\Downloads\server\tools" `
          -Destination "build\server\" -Recurse

# 3. 压缩打包
Compress-Archive -Path "build\server\*" -DestinationPath "onlyoffice-server-custom.zip"
```

### 方式 2：使用原项目的 Makefile

如果需要完整的构建（包括 core 编译）：

```bash
# 在项目根目录
cd document-server-package

# 只构建 documentserver 部分
make documentserver

# 打包
make deb  # 或 rpm、tar
```

## 🐛 故障排除

### pkg 打包失败

```bash
# 清理并重新安装依赖
rm -rf node_modules
npm ci

# 更新 pkg
npm install -g pkg@latest
```

### 内存不足

增加 Node.js 内存限制：

```powershell
$env:NODE_OPTIONS="--max-old-space-size=8192"
.\build-server.ps1
```

## 📚 参考资料

- [pkg 官方文档](https://github.com/vercel/pkg)
- [OnlyOffice 构建文档](https://helpcenter.onlyoffice.com/installation/docs-community-compile.aspx)

