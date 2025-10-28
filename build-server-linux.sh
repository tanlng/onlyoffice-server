#!/bin/bash
# OnlyOffice DocumentServer - Server 打包脚本（Linux）
# 用途：将 server 目录打包成独立可执行文件

set -e

echo "==========================================="
echo "  OnlyOffice Server 打包工具 (Linux)"
echo "==========================================="
echo ""

# 配置
TARGET="node18-linux-x64"  # Linux x64
OUTPUT_DIR="./build/server"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# 创建输出目录
echo "[1/6] 创建输出目录..."
mkdir -p "$OUTPUT_DIR/Common/config/log4js"
mkdir -p "$OUTPUT_DIR/DocService"
mkdir -p "$OUTPUT_DIR/FileConverter"
mkdir -p "$OUTPUT_DIR/Metrics"

# 检查并安装 pkg
echo "[2/6] 检查 pkg 工具..."
if ! command -v pkg &> /dev/null; then
    echo "   安装 pkg..."
    npm install -g pkg
fi

# 打包 DocService
echo "[3/6] 打包 DocService..."
cd DocService
pkg ./package.json \
    --targets $TARGET \
    --output "../$OUTPUT_DIR/DocService/docservice" \
    --options "max-old-space-size=4096"
cd ..

# 打包 FileConverter
echo "[4/6] 打包 FileConverter..."
cd FileConverter
pkg ./package.json \
    --targets $TARGET \
    --output "../$OUTPUT_DIR/FileConverter/converter" \
    --options "max-old-space-size=4096"
cd ..

# 打包 Metrics
echo "[5/6] 打包 Metrics..."
cd Metrics
pkg ./package.json \
    --targets $TARGET \
    --output "../$OUTPUT_DIR/Metrics/metrics" \
    --options "max-old-space-size=4096"
cd ..

# 复制配置文件
echo "[6/6] 复制配置文件..."
cp -r Common/config/*.json "$OUTPUT_DIR/Common/config/"
cp -r Common/config/log4js/*.json "$OUTPUT_DIR/Common/config/log4js/"

# 复制数据库脚本
echo "   复制数据库脚本..."
cp -r schema "$OUTPUT_DIR/"

# 设置可执行权限
chmod +x "$OUTPUT_DIR/DocService/docservice"
chmod +x "$OUTPUT_DIR/FileConverter/converter"
chmod +x "$OUTPUT_DIR/Metrics/metrics"

# 生成版本信息
cat > "$OUTPUT_DIR/BUILD_INFO.txt" << EOF
OnlyOffice DocumentServer - Server Build
========================================
Build Time: $TIMESTAMP
Target: $TARGET
Modified: storage-s3.js (externalHost support)

Executables:
- DocService/docservice
- FileConverter/converter  
- Metrics/metrics

Config:
- Common/config/*.json
EOF

echo ""
echo "==========================================="
echo "  打包完成！"
echo "==========================================="
echo ""
echo "输出目录: $OUTPUT_DIR"
echo ""
echo "提示："
echo "  1. 可执行文件已生成，但还需要 core 组件（C++ 二进制文件）"
echo "  2. 从已编译的版本复制 .so 文件和 x2t 等工具"
echo "  3. 配置文件在 Common/config/ 目录"
echo ""

