#!/usr/bin/env bash
# filepath: ~/nixos-config/install.sh
# 一键安装/重装/新机初始化本仓库管理的 NixOS(官方安装介质 root shell 下运行)
#
# 用法:
#   ./install.sh <已有主机名>                # 按既有配置安装/重装
#   ./install.sh <已有主机名> --host-key <f> # 同机重装,复用旧 host key(secrets 免重加密)
#   ./install.sh <新主机名>                  # 向导模式:探测硬件→引导填参→生成配置→安装
#
# 主机注册表 = hosts/ 目录(flake.nix 自动发现,_ 前缀除外):
#   向导建完目录即注册完成,无需改任何 nix 文件
#
# 环境要求:官方 NixOS 安装介质(root + nix + 有线网),本仓库已就位
# (git clone 或 U 盘拷贝;git 若缺失自动经 nix shell 提供)。
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
[ "$(id -u)" = 0 ] || die "请以 root 运行(安装介质默认 root shell)"

# 安装介质可能没有 git;flake 纯净性要求新文件被 git 跟踪
GIT="git"
command -v git >/dev/null 2>&1 || GIT="nix shell nixpkgs#git -c git"

# ── 向导模式:hosts/<name> 不存在 = 新主机 ─────────────
if [ ! -d "hosts/$HOSTNAME" ]; then
  echo "=========================================================="
  echo "🧙 hosts/$HOSTNAME 不存在 → 新主机向导"
  echo "=========================================================="
  read -p "为新机器创建配置并安装?(y/N) " -n 1 -r; echo
  [[ $REPLY =~ ^[Yy]$ ]] || die "已取消(要装已有主机,检查主机名拼写)"

  # 探测 CPU(AVX 等差异交给 nixos-hardware/nixpkgs,这里只选厂商 profile)
  if grep -q AuthenticAMD /proc/cpuinfo; then CPU_PROFILE=common-cpu-amd
  else CPU_PROFILE=common-cpu-intel; fi
  echo "  CPU → $CPU_PROFILE"

  # 探测 GPU(NVIDIA 自动挂模块;AMD/Intel 核显免专项模块,留给 TODO)
  GPU_IMPORT="# ./nvidia.nix  # 未检测到 NVIDIA(AMD/Intel 核显无需专项模块)"
  for uevent in /sys/class/drm/card*/device/uevent; do
    if grep -q '^DRIVER=nvidia$' "$uevent" 2>/dev/null; then
      GPU_IMPORT="./nvidia.nix"; break
    fi
  done
  echo "  GPU → ${GPU_IMPORT%%#*}"

  # 磁盘清单(人来做"哪块盘扮演什么角色"的意图决策)
  echo "  检测到以下磁盘:"
  mapfile -t DISKS < <(lsblk -dnp -o PATH,SIZE,TYPE,MODEL | awk '$3=="disk"')
  [ "${#DISKS[@]}" -ge 1 ] || die "未检测到磁盘"
  for i in "${!DISKS[@]}"; do echo "    [$i] ${DISKS[$i]}"; done

  pick_disk() { # $1=用途 $2=是否必填
    local idx
    while :; do
      read -p "  $1 用哪块盘?(序号$([ "$2" = req ] && echo '' || echo ',回车=不单独分盘')) " idx
      [ -z "$idx" ] && [ "$2" != req ] && { echo null; return; }
      [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#DISKS[@]}" ] \
        && { echo "${DISKS[$idx]%% *}"; return; }
      echo "    无效序号,重输" >&2
    done
  }
  SYSTEM_DISK=$(pick_disk "系统盘(将被格式化!)" req)
  HOME_DISK=$(pick_disk "home 盘" opt)
  DATA_DISK=$(pick_disk "data 盘" opt)
  echo "  系统盘=$SYSTEM_DISK home=${HOME_DISK:-子卷} data=${DATA_DISK:-子卷}"

  # swap 建议 = 内存大小(休眠需要 ≥ RAM)
  RAM_GIB=$(free -g | awk '/^Mem:/{print $2}')
  read -p "  swap 大小(GiB,默认 ${RAM_GIB}G=内存大小,休眠需≥RAM): " SWAP_GIB
  SWAP_GIB=${SWAP_GIB:-$RAM_GIB}
  [[ "$SWAP_GIB" =~ ^[0-9]+$ ]] || die "swap 大小无效: $SWAP_GIB"

  # 物化:模板 → hosts/<name>/
  mkdir -p "hosts/$HOSTNAME"
  cp hosts/_template/{default.nix,disko.nix,redact.sh} "hosts/$HOSTNAME/"
  [ "$GPU_IMPORT" = "./nvidia.nix" ] && cp hosts/_template/nvidia.nix "hosts/$HOSTNAME/"
  sed -i "s|{{HOSTNAME}}|$HOSTNAME|g; s|{{CPU_PROFILE}}|$CPU_PROFILE|g; s|{{GPU_IMPORT}}|$GPU_IMPORT|g" \
    "hosts/$HOSTNAME/default.nix"
  sed -i "s|{{SYSTEM_DISK}}|$SYSTEM_DISK|g; s|{{HOME_DISK}}|$HOME_DISK|g; s|{{DATA_DISK}}|$DATA_DISK|g; s|{{SWAP_GIB}}|$SWAP_GIB|g" \
    "hosts/$HOSTNAME/disko.nix"
  $GIT add "hosts/$HOSTNAME"
  echo "✅ hosts/$HOSTNAME 已生成并注册(hosts/ 目录即主机列表)"
  echo "   装机后的手动项(显示器/传感器/udev):见 hosts/$HOSTNAME/default.nix 内 TODO"
fi

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
# label 从主机名派生(FWW-Desktop → host_fww_desktop);新主机 label 尚未
# 登记是合法状态,由 [4/5] 生成 key 后写入
echo "[2/5] 🔑 处理 SSH host key(sops 解密契约)..."
SOPS_ADMIN_LABEL=admin_fww
SOPS_HOST_LABEL=host_$(echo "$HOSTNAME" | tr '[:upper:]-' '[:lower:]_')
OLD_AGE_PUB=$(sed -n "s/.*&${SOPS_HOST_LABEL} \(age1[a-z0-9]*\).*/\1/p" .sops.yaml)
if [ -z "$OLD_AGE_PUB" ]; then
  echo "     .sops.yaml 中无 ${SOPS_HOST_LABEL}(新主机),key 生成后登记 → [4/5]"
fi

if [ -n "$HOST_KEY_FILE" ]; then
  # 同机重装:复用备份的旧 key
  [ -f "$HOST_KEY_FILE" ] || die "--host-key 文件不存在: $HOST_KEY_FILE"
  [ -n "$OLD_AGE_PUB" ] || die "该主机 label 未登记过,不存在\"复用旧 key\"场景;去掉 --host-key 走全新安装"
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
  # 全新安装(或 label 需重登记):生成新 key;secrets.yaml 重加密给新 key
  ssh-keygen -t ed25519 -N "" -f "$KEY" -q
  NEW_AGE_PUB=$(ssh-keygen -y -f "$KEY" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
  if [ "${SOPS_AGE_KEY_FILE:-}" = "" ] && [ "${SOPS_AGE_KEY:-}" = "" ]; then
    die "全新安装需要 admin age 私钥重加密 secrets:
  1. 备份 U 盘放好 admin 私钥后重跑:
     SOPS_AGE_KEY_FILE=/path/to/admin.key ./install.sh $HOSTNAME
  2. 或改用同机重装路径(--host-key 复用旧 key)"
  fi
  if [ -n "$OLD_AGE_PUB" ]; then
    # label 已存在(重装):换公钥值
    sed -i "s|&${SOPS_HOST_LABEL} age1[a-z0-9]*|\\&${SOPS_HOST_LABEL} ${NEW_AGE_PUB}|" .sops.yaml
  else
    # 新主机:登记 label(keys 段 + key_groups 引用;YAML 列表顺序无关)
    sed -i "/^keys:/a\\  - \&${SOPS_HOST_LABEL} ${NEW_AGE_PUB}" .sops.yaml
    sed -i "/- \*${SOPS_ADMIN_LABEL}/a\\          - \*${SOPS_HOST_LABEL}" .sops.yaml
  fi
  nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml -y
  $GIT add .sops.yaml secrets/secrets.yaml
  echo "     secrets.yaml 已重加密(host: ${SOPS_HOST_LABEL})✅(记得 commit)"
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
