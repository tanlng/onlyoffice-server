#!/bin/bash
# Server 重新打包和部署脚本
# 用途：只重新打包修改后的 Node.js 服务，不重新编译 C++ core

set -e  # 遇到错误立即退出

# 配置
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="/path/to/onlyoffice-server-build-source"  # 修改为你的目标目录
PKG_TARGET="node20-linux-x64"

echo "=========================================="
echo "OnlyOffice Server 重新打包部署脚本"
echo "=========================================="
echo "源代码目录: $SOURCE_DIR"
echo "目标部署目录: $TARGET_DIR"
echo "=========================================="

# 检查 pkg 是否已安装
if ! command -v pkg &> /dev/null; then
    echo "错误: pkg 未安装，正在安装..."
    npm install -g pkg
fi

# 函数：打包服务
package_service() {
    local SERVICE_NAME=$1
    local SERVICE_DIR=$2
    local OUTPUT_NAME=$3
    local EXTRA_ARGS=$4
    
    echo ""
    echo "【$SERVICE_NAME】开始打包..."
    echo "----------------------------------------"
    
    cd "$SOURCE_DIR/$SERVICE_DIR"
    
    # 检查 package.json 是否存在
    if [ ! -f "package.json" ]; then
        echo "错误: $SERVICE_DIR/package.json 不存在"
        return 1
    fi
    
    # 打包
    echo "执行: pkg . -t $PKG_TARGET $EXTRA_ARGS -o $OUTPUT_NAME"
    pkg . -t "$PKG_TARGET" $EXTRA_ARGS -o "$OUTPUT_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✓ $SERVICE_NAME 打包成功: $OUTPUT_NAME"
        
        # 备份旧文件
        if [ -f "$TARGET_DIR/$SERVICE_DIR/$OUTPUT_NAME" ]; then
            echo "  备份旧文件..."
            cp "$TARGET_DIR/$SERVICE_DIR/$OUTPUT_NAME" "$TARGET_DIR/$SERVICE_DIR/${OUTPUT_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # 复制新文件
        echo "  部署新文件到: $TARGET_DIR/$SERVICE_DIR/$OUTPUT_NAME"
        cp "$OUTPUT_NAME" "$TARGET_DIR/$SERVICE_DIR/"
        chmod +x "$TARGET_DIR/$SERVICE_DIR/$OUTPUT_NAME"
        
        echo "✓ $SERVICE_NAME 部署完成"
    else
        echo "✗ $SERVICE_NAME 打包失败"
        return 1
    fi
}

# 主流程
main() {
    echo ""
    echo "开始打包和部署..."
    echo ""
    
    # 1. 打包 DocService
    package_service "DocService" "DocService" "docservice" "--options max_old_space_size=4096"
    
    # 2. 打包 FileConverter
    package_service "FileConverter" "FileConverter" "converter" ""
    
    # 3. 打包 Metrics
    package_service "Metrics" "Metrics" "metrics" ""
    
    # 4. 打包 AdminPanel (可选)
    # package_service "AdminPanel" "AdminPanel/server" "adminpanel" ""
    
    echo ""
    echo "=========================================="
    echo "✓ 所有服务打包部署完成！"
    echo "=========================================="
    echo ""
    echo "下一步操作："
    echo "1. 重启服务以使用新的可执行文件"
    echo "   systemctl restart ds-docservice"
    echo "   systemctl restart ds-converter"
    echo "   systemctl restart ds-metrics"
    echo ""
    echo "2. 查看服务状态"
    echo "   systemctl status ds-docservice"
    echo "   systemctl status ds-converter"
    echo "   systemctl status ds-metrics"
    echo ""
}

# 检查参数
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --target-dir PATH    指定目标部署目录 (默认: $TARGET_DIR)"
    echo "  --pkg-target TARGET  指定 pkg 打包目标 (默认: $PKG_TARGET)"
    echo "  --help, -h           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --target-dir /opt/onlyoffice/documentserver/server"
    echo ""
    exit 0
fi

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --target-dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        --pkg-target)
            PKG_TARGET="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 执行主流程
main

