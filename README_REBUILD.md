# Server 重新打包和部署指南

## 📦 使用场景

当您修改了 server 的源代码后，需要重新打包并部署到运行环境中。这个脚本可以帮助您快速完成这个过程，**无需重新编译 C++ core 库**。

## ⚠️ 重要提示：版本号管理

在重新打包之前，如果您修改了版本号，请务必先更新源代码中的版本号定义：

**版本号定义位置**：`server/Common/sources/commondefines.js`

```javascript
const buildVersion = '8.3.0';  // 修改为您的版本号
const buildNumber = 94;         // 修改为您的构建号
```

⚠️ **记住：先改版本号，再打包！** 否则打包后的服务仍然是旧版本号。

详细说明请查看：[版本号管理指南](../docs/development/version-management.md)

## 🚀 快速开始

### 方法一：使用 Python 脚本（推荐）

#### 1. 基本用法

```bash
# 进入 server 目录
cd server

# 打包并部署到默认目录（e:/onlyoffice-server-build）
python rebuild_server.py

# 指定目标目录
python rebuild_server.py --target-dir /path/to/your/server
```

#### 2. 只打包特定服务

```bash
# 只打包 DocService
python rebuild_server.py --services docservice

# 打包 DocService 和 Converter
python rebuild_server.py --services docservice converter

# 打包所有服务
python rebuild_server.py --services all
```

#### 3. 只打包不部署

```bash
# 只打包，不复制到目标目录（用于测试）
python rebuild_server.py --no-deploy
```

### 方法二：使用 Bash 脚本

```bash
# 给脚本添加执行权限
chmod +x rebuild_and_deploy.sh

# 修改脚本中的 TARGET_DIR 变量，然后执行
./rebuild_and_deploy.sh

# 或者通过命令行参数指定目标目录
./rebuild_and_deploy.sh --target-dir /path/to/your/server
```

## 📋 可用服务列表

| 服务名 | 目录 | 输出文件 | 说明 |
|--------|------|---------|------|
| `docservice` | DocService | docservice | 文档协同编辑服务（核心） |
| `converter` | FileConverter | converter | 文档格式转换服务 |
| `metrics` | Metrics | metrics | 监控统计服务 |
| `adminpanel` | AdminPanel/server | adminpanel | 管理面板后端服务 |

## 🔧 工作流程

脚本会自动执行以下步骤：

```
1. 检查 pkg 是否已安装
   └─> 如果未安装，自动执行 npm install -g pkg

2. 对每个要打包的服务执行：
   ├─> 安装依赖（如果 node_modules 不存在）
   ├─> 使用 pkg 打包成单个可执行文件
   │   ├─> DocService: node20-linux-x64, max_old_space_size=4096
   │   ├─> Converter: node20-linux-x64
   │   ├─> Metrics: node20-linux-x64
   │   └─> AdminPanel: node20-linux-x64
   └─> 验证打包结果

3. 部署（如果未指定 --no-deploy）：
   ├─> 备份目标目录中的旧文件（.backup.时间戳）
   ├─> 复制新打包的文件到目标目录
   └─> 设置可执行权限（chmod +x）
```

## 📁 目录结构

### 源代码目录（当前）
```
server/
├── DocService/
│   ├── package.json
│   ├── sources/
│   └── docservice (打包后生成)
├── FileConverter/
│   ├── package.json
│   ├── sources/
│   └── converter (打包后生成)
├── Metrics/
│   ├── package.json
│   └── metrics (打包后生成)
└── rebuild_server.py
```

### 目标部署目录
```
e:/onlyoffice-server-build/
├── DocService/
│   └── docservice ✅ 会被替换
├── FileConverter/
│   ├── converter ✅ 会被替换
│   └── bin/ ⚠️  不会被修改（C++ 库）
│       ├── x2t
│       ├── libkernel.so
│       └── ...
├── Metrics/
│   └── metrics ✅ 会被替换
└── Common/
    └── config/ ⚠️  不会被修改
```

## ⚠️ 重要说明

### 1. 不会重新编译的部分

以下部分**不会被重新编译或替换**：

- ❌ `FileConverter/bin/` 下的 C++ 库（.so 文件）
- ❌ `FileConverter/bin/x2t` 转换工具
- ❌ `Common/config/` 配置文件
- ❌ `tools/` 工具集

如果您修改了 C++ 代码或需要更新这些部分，请使用完整的 build_tools 构建流程。

### 2. 只打包 Node.js 服务

这个脚本只重新打包 Node.js 服务的变更：
- ✅ DocService 的 JavaScript/TypeScript 代码
- ✅ FileConverter 的 Node.js 包装器
- ✅ Metrics 服务代码
- ✅ AdminPanel 后端代码

### 3. 配置文件不会被覆盖

打包过程不会修改配置文件，您的现有配置将保持不变。

## 🔄 部署后的操作

### 1. 重启服务

```bash
# 重启 DocService
sudo systemctl restart ds-docservice

# 重启 Converter
sudo systemctl restart ds-converter

# 重启 Metrics
sudo systemctl restart ds-metrics

# 或者一次性重启所有服务
sudo systemctl restart ds-*
```

### 2. 检查服务状态

