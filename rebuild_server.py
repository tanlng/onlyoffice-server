#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OnlyOffice Server 重新打包和部署脚本
用途：只重新打包修改后的 Node.js 服务，不重新编译 C++ core
"""

import os
import sys
import shutil
import subprocess
import argparse
from datetime import datetime
import platform

# 配置
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# 根据操作系统自动选择 pkg 目标
def get_default_pkg_target():
    """根据当前系统自动选择 pkg 目标"""
    system = platform.system().lower()
    machine = platform.machine().lower()
    
    if system == 'linux':
        if 'aarch64' in machine or 'arm64' in machine:
            return "node20-linux-arm64"
        else:
            return "node20-linux-x64"
    elif system == 'windows':
        return "node20-win-x64"
    elif system == 'darwin':  # macOS
        if 'arm64' in machine:
            return "node20-macos-arm64"
        else:
            return "node20-macos-x64"
    else:
        return "node20-linux-x64"  # 默认

PKG_TARGET = get_default_pkg_target()

# 服务配置
SERVICES = {
    'docservice': {
        'dir': 'DocService',
        'output': 'docservice',
        'target_subdir': 'DocService',
        'pkg_args': ['--options', 'max_old_space_size=4096'],
        'description': '文档服务 (核心协同编辑)'
    },
    'converter': {
        'dir': 'FileConverter',
        'output': 'converter',
        'target_subdir': 'FileConverter',
        'pkg_args': [],
        'description': '转换服务 (文档格式转换)'
    },
    'metrics': {
        'dir': 'Metrics',
        'output': 'metrics',
        'target_subdir': 'Metrics',
        'pkg_args': [],
        'description': '监控服务'
    },
    'adminpanel': {
        'dir': 'AdminPanel/server',
        'output': 'adminpanel',
        'target_subdir': 'AdminPanel/server',
        'pkg_args': [],
        'description': '管理面板服务'
    }
}


def log_info(msg):
    """打印信息"""
    print(f"[INFO] {msg}")


def log_success(msg):
    """打印成功信息"""
    print(f"[\033[92m✓\033[0m] {msg}")


def log_error(msg):
    """打印错误信息"""
    print(f"[\033[91m✗\033[0m] {msg}", file=sys.stderr)


def log_warning(msg):
    """打印警告信息"""
    print(f"[\033[93m⚠\033[0m] {msg}")


def run_command(cmd, cwd=None, shell=False):
    """执行命令"""
    try:
        # 在 Windows 上，如果使用 npx 等命令，需要设置 shell=True
        if platform.system().lower() == 'windows' and isinstance(cmd, list) and len(cmd) > 0:
            # 检查是否是 npx 或 npm 命令
            if cmd[0] in ['npx', 'npm', 'node']:
                shell = True
        
        log_info(f"执行命令: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
        result = subprocess.run(
            cmd,
            cwd=cwd,
            shell=shell,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        log_error(f"命令执行失败: {e.stderr}")
        return False, e.stderr


def check_pkg_installed():
    """检查 pkg 是否已安装"""
    log_info("检查 pkg 是否已安装...")
    
    # 在 Windows 上使用 npx 或 pkg.cmd
    if platform.system().lower() == 'windows':
        # 检查 pkg.cmd 是否存在
        pkg_cmd = shutil.which('pkg.cmd')
        if pkg_cmd is None:
            log_warning("pkg 未安装，正在安装...")
            success, _ = run_command(['npm', 'install', '-g', 'pkg'])
            if not success:
                log_error("pkg 安装失败，请手动安装: npm install -g pkg")
                return False
            log_success("pkg 安装成功")
        else:
            log_success(f"pkg 已安装: {pkg_cmd}")
    else:
        # Linux/macOS 使用 which
        pkg_path = shutil.which('pkg')
        if pkg_path is None:
            log_warning("pkg 未安装，正在安装...")
            success, _ = run_command(['npm', 'install', '-g', 'pkg'])
            if not success:
                log_error("pkg 安装失败，请手动安装: npm install -g pkg")
                return False
            log_success("pkg 安装成功")
        else:
            log_success(f"pkg 已安装: {pkg_path}")
    
    return True


def install_dependencies(service_dir):
    """安装服务依赖"""
    package_json = os.path.join(SCRIPT_DIR, service_dir, 'package.json')
    if not os.path.exists(package_json):
        log_warning(f"未找到 package.json: {service_dir}")
        return True
    
    node_modules = os.path.join(SCRIPT_DIR, service_dir, 'node_modules')
    if os.path.exists(node_modules):
        log_info(f"{service_dir} 依赖已存在，跳过安装")
        return True
    
    log_info(f"安装 {service_dir} 依赖...")
    success, _ = run_command(['npm', 'ci'], cwd=os.path.join(SCRIPT_DIR, service_dir))
    return success


def package_service(service_name, service_config, pkg_target, output_base_dir=None):
    """打包服务"""
    log_info(f"开始打包 {service_name} - {service_config['description']}")
    print("=" * 60)
    
    service_dir = os.path.join(SCRIPT_DIR, service_config['dir'])
    output_name = service_config['output']
    
    # 检查源目录
    if not os.path.exists(service_dir):
        log_error(f"服务目录不存在: {service_dir}")
        return False, None
    
    # 检查 package.json
    package_json = os.path.join(service_dir, 'package.json')
    if not os.path.exists(package_json):
        log_error(f"未找到 package.json: {service_dir}")
        return False, None
    
    # 安装依赖（如果需要）
    if not install_dependencies(service_config['dir']):
        log_error(f"依赖安装失败: {service_name}")
        return False, None
    
    # 确定输出路径
    if output_base_dir:
        # 直接输出到目标目录
        output_subdir = os.path.join(output_base_dir, service_config['target_subdir'])
        if not os.path.exists(output_subdir):
            log_error(f"输出目录不存在: {output_subdir}")
            return False, None
        output_file = os.path.join(output_subdir, output_name)
    else:
        # 输出到源目录
        output_file = os.path.join(service_dir, output_name)
    
    # 构建 pkg 命令
    # 在 Windows 上查找 pkg.cmd 或使用 npx
    if platform.system().lower() == 'windows':
        # 查找 pkg.cmd
        pkg_cmd = shutil.which('pkg.cmd')
        if pkg_cmd:
            cmd = ['pkg.cmd', '.', '-t', pkg_target] + service_config['pkg_args'] + ['-o', output_file]
        else:
            # 如果没有 pkg.cmd，使用 npx pkg
            cmd = ['npx', 'pkg', '.', '-t', pkg_target] + service_config['pkg_args'] + ['-o', output_file]
    else:
        cmd = ['pkg', '.', '-t', pkg_target] + service_config['pkg_args'] + ['-o', output_file]
    
    log_info(f"输出路径: {output_file}")
    
    # 执行打包
    success, output = run_command(cmd, cwd=service_dir)
    
    if success:
        if os.path.exists(output_file):
            file_size = os.path.getsize(output_file) / (1024 * 1024)  # MB
            log_success(f"{service_name} 打包成功: {output_file} ({file_size:.2f} MB)")
            return True, output_file
        else:
            log_error(f"打包文件未生成: {output_file}")
            return False, None
    else:
        log_error(f"{service_name} 打包失败")
        return False, None


def deploy_service(service_name, service_config, source_file, target_dir):
    """部署服务"""
    log_info(f"部署 {service_name}...")
    
    target_subdir = os.path.join(target_dir, service_config['target_subdir'])
    target_file = os.path.join(target_subdir, service_config['output'])
    
    # 检查目标目录
    if not os.path.exists(target_subdir):
        log_error(f"目标目录不存在: {target_subdir}")
        return False
    
    # 备份旧文件
    if os.path.exists(target_file):
        backup_name = f"{target_file}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        log_info(f"备份旧文件: {os.path.basename(backup_name)}")
        shutil.copy2(target_file, backup_name)
    
    # 复制新文件
    log_info(f"复制新文件到: {target_file}")
    shutil.copy2(source_file, target_file)
    
    # 设置执行权限
    os.chmod(target_file, 0o755)
    
    log_success(f"{service_name} 部署完成")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='OnlyOffice Server 重新打包和部署工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  # 打包并部署所有服务
  python rebuild_server.py --target-dir /path/to/server

  # 只打包 DocService
  python rebuild_server.py --target-dir /path/to/server --services docservice

  # 只打包不部署
  python rebuild_server.py --no-deploy

  # 打包 DocService 和 Converter
  python rebuild_server.py --target-dir /path/to/server --services docservice converter
        '''
    )
    
    parser.add_argument(
        '--target-dir',
        type=str,
        default='E:/onlyoffice-server-build',
        help='目标部署目录 (默认: E:/onlyoffice-server-build)'
    )
    
    parser.add_argument(
        '--pkg-target',
        type=str,
        default='node20-linux-x64',  # 默认打包为 Linux 格式（在 Windows 上跨平台打包）
        help=f'pkg 打包目标 (默认: node20-linux-x64，自动检测系统: {PKG_TARGET})'
    )
    
    parser.add_argument(
        '--services',
        nargs='+',
        choices=list(SERVICES.keys()) + ['all'],
        default=['docservice', 'converter', 'metrics'],
        help='要打包的服务 (默认: docservice converter metrics)'
    )
    
    parser.add_argument(
        '--output-to-source',
        action='store_true',
        help='输出到源目录而不是目标目录（打包后需要手动复制）'
    )
    
    parser.add_argument(
        '--skip-pkg-check',
        action='store_true',
        help='跳过 pkg 安装检查'
    )
    
    args = parser.parse_args()
    
    # 打印配置
    print("\n" + "=" * 60)
    print("OnlyOffice Server 重新打包和部署工具")
    print("=" * 60)
    print(f"当前系统: {platform.system()} {platform.machine()}")
    print(f"源代码目录: {SCRIPT_DIR}")
    print(f"输出目录: {args.target_dir if not args.output_to_source else '源目录'}")
    print(f"pkg 目标: {args.pkg_target}")
    print(f"要打包的服务: {', '.join(args.services)}")
    print("=" * 60)
    
    # 跨平台打包警告
    current_system = platform.system().lower()
    target_system = 'linux' if 'linux' in args.pkg_target else \
                   'windows' if 'win' in args.pkg_target else \
                   'macos' if 'macos' in args.pkg_target else 'unknown'
    
    if current_system == 'windows' and target_system == 'linux':
        log_warning("⚠️  注意：您正在 Windows 上打包 Linux 可执行文件")
        log_info("这是正常的，但请确保目标部署环境是 Linux 系统")
    elif current_system == 'linux' and target_system == 'windows':
        log_warning("⚠️  注意：您正在 Linux 上打包 Windows 可执行文件")
    
    print()
    
    # 检查 pkg
    if not args.skip_pkg_check and not check_pkg_installed():
        return 1
    
    # 确定要打包的服务
    services_to_build = args.services
    if 'all' in services_to_build:
        services_to_build = list(SERVICES.keys())
    
    # 确定输出目录
    output_dir = None if args.output_to_source else args.target_dir
    
    # 打包服务
    built_services = {}
    failed_services = []
    
    for service_name in services_to_build:
        if service_name not in SERVICES:
            log_warning(f"未知服务: {service_name}，跳过")
            continue
        
        print()
        success, output_file = package_service(
            service_name,
            SERVICES[service_name],
            args.pkg_target,
            output_dir
        )
        
        if success:
            built_services[service_name] = output_file
        else:
            failed_services.append(service_name)
    
    # 打印总结
    print()
    print("=" * 60)
    print("总结")
    print("=" * 60)
    
    if built_services:
        print(f"✓ 成功打包 {len(built_services)} 个服务:")
        for service, output_file in built_services.items():
            file_size = os.path.getsize(output_file) / (1024 * 1024)
            print(f"  - {service}: {output_file} ({file_size:.2f} MB)")
    
    if failed_services:
        print(f"✗ 打包失败 {len(failed_services)} 个服务:")
        for service in failed_services:
            print(f"  - {service}")
    
    print("=" * 60)
    
    if built_services and not args.output_to_source:
        print()
        print("下一步操作:")
        print("1. 将文件上传到 Linux 服务器")
        print("2. 赋予执行权限:")
        for service in built_services.keys():
            print(f"   chmod +x {args.target_dir}/{SERVICES[service]['target_subdir']}/{service}")
        print()
        print("3. 重启服务:")
        for service in built_services.keys():
            print(f"   systemctl restart ds-{service}")
        print()
        print("4. 查看服务状态:")
        for service in built_services.keys():
            print(f"   systemctl status ds-{service}")
        print()
    
    # 返回状态码
    if failed_services:
        return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n操作已取消")
        sys.exit(1)
    except Exception as e:
        log_error(f"未预期的错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

