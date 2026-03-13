# filepath: ~/nixos-config/install.sh
#!/usr/bin/env bash

# 遇到错误立即退出
set -e

# =========================================================================
# 1. 参数校验与环境准备
# =========================================================================
if [ -z "$1" ]; then
    echo "❌ 错误：未指定主机名。"
    echo "💡 用法：./install.sh <主机名称>"
    echo "🎯 示例：./install.sh FWW-Desktop"
    exit 1
fi

HOSTNAME=$1
PROJECT_ROOT=$(pwd)

if [ ! -d "$PROJECT_ROOT/hosts/$HOSTNAME" ]; then
    echo "❌ 错误：找不到该主机的配置目录 ($PROJECT_ROOT/hosts/$HOSTNAME)！"
    exit 1
fi

echo "=========================================================="
echo "🚀 开始一键安装 2026 现代化 NixOS"
echo "🖥️  目标主机: $HOSTNAME"
echo "=========================================================="
echo "⚠️ 警告：这将根据 hosts/$HOSTNAME/disko.nix 声明的规则清空并格式化硬盘！"
read -p "确认已备份数据并继续？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消安装。"
    exit 1
fi

# =========================================================================
# 2. 自动化部署流程
# =========================================================================

echo "[1/4] 📦 正在执行声明式磁盘格式化与挂载..."
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode disko --flake .#$HOSTNAME

echo "[2/4] 🔍 正在扫描主板与挂载点配置..."
nixos-generate-config --no-filesystems --root /mnt --dir /mnt/etc/nixos

# 覆盖掉我们项目中的占位硬件文件
cp /mnt/etc/nixos/hardware-configuration.nix "$PROJECT_ROOT/hosts/$HOSTNAME/hardware.nix"

# 强制 Git 追踪新文件，满足 Flake 的纯净性要求
git add "$PROJECT_ROOT/hosts/$HOSTNAME/hardware.nix"

echo "[3/4] ⚙️ 正在拉取 NixPkgs 并编译 NixOS 系统，这可能需要一些时间..."
nixos-install --root /mnt --flake .#$HOSTNAME --no-root-passwd \
  --option extra-substituters "https://niri.cachix.org" \
  --option extra-trusted-public-keys "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="

echo "[4/4] 📂 正在将当前配置工程部署到您的用户主目录..."
# 在新系统中创建 fww 用户的主目录配置文件夹
mkdir -p /mnt/home/fww/nixos-config
# 拷贝所有配置文件
cp -r "$PROJECT_ROOT/"* /mnt/home/fww/nixos-config/

# 【核心最佳实践】：利用 nixos-enter 进入新系统，将文件所有权移交给 fww 用户
echo "🔐 正在移交配置文件权限给 fww 用户..."
nixos-enter --root /mnt -c "chown -R fww:users /home/fww/nixos-config"

echo "=========================================================="
echo "✅ 安装圆满完成！(主机: $HOSTNAME)"
echo "请拔出安装U盘，输入 reboot 重启进入全新系统！"
echo ""
echo "✨ 您的系统配置已安放在 ~/nixos-config 目录下。"
echo "初次登录密码为：ww911811 (请登录后立刻用 passwd 命令修改)"
echo "=========================================================="
