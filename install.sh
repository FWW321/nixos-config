#!/usr/bin/env bash
# filepath: ~/nixos-config/install.sh
# 一键安装/重装/新机初始化本仓库管理的 NixOS(官方安装介质 root shell 下运行)
#
# 用法:
#   ./install.sh <已有主机名>                # 按既有配置安装/重装
#   ./install.sh <已有主机名> --host-key <f> # 同机重装,复用旧 host key(secrets 免重加密)
#   ./install.sh <新主机名>                  # 向导模式:探测硬件→引导填参→生成配置→安装
#   ./install.sh --selftest                  # CI/本地:夹具走一遍物化+求值,不动盘不交互
#
# 主机注册表 = hosts/ 目录(flake.nix 自动发现,_ 前缀除外):
#   向导建完目录即注册完成,无需改任何 nix 文件
#
# 环境要求:官方 NixOS 安装介质(root + nix + 有线网),本仓库已就位
# (git clone 或 U 盘拷贝;git 若缺失自动经 nix shell 提供)。
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "❌ $*" >&2; exit 1; }

# 物化 = 复制零 token 模板 + 写 params.nix(向导与 selftest 共用同一真源)。
# 正确性靠 Nix 类型系统:params 缺字段/错值名 → [2/6] 求值闸门当场报错,
# 不存在"模板替换漏填"这一类 bug,故无需 token 残留检查
materialize_host() { # $1=主机名 $2=cpu_profile $3=gpu(nvidia|null) $4=nvidia_open
  #                   $5=nvidia_pkg $6=system_disk $7=home_disk $8=data_disk $9=swap_gib
  local h=$1
  mkdir -p "hosts/$h"
  cp hosts/_template/{default.nix,disko.nix,nvidia.nix,params.nix,redact.sh} "hosts/$h/"
  cat >"hosts/$h/params.nix" <<EOF
# 由 install.sh 向导生成;手动调整后直接 nixos-rebuild 即可
{
  cpuProfile = "$2";
  gpu = ${3};
  nvidia = {
    open = ${4};
    package = ${5};
  };
  disks = {
    system = "${6}";
    home = ${7};
    data = ${8};
  };
  swapGiB = ${9};
}
EOF
}

# ── --selftest:CI 夹具回归(物化 3 种布局 → 完整求值 → 清理)──
# 覆盖:单盘+Turing N卡 / 三盘+legacy N卡 / 无独显 AMD;磁盘路径仅存在于
# 配置文本,求值不触碰设备;夹具用 FWW-Desktop 的脱敏 facter(hardware.facter 必填)
if [ "${1:-}" = "--selftest" ]; then
  ST_CLEAN="hosts/st-single-gpu hosts/st-multi-legacy hosts/st-nogpu"
  # shellcheck disable=SC2064  # ST_CLEAN 是固定字符串,定义时展开正是意图
  trap "git rm -rfq --ignore-unmatch $ST_CLEAN 2>/dev/null || rm -rf $ST_CLEAN" EXIT
  materialize_host st-single-gpu   common-cpu-intel '"nvidia"' true  '"latest"'     /dev/vda null     null     32
  materialize_host st-multi-legacy common-cpu-intel '"nvidia"' false '"legacy_580"' /dev/vda /dev/vdb /dev/vdc 64
  materialize_host st-nogpu        common-cpu-amd   null       true  '"latest"'     /dev/vda null     null     16
  for h in st-single-gpu st-multi-legacy st-nogpu; do
    cp hosts/FWW-Desktop/.facter.json "hosts/$h/.facter.json"
  done
  git add hosts/st-*
  for h in st-single-gpu st-multi-legacy st-nogpu; do
    echo "── selftest: 求值 $h ──"
    nix build --dry-run ".#nixosConfigurations.$h.config.system.build.toplevel" \
      || die "selftest: $h 求值失败"
  done
  echo "✅ selftest 通过:3 组夹具物化 + 完整求值"
  exit 0
