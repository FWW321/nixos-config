#!/usr/bin/env bash
# filepath: ~/nixos-config/install.sh
# 一键安装/重装本仓库管理的 NixOS 主机(官方安装介质 root shell 下运行)
#
# 用法:
#   ./install.sh <主机名>                     # 全新安装(生成新 host key,需重加密 secrets)
#   ./install.sh <主机名> --host-key <file>   # 同机重装(复用旧 ssh_host_ed25519_key,secrets 免重加密)
#
# 环境要求:官方 NixOS 安装介质(root + nix + 有线网),本仓库已就位
# (git clone 或 U 盘拷贝;git 若缺失自动经 nix shell 提供)。
#
# 与旧版的关键差异(2026-08 重写):
#   - 硬件事实走 facter(.facter.json + redact),不再生成 hardware.nix(该文件已删)
#   - disko 用 flake.lock 内 pin 的版本(build diskoScript),不再拉 github:latest
#   - sops host key 契约显式化:secrets.yaml 加密给 host key 的 age 公钥,
#     新 key 必须重加密(否则装完无法登录),复用旧 key 则免
#   - 仓库拷贝含 dotfiles(.git/.sops.yaml/.facter.json 缺一则新机不可用)
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "❌ $*" >&2; exit 1; }

# ── 参数 ─────────────────────────────────────────────
HOSTNAME="" HOST_KEY_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host-key)
      [ $# -ge 2 ] || die "--host-key 需要路径参数"
      HOST_KEY_FILE=$2; shift 2 ;;
    -*) die "未知参数: $1" ;;
    *) HOSTNAME=$1; shift ;;
  esac
done
[ -n "$HOSTNAME" ] || die "未指定主机名。用法: ./install.sh <主机名> [--host-key <旧key>]"
[ -d "hosts/$HOSTNAME" ] || die "找不到 hosts/$HOSTNAME 配置目录"
[ "$(id -u)" = 0 ] || die "请以 root 运行(安装介质默认 root shell)"

# 安装介质可能没有 git;flake 纯净性要求新文件被 git 跟踪
GIT="git"
command -v git >/dev/null 2>&1 || GIT="nix shell nixpkgs#git -c git"

# ── 确认 destructive 操作 ────────────────────────────
echo "=========================================================="
echo "🚀 NixOS 一键安装 — 目标主机: $HOSTNAME"
echo "=========================================================="
echo "⚠️  disko 将格式化以下磁盘(disko.nix 声明,换机器需先改设备路径):"
grep -h 'device =' "hosts/$HOSTNAME/disko.nix" | sed 's/^/     /'
read -p "确认已备份数据并继续?(y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || die "已取消"

# ── [1/5] 硬件事实:facter 报告 + 脱敏 ─────────────────
# 任何 flake eval 都依赖 .facter.json,必须最先做
echo "[1/5] 🔍 生成硬件事实报告(facter)..."
nix run nixpkgs#nixos-facter -- -o "hosts/$HOSTNAME/.facter.json"
"hosts/$HOSTNAME/redact.sh"   # 公开仓库:序列号脱敏(幂等)
$GIT add "hosts/$HOSTNAME/.facter.json"

# ── [2/5] sops host key 契约 ──────────────────────────
# secrets.yaml 按 host key 的 age 公钥加密;key 不匹配 = 装完无法登录
echo "[2/5] 🔑 处理 SSH host key(sops 解密契约)..."
SOPS_HOST_LABEL=host_fww_desktop
OLD_AGE_PUB=$(sed -n "s/.*&${SOPS_HOST_LABEL} \(age1[a-z0-9]*\).*/\1/p" .sops.yaml)
[ -n "$OLD_AGE_PUB" ] || die ".sops.yaml 中找不到 &${SOPS_HOST_LABEL}"