```bash
# 查看服务状态
sudo systemctl status ds-docservice
sudo systemctl status ds-converter
sudo systemctl status ds-metrics

# 查看日志
sudo journalctl -u ds-docservice -f
sudo journalctl -u ds-converter -f
```

### 3. 验证服务

```bash
# 检查进程
ps aux | grep docservice
ps aux | grep converter
ps aux | grep metrics

# 检查端口（如果配置了）
netstat -tlnp | grep docservice
```

## 🐛 故障排除

### 问题 1: pkg 命令未找到

**错误信息**: `pkg: command not found`

**解决方案**:
```bash
npm install -g pkg
```

### 问题 2: 打包失败 - 内存不足

**错误信息**: `JavaScript heap out of memory`

**解决方案**:
DocService 已经配置了 `--options max_old_space_size=4096`，如果还是不够，可以增大这个值：

编辑 `rebuild_server.py`，修改 DocService 的配置：
```python
'docservice': {
    ...
    'pkg_args': ['--options', 'max_old_space_size=8192'],  # 改为 8GB
    ...
}
```

### 问题 3: 权限不足

**错误信息**: `Permission denied`

**解决方案**:
```bash
# 给脚本添加执行权限
chmod +x rebuild_server.py

# 如果目标目录需要 sudo 权限
sudo python rebuild_server.py --target-dir /var/www/onlyoffice/documentserver/server
```

### 问题 4: 打包后的文件无法运行

**可能原因**:
1. pkg 目标平台不匹配
2. 依赖未正确安装
3. 缺少原生模块

**解决方案**:
```bash
# 检查系统架构
uname -m  # 应该是 x86_64 或 aarch64

# 如果是 ARM 架构，修改 pkg 目标
python rebuild_server.py --pkg-target node20-linux-arm64

# 查看打包文件信息
file DocService/docservice

# 测试运行
cd DocService
./docservice --version  # 或直接运行查看错误
```

### 问题 5: 服务启动后立即退出

**检查步骤**:
```bash
# 1. 查看详细日志
sudo journalctl -u ds-docservice -n 100 --no-pager

# 2. 手动运行查看错误
cd /path/to/server/DocService
NODE_ENV=production-linux NODE_CONFIG_DIR=../Common/config ./docservice

# 3. 检查配置文件
ls -la ../Common/config/
cat ../Common/config/production-linux.json
```

## 💡 使用技巧

### 1. 快速迭代开发

```bash
# 修改代码后，快速打包部署 DocService
python rebuild_server.py --services docservice

# 重启服务
sudo systemctl restart ds-docservice

# 查看日志
sudo journalctl -u ds-docservice -f
```

### 2. 批量处理

```bash
# 打包所有服务但不部署，先检查
python rebuild_server.py --no-deploy --services all

# 确认无误后再部署
python rebuild_server.py --services all
```

### 3. 自动化部署脚本

创建一个简单的部署脚本 `deploy.sh`:

```bash
#!/bin/bash
set -e

echo "开始重新打包..."
python rebuild_server.py --services docservice converter

echo "重启服务..."
sudo systemctl restart ds-docservice ds-converter

echo "等待服务启动..."
sleep 5

echo "检查服务状态..."
sudo systemctl status ds-docservice --no-pager
sudo systemctl status ds-converter --no-pager

echo "部署完成！"
```

## 📊 性能对比

| 构建方式 | 时间 | 包含内容 | 适用场景 |
|---------|------|---------|---------|
| 完整构建（build_tools） | 30-60分钟 | C++ core + Node.js 服务 | 首次构建、core 变更 |
| 快速重打包（本脚本） | 1-3分钟 | 只打包 Node.js 服务 | 日常开发、代码迭代 |

## 📝 更多选项

查看所有可用选项：

```bash
python rebuild_server.py --help
```

输出：
```
usage: rebuild_server.py [-h] [--target-dir TARGET_DIR]
                         [--pkg-target PKG_TARGET]
                         [--services {docservice,converter,metrics,adminpanel,all} ...]
                         [--no-deploy] [--skip-pkg-check]

选项:
  -h, --help            显示帮助信息
  --target-dir          目标部署目录
  --pkg-target          pkg 打包目标（默认: node20-linux-x64）
  --services            要打包的服务列表
  --no-deploy           只打包不部署
  --skip-pkg-check      跳过 pkg 安装检查
```

## 🔗 相关文档

- [DocService 打包配置指南](../docs/development/docservice-packaging.md)
- [项目构建指南](../docs/development/build.md)
- [开发环境搭建](../docs/development/setup.md)

## ❓ 常见问题

**Q: 我可以在 Windows 上运行这个脚本吗？**

A: Python 脚本可以在 Windows 上运行，但需要安装 Python 3 和 Node.js。Bash 脚本需要 Git Bash 或 WSL。

**Q: 打包的文件可以在不同的 Linux 发行版上运行吗？**

A: 可以。pkg 打包的文件包含了 Node.js 运行时，理论上可以在任何 Linux x64 系统上运行。但可能需要安装一些系统库（glibc 等）。

**Q: 我需要重新打包所有服务吗？**

A: 不需要。只打包您修改过的服务即可。例如，如果只修改了 DocService，只需要 `--services docservice`。

**Q: 备份文件会一直保留吗？**

A: 是的。每次部署都会创建带时间戳的备份文件。建议定期清理旧的备份文件。

---

**祝您开发顺利！** 🎉