fi

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
# 主机名 = 目录名 + flake attr 名,限制字符集(防 sed/attr 两种上下文注入)
[[ "$HOSTNAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "主机名仅限字母数字与 _-(当前: $HOSTNAME)"

# 引导模式守卫:本仓库引导栈(ESP 分区 + systemd-boot + efi.canTouchEfiVariables,
# 见 modules/nixos/boot.nix)仅 UEFI 机器可引导;BIOS-only(或 CSM 强制 legacy)机器
# 会装完无法开机。检测:UEFI 模式下内核暴露 /sys/firmware/efi
[ -d /sys/firmware/efi ] || die "当前以 BIOS/Legacy 模式启动 —— 本仓库引导配置只支持 UEFI。
  若机器实为 UEFI:重启进固件设置,关闭 CSM/Legacy boot 后重试。
  确需 BIOS 引导:modules/nixos/boot.nix 换 GRUB + 模板 ESP 段去掉 type=EF00 后再来。"

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

  # 探测 GPU(PCI vendor 0x10de + class 03xx;不能用 DRIVER=nvidia —— 安装介质
  # 只有 nouveau,闭源驱动装完才有)。同时按 PCI device id 判架构:
  #   >= 0x1E00 = Turing+(GSP 存在,open 模块可用);更老 = Maxwell/Pascal/Volta
  #   (open 不兼容,需闭源 + legacy_580 终点分支,nvidia README/support timeframes)
  GPU_KIND=null
  NVIDIA_OPEN=true
  NVIDIA_PACKAGE=latest
  GPU_LIST=""
  for d in /sys/bus/pci/devices/*; do
    if [ "$(cat "$d/vendor" 2>/dev/null)" = "0x10de" ] && [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]]; then
      devid=$(cat "$d/device"); devid=$((devid))
      GPU_LIST="$GPU_LIST $(basename "$d"):$(cat "$d/device")"
      if [ "$devid" -lt $((0x1E00)) ]; then
        NVIDIA_OPEN=false
        NVIDIA_PACKAGE=legacy_580
        echo "    $(basename "$d") device $(cat "$d/device") < Turing(Maxwell/Pascal/Volta)→ 闭源模块 + legacy_580"
      else
        echo "    $(basename "$d") device $(cat "$d/device") = Turing+ → open 模块 + latest"
      fi
    fi
  done
  if [ -n "$GPU_LIST" ]; then
    GPU_KIND="nvidia"
    echo "  GPU → NVIDIA(${GPU_LIST# })open=$NVIDIA_OPEN package=$NVIDIA_PACKAGE"
    command -v lspci >/dev/null && lspci -nn | grep -i 'vga\|3d' | sed 's/^/    /'
  else
    echo "  GPU → 非 NVIDIA(核显/AMD 免专项模块)"
  fi

  # 磁盘清单(人来做"哪块盘扮演什么角色"的意图决策)
  # 排除带挂载分区的盘:安装介质自身在其中 —— installer 的 nix store 就在
  # U 盘上,选它等于锯断自己坐的树枝
  EXCLUDE_DISKS=$(lsblk -nrpo NAME,TYPE,MOUNTPOINTS \
    | awk '($2=="part" || $2=="disk") && $3!="" {d=$1; sub(/[0-9]+$/,"",d); print d}' | sort -u)
  mapfile -t DISKS < <(lsblk -dnp -o PATH,SIZE,TYPE,MODEL \
    | awk -v excl="$EXCLUDE_DISKS" 'BEGIN{n=split(excl,a,"\n"); for(i=1;i<=n;i++) skip[a[i]]=1}
      $3=="disk" && !($1 in skip)')
  [ "${#DISKS[@]}" -ge 1 ] || die "未检测到可用磁盘${EXCLUDE_DISKS:+(已排除带挂载分区的: $(echo $EXCLUDE_DISKS))}"
  if [ -n "$EXCLUDE_DISKS" ]; then
    echo "  (已排除带挂载分区的盘: $(echo $EXCLUDE_DISKS | tr '\n' ' '))"
  fi
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
  # 角色互斥:同盘双角色 = disko 两条目同设备,第二次 mkfs 抹掉第一次的成果
  if [ "$HOME_DISK" != null ] || [ "$DATA_DISK" != null ]; then
    for d in "$HOME_DISK" "$DATA_DISK"; do
      if [ "$d" != null ] && [ "$d" = "$SYSTEM_DISK" ]; then
        die "$d 被选了两个角色 —— 多盘请选不同盘;单盘则多余角色直接回车(落回系统盘子卷)"
      fi
    done
    if [ "$HOME_DISK" != null ] && [ "$HOME_DISK" = "$DATA_DISK" ]; then
      die "home 盘与 data 盘不能是同一块"
    fi
  fi

  # swap 建议 = 内存大小(休眠需要 ≥ RAM)
  RAM_GIB=$(free -g | awk '/^Mem:/{print $2}')
  read -p "  swap 大小(GiB,默认 ${RAM_GIB}G=内存大小,休眠需≥RAM): " SWAP_GIB
  SWAP_GIB=${SWAP_GIB:-$RAM_GIB}
  [[ "$SWAP_GIB" =~ ^[0-9]+$ ]] || die "swap 大小无效: $SWAP_GIB"

  # 布局总览:物化前最后一眼(结构是仓库约定:btrfs+zstd、@root/@nix 子卷、
  # ESP 4G;可变参数全部来自上方选择)
  echo "  ─────────────────────────────────────"
  echo "  最终磁盘布局(仓库约定结构):"
  echo "    $SYSTEM_DISK → ESP 4G(/boot) + swap ${SWAP_GIB}G + btrfs(@root / @nix"
  if [ "$HOME_DISK" = null ]; then
    echo "                + @home 子卷)"
  else
    echo "    $HOME_DISK → btrfs @home(/home)"
  fi
  if [ "$DATA_DISK" = null ]; then
    [ "$HOME_DISK" != null ] && echo "                + @data 子卷)"
  else
    echo "    $DATA_DISK → btrfs @data(/data)"
  fi
  echo "  ─────────────────────────────────────"
  read -p "  按此布局创建并安装?(y/N) " -n 1 -r; echo
  [[ $REPLY =~ ^[Yy]$ ]] || die "已取消"

  # 物化:模板 → hosts/<name>/(共用函数,与 selftest 同一真源)
  # GPU_ARG/NVIDIA_PKG_ARG 是"Nix 字面量"形态:"nvidia" 与 null;
  # latest 写成 nix 字符串 "latest"(params.nix 中为 attr 名)
  if [ "$GPU_KIND" = nvidia ]; then GPU_ARG='"nvidia"'; else GPU_ARG=null; fi
  NVIDIA_PKG_ARG="\"$NVIDIA_PACKAGE\""
  materialize_host "$HOSTNAME" "$CPU_PROFILE" "$GPU_ARG" "$NVIDIA_OPEN" \
    "$NVIDIA_PKG_ARG" "$SYSTEM_DISK" "$HOME_DISK" "$DATA_DISK" "$SWAP_GIB"
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

# ── [1/6] 硬件事实:facter 报告 + 脱敏 ─────────────────
# 任何 flake eval 都依赖 .facter.json,必须最先做
echo "[1/6] 🔍 生成硬件事实报告(facter)..."
nix run nixpkgs#nixos-facter -- -o "hosts/$HOSTNAME/.facter.json"
"hosts/$HOSTNAME/redact.sh"   # 公开仓库:序列号脱敏(幂等)
$GIT add "hosts/$HOSTNAME/.facter.json"

# ── [2/6] 预检:动盘前完整求值 ─────────────────────────
# 配置的第一次完整求值发生在这里而非 nixos-install —— 模板参数错/模块
# 冲突/token 残留在格式化之前拦截(diskoScript 只求值到 disko 层,不够)
echo "[2/6] 🧪 预检:完整求值目标配置(动盘前最后一道闸)..."
if ! nix build --dry-run ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"; then
  die "配置求值失败 —— 磁盘尚未触碰,修好配置重跑即可"
fi

# ── [3/6] sops host key 契约(全部在动盘之前完成)──────
# secrets.yaml 按 host key 的 age 公钥加密;key 不匹配 = 装完无法登录。
# key 生成/label 登记/重加密/解密烟测全部前置:任何 sops 失败都发生在
# 磁盘被格式化之前(YAML 被 sed 弄坏也在这里当场暴露,而非盘空之后)
# label 从主机名派生(FWW-Desktop → host_fww_desktop)
echo "[3/6] 🔑 sops host key 契约..."
SOPS_ADMIN_LABEL=admin_fww
SOPS_HOST_LABEL=host_$(echo "$HOSTNAME" | tr '[:upper:]-' '[:lower:]_')
OLD_AGE_PUB=$(sed -n "s/.*&${SOPS_HOST_LABEL} \(age1[a-z0-9]*\).*/\1/p" .sops.yaml)
TMPKEY=/tmp/install-host-key

if [ -n "$HOST_KEY_FILE" ]; then
  # 同机重装:复用备份的旧 key(必须与 .sops.yaml 登记值一致,当场验证)
  [ -f "$HOST_KEY_FILE" ] || die "--host-key 文件不存在: $HOST_KEY_FILE"
  [ -n "$OLD_AGE_PUB" ] || die "该主机 label 未登记过,不存在\"复用旧 key\"场景;去掉 --host-key 走全新安装"
  NEW_AGE_PUB=$(ssh-keygen -y -f "$HOST_KEY_FILE" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
  [ "$NEW_AGE_PUB" = "$OLD_AGE_PUB" ] \
    || die "旧 key 与 .sops.yaml 不匹配(该 key 非本仓库加密目标),请检查后重试"
  echo "     旧 key 与 .sops.yaml 匹配,secrets 无需重加密 ✅"
else
  # 全新安装(或重装换 key):生成新 key → 登记 label → 重加密
  rm -f "$TMPKEY"   # 部分失败重跑时避免 ssh-keygen 交互式询问覆盖
  ssh-keygen -t ed25519 -N "" -f "$TMPKEY" -q
  NEW_AGE_PUB=$(ssh-keygen -y -f "$TMPKEY" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
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
  # updatekeys 会完整解析 .sops.yaml —— 上方 sed 的任何损坏在此当场失败(仍动盘前)
  nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml -y
  $GIT add .sops.yaml secrets/secrets.yaml
  echo "     secrets.yaml 已重加密(host: ${SOPS_HOST_LABEL})✅(记得 commit)"
fi

# 解密烟测:拿手头的 admin 私钥证明 user_password 路径可解(防 key/路径名漂移;
# --host-key 路径无 admin 私钥,但上方已证 key 与登记值一致,等价于可解)
if [ -n "${SOPS_AGE_KEY_FILE:-}${SOPS_AGE_KEY:-}" ]; then
  nix run nixpkgs#sops -- decrypt --extract '["user_password"]' secrets/secrets.yaml >/dev/null \
    && echo "     user_password 解密烟测通过 ✅" \
    || die "user_password 解密失败:检查 secrets.yaml 的路径名与 admin key"
fi

# ── [4/6] disko:声明式分区/格式化/挂载 ───────────────
# 到这里为止的一切失败都不留痕迹(除 repo 内新文件);从这里起磁盘被改写
echo "[4/6] 📦 disko 格式化与挂载(flake.lock 内 pin 版本)..."
nix build ".#nixosConfigurations.${HOSTNAME}.config.system.build.diskoScript" \
  --out-link /tmp/disko-install
/tmp/disko-install

# ── [5/6] host key 就位(此刻 /mnt 才可写)─────────────
echo "[5/6] 📝 host key 写入目标系统..."
KEY=/mnt/etc/ssh/ssh_host_ed25519_key
mkdir -p /mnt/etc/ssh
if [ -n "$HOST_KEY_FILE" ]; then
  install -m 600 "$HOST_KEY_FILE" "$KEY"
else
  install -m 600 "$TMPKEY" "$KEY"
fi
ssh-keygen -y -f "$KEY" > "${KEY}.pub"

# ── [6/6] 安装系统 + 仓库就位 ─────────────────────────
# 缓存源经 nix eval 取自本机配置(nix.nix 单一真源,消除双份手工同步)
echo "[6/6] ⚙️  构建 NixOS..."
SUBSTITUTERS=$(nix eval --raw ".#nixosConfigurations.${HOSTNAME}.config.nix.settings.substituters" \
  --apply 'builtins.concatStringsSep " "')
TRUSTED_KEYS=$(nix eval --raw ".#nixosConfigurations.${HOSTNAME}.config.nix.settings.trusted-public-keys" \
  --apply 'builtins.concatStringsSep " "')
nixos-install --root /mnt --flake ".#${HOSTNAME}" --no-root-passwd \
  --option substituters "$SUBSTITUTERS" --option trusted-public-keys "$TRUSTED_KEYS"

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