if [ -n "$HOST_KEY_FILE" ]; then
  # 同机重装:复用备份的旧 key
  [ -f "$HOST_KEY_FILE" ] || die "--host-key 文件不存在: $HOST_KEY_FILE"
  NEW_AGE_PUB=$(ssh-keygen -y -f "$HOST_KEY_FILE" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
else
  NEW_AGE_PUB=""
fi

if [ -n "$NEW_AGE_PUB" ] && [ "$NEW_AGE_PUB" = "$OLD_AGE_PUB" ]; then
  echo "     旧 key 与 .sops.yaml 匹配,secrets 无需重加密 ✅"
elif [ -n "$NEW_AGE_PUB" ]; then
  die "旧 key 与 .sops.yaml 不匹配(该 key 非本仓库加密目标),请检查后重试"
fi
# NEW_AGE_PUB 为空(全新安装)→ 稍后生成新 key 并重加密,见 [4/5]

# ── [3/5] disko:声明式分区/格式化/挂载 ───────────────
echo "[3/5] 📦 disko 格式化与挂载(flake.lock 内 pin 版本)..."
nix build ".#nixosConfigurations.${HOSTNAME}.config.system.build.diskoScript" \
  --out-link /tmp/disko-install
/tmp/disko-install

# ── [4/5] host key 就位 + (必要时)重加密 secrets ─────
echo "[4/5] 🔐 host key 就位..."
KEY=/mnt/etc/ssh/ssh_host_ed25519_key
mkdir -p /mnt/etc/ssh
if [ -n "$HOST_KEY_FILE" ]; then
  install -m 600 "$HOST_KEY_FILE" "$KEY"
  ssh-keygen -y -f "$KEY" > "${KEY}.pub"
else
  # 全新安装:生成新 key;secrets.yaml 必须重加密给新 key
  ssh-keygen -t ed25519 -N "" -f "$KEY" -q
  NEW_AGE_PUB=$(ssh-keygen -y -f "$KEY" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
  if [ "${SOPS_AGE_KEY_FILE:-}" = "" ] && [ "${SOPS_AGE_KEY:-}" = "" ]; then
    die "全新安装需要 admin age 私钥重加密 secrets:
  1. 备份 U 盘放好 admin 私钥后重跑:
     SOPS_AGE_KEY_FILE=/path/to/admin.key ./install.sh $HOSTNAME
  2. 或改用同机重装路径(--host-key 复用旧 key)"
  fi
  sed -i "s|&${SOPS_HOST_LABEL} age1[a-z0-9]*|&${SOPS_HOST_LABEL} ${NEW_AGE_PUB}|" .sops.yaml
  nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml -y
  $GIT add .sops.yaml secrets/secrets.yaml
  echo "     secrets.yaml 已重加密给新 host key ✅(记得 commit)"
fi

# ── [5/5] 安装系统 + 仓库就位 ─────────────────────────
echo "[5/5] ⚙️  构建 NixOS(缓存列表与 modules/nixos/nix.nix 保持同步)..."
nixos-install --root /mnt --flake ".#${HOSTNAME}" --no-root-passwd \
  --option extra-substituters "https://attic.xuyh0120.win/lantian https://niri.cachix.org https://hyprland.cachix.org https://nix-community.cachix.org https://noctalia.cachix.org" \
  --option extra-trusted-public-keys "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc= niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="

DEST=/mnt/home/fww/nixos-config
mkdir -p "$DEST"
# dotglob:dotfiles 必须随行(.git/.sops.yaml/.facter.json/.github)
# 缺 .git 新机不可 rebuild;缺 .sops.yaml 不可编辑 secrets;缺 .facter.json flake 直接 eval 失败
shopt -s dotglob
cp -a ./* "$DEST"/
nixos-enter --root /mnt -c "chown -R fww:users /home/fww/nixos-config"

echo "=========================================================="
echo "✅ 安装完成!(主机: $HOSTNAME)"
echo "拔出安装介质,输入 reboot 进入全新系统。"
echo "首次登录密码:见 secrets/secrets.yaml 的 user_password(sops 解密)。"
echo "=========================================================="
