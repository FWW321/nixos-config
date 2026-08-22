#!/usr/bin/env bash
# filepath: ~/nixos-config/install.sh
# NixOS 推送式装机编排 —— 在管理机(有 nix/git 与本仓库)上运行,经 nixos-anywhere 安装到目标机
#
# 分工(nixos-anywhere 1.13 源码验证的顺序契约):
#   机械半场归 nixos-anywhere:kexec/安装器接管 → facter 采集 → 本地构建
#   (=求值闸门,先于 disko)→ disko 分区格式化 → --extra-files 密钥落盘 →
#   nixos-install(substituters 自动取自本 flake 的 nix.settings)→ 重启
#   智慧半场归本脚本:向导(ssh 探测→意图决策→params.nix 物化)、sops host
#   key 契约(keygen→登记→updatekeys→烟测,全部动盘前)、收尾指引
#
# 用法:
#   ./install.sh <主机名> [root@目标]     # 新主机走向导;已有主机直接装
#   ./install.sh <主机名> --host-key <f>  # 同机重装:复用旧 host key(免 updatekeys)
#   ./install.sh --selftest               # CI 回归:物化+求值,不触任何机器
#
# 目标机准备(全新机):minimal ISO 控制台 → sudo passwd root
#   (sshd 默认已启用;ISO 自带 git,git clone 本仓库后即可本地运行本脚本)
# 已有 Linux:无需介质,kexec 自动接管(仅要求 root 可 ssh)。
# 单机自装:ISO 上起 sshd 后目标填 root@localhost(在目标自身运行系统中
# 对本机推送不可行 —— kexec 会掀翻运行中的脚本)。
# 仓库公开:新机装完 git clone 即得配置,不再随装拷贝。
#
# 主机注册表 = hosts/ 目录(flake.nix 自动发现,_ 前缀除外):
#   向导建完目录即注册完成,无需改任何 nix 文件
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "❌ $*" >&2; exit 1; }

# 物化 = 复制零 token 模板 + 写 params.nix(向导与 selftest 共用同一真源)。
# 正确性靠 Nix 类型系统:params 缺字段/错值名 → 构建闸门当场报错,
# 不存在"模板替换漏填"这一类 bug,故无需 token 残留检查
materialize_host() { # $1=主机名 $2=cpu_profile $3=gpu(nvidia|null) $4=nvidia_open
  #                   $5=nvidia_pkg $6=system_disk $7=home_disk $8=data_disk $9=swap_gib
  local h=$1
  mkdir -p "hosts/$h"
  cp hosts/_template/{default.nix,disko.nix,nvidia.nix,params.nix} "hosts/$h/"
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
# 配置文本,求值不触碰设备;夹具复用 FWW-Desktop 的 facter 报告(hardware.facter 必填)
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
HOSTNAME="" HOST_KEY_FILE="" TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host-key)
      [ $# -ge 2 ] || die "--host-key 需要路径参数"
      HOST_KEY_FILE=$2; shift 2 ;;
    -*) die "未知参数: $1" ;;
    *)
      if [ -z "$HOSTNAME" ]; then HOSTNAME=$1
      elif [ -z "$TARGET" ]; then TARGET=$1
      else die "多余参数: $1"; fi
      shift ;;
  esac
done
[ -n "$HOSTNAME" ] || die "未指定主机名。用法: ./install.sh <主机名> [root@目标] [--host-key <旧key>]"
# 主机名 = 目录名 + flake attr 名,限制字符集(防 sed/attr 两种上下文注入)
[[ "$HOSTNAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "主机名仅限字母数字与 _-(当前: $HOSTNAME)"
while [ -z "$TARGET" ]; do read -p "目标机 (root@ip / root@localhost): " TARGET; done
[[ "$TARGET" = *@* ]] || TARGET="root@$TARGET"   # ssh 裸地址默认用本机用户名,装机必须 root

# ── [1/4] 目标探测:单次 ssh 拿全部事实(只交互一次密码)──
# 引导模式守卫也在目标侧:本仓库引导栈(ESP + systemd-boot,见
# modules/nixos/boot.nix)仅 UEFI 可引导,BIOS-only 机器装完开不了机
PROBE=$(mktemp)
trap 'rm -f "$PROBE"' EXIT
# 内部无单引号:可整体单引号包裹,也可独立提取测试(bash -nc "$probe_script")
probe_script='[ -d /sys/firmware/efi ] && echo "uefi yes" || echo "uefi no"
grep -q AuthenticAMD /proc/cpuinfo 2>/dev/null && echo "cpu amd" || echo "cpu intel"
for d in /sys/bus/pci/devices/*; do
  if [ "$(cat "$d/vendor" 2>/dev/null)" = "0x10de" ]; then
    case "$(cat "$d/class" 2>/dev/null)" in
      0x03*) echo "gpu $(basename "$d"):$(cat "$d/device")" ;;
    esac
  fi
done
lsblk -nrpo NAME,TYPE,MOUNTPOINTS | sed "s/^/lsblk /"
lsblk -dnp -o PATH,SIZE,TYPE,MODEL | sed "s/^/disk /"
grep MemTotal /proc/meminfo | sed "s/^/mem /"'
echo "[1/4] 🔎 探测目标机 $TARGET..."
# shellcheck disable=SC2029  # 探测脚本有意在目标侧展开
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
  "$TARGET" "$probe_script" >"$PROBE" \
  || die "无法连接 $TARGET。全新机:ISO 控制台先 sudo passwd root(sshd 默认已启用)"

RAM_KIB=$(awk '/^mem /{print $3}' "$PROBE")
[ "$(awk '/^uefi /{print $2}' "$PROBE")" = yes ] \
  || die "目标机以 BIOS/Legacy 模式启动 —— 本仓库引导配置只支持 UEFI。
  若机器实为 UEFI:重启进固件设置,关闭 CSM/Legacy boot 后重试。
  确需 BIOS 引导:modules/nixos/boot.nix 换 GRUB + 模板 ESP 段去掉 type=EF00 后再来。"

# ── 向导:hosts/<name> 不存在 = 新主机(事实已探测,决策就地做)──
if [ ! -d "hosts/$HOSTNAME" ]; then
  echo "=========================================================="
  echo "🧙 hosts/$HOSTNAME 不存在 → 新主机向导"
  echo "=========================================================="
  read -p "为新机器创建配置并安装?(y/N) " -n 1 -r; echo
  [[ $REPLY =~ ^[Yy]$ ]] || die "已取消(要装已有主机,检查主机名拼写)"

  # CPU:AVX 等差异交给 nixos-hardware/nixpkgs,这里只选厂商 profile
  CPU_PROFILE=common-cpu-$(awk '/^cpu /{print $2}' "$PROBE")
  echo "  CPU → $CPU_PROFILE"

  # GPU(vendor 0x10de + class 03xx;不能看 DRIVER=nvidia —— 安装环境只有
  # nouveau,闭源驱动装完才有)。按 PCI device id 判代际:
  #   >= 0x1E00 = Turing+(GSP 存在,open 模块可用);更老 = Maxwell/Pascal/
  #   Volta(open 不兼容,闭源 + legacy_580 终点分支,nvidia support timeframes)
  GPU_KIND=null
  NVIDIA_OPEN=true
  NVIDIA_PACKAGE=latest
  GPU_LIST=""
  while read -r g; do
    [ -n "$g" ] || continue
    devid=$(( ${g##*:} ))
    if [ "$devid" -lt $((0x1E00)) ]; then
      NVIDIA_OPEN=false
      NVIDIA_PACKAGE=legacy_580
      echo "    $g < Turing(Maxwell/Pascal/Volta)→ 闭源模块 + legacy_580"
    else
      echo "    $g = Turing+ → open 模块 + latest"
    fi
    GPU_LIST="$GPU_LIST $g"
  done < <(awk '/^gpu /{print $2}' "$PROBE")
  if [ -n "$GPU_LIST" ]; then
    GPU_KIND="nvidia"
    echo "  GPU → NVIDIA(${GPU_LIST# })open=$NVIDIA_OPEN package=$NVIDIA_PACKAGE"
  else
    echo "  GPU → 非 NVIDIA(核显/AMD 免专项模块)"
  fi

  # 磁盘清单(人来做"哪块盘扮演什么角色"的意图决策)
  # 排除带挂载分区的盘:安装环境自身在其中 —— 选它等于锯断自己坐的树枝
  EXCLUDE_DISKS=$(awk '/^lsblk /{sub(/^lsblk /,""); print}' "$PROBE" \
    | awk '($2=="part" || $2=="disk") && $3!="" {d=$1; sub(/[0-9]+$/,"",d); print d}' | sort -u)
  mapfile -t DISKS < <(awk '/^disk /{sub(/^disk /,""); print}' "$PROBE" \
    | awk -v excl="$EXCLUDE_DISKS" 'BEGIN{n=split(excl,a,"\n"); for(i=1;i<=n;i++) skip[a[i]]=1}
        $3=="disk" && !($1 in skip)')
  [ "${#DISKS[@]}" -ge 1 ] || die "未检测到可用磁盘${EXCLUDE_DISKS:+(已排除带挂载分区的: $(echo $EXCLUDE_DISKS))}"
  if [ -n "$EXCLUDE_DISKS" ]; then
    echo "  (已排除带挂载分区的盘: $(echo "$EXCLUDE_DISKS" | tr '\n' ' '))"
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

  # swap 建议 = 内存大小向上取整(休眠需 ≥ RAM;读 MemTotal 免受 locale 影响)
  RAM_GIB=$(( (RAM_KIB + 1048575) / 1048576 ))
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
  git add "hosts/$HOSTNAME"
  echo "✅ hosts/$HOSTNAME 已生成并注册(hosts/ 目录即主机列表)"
  echo "   装机后的手动项(显示器/传感器/udev):见 hosts/$HOSTNAME/default.nix 内 TODO"
fi

# ── [2/4] 动盘前最终确认 ──────────────────────────────
# (求值闸门不在此处:nixos-anywhere 的本地构建阶段先于 disko,配置错在
#  动盘前失败;facter 采集同样由其在 kexec 后完成 —— 见 [4/4] 注释)
echo "=========================================================="
echo "🚀 NixOS 推送安装 — 主机: $HOSTNAME → $TARGET"
echo "=========================================================="
echo "⚠️  disko 阶段将格式化以下磁盘(disko.nix 声明,换机器需先改设备路径):"
grep -h 'device =' "hosts/$HOSTNAME/disko.nix" | sed 's/^/     /'
read -p "确认已备份数据并继续?(y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || die "已取消"

# ── [3/4] sops host key 契约(全部动盘前;密钥经 --extra-files 随装落地)──
# secrets.yaml 按 host key 的 age 公钥加密;key 不匹配 = 装完无法登录。
# key 生成/label 登记/重加密/解密烟测全部前置:任何 sops 失败都发生在
# 磁盘被格式化之前(YAML 被 sed 弄坏也在这里当场暴露,而非盘空之后)
# label 从主机名派生(FWW-Desktop → host_fww_desktop)
echo "[3/4] 🔑 sops host key 契约..."
SOPS_ADMIN_LABEL=admin_fww
SOPS_HOST_LABEL=host_$(echo "$HOSTNAME" | tr '[:upper:]-' '[:lower:]_')
OLD_AGE_PUB=$(sed -n "s/.*&${SOPS_HOST_LABEL} \(age1[a-z0-9]*\).*/\1/p" .sops.yaml)
# staging:--extra-files 的根,目录结构即目标机根文件系统的投影
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"; rm -f "$PROBE"' EXIT
mkdir -p "$STAGE/etc/ssh"
HOSTKEY="$STAGE/etc/ssh/ssh_host_ed25519_key"

if [ -n "$HOST_KEY_FILE" ]; then
  # 同机重装:复用备份的旧 key(必须与 .sops.yaml 登记值一致,当场验证)
  [ -f "$HOST_KEY_FILE" ] || die "--host-key 文件不存在: $HOST_KEY_FILE"
  [ -n "$OLD_AGE_PUB" ] || die "该主机 label 未登记过,不存在\"复用旧 key\"场景;去掉 --host-key 走全新安装"
  NEW_AGE_PUB=$(ssh-keygen -y -f "$HOST_KEY_FILE" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
  [ "$NEW_AGE_PUB" = "$OLD_AGE_PUB" ] \
    || die "旧 key 与 .sops.yaml 不匹配(该 key 非本仓库加密目标),请检查后重试"
  install -m 600 "$HOST_KEY_FILE" "$HOSTKEY"
  ssh-keygen -y -f "$HOSTKEY" >"${HOSTKEY}.pub"
  echo "     旧 key 与 .sops.yaml 匹配,secrets 无需重加密 ✅"
else
  # 全新安装(或重装换 key):生成新 key → 登记 label → 重加密
  ssh-keygen -t ed25519 -N "" -f "$HOSTKEY" -q   # mktemp 目录必空,无覆盖询问
  NEW_AGE_PUB=$(ssh-keygen -y -f "$HOSTKEY" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)
  if [ "${SOPS_AGE_KEY_FILE:-}" = "" ] && [ "${SOPS_AGE_KEY:-}" = "" ]; then
    die "全新安装需要 admin age 私钥重加密 secrets:
  备份 U 盘放好 admin 私钥后重跑:
     SOPS_AGE_KEY_FILE=/path/to/admin.key ./install.sh $HOSTNAME $TARGET
  或改用同机重装路径(--host-key 复用旧 key)"
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
  git add .sops.yaml secrets/secrets.yaml
  echo "     secrets.yaml 已重加密(host: ${SOPS_HOST_LABEL})✅"
fi

# 解密烟测:拿手头的 admin 私钥证明 user_password 路径可解(防 key/路径名漂移;
# --host-key 路径无 admin 私钥,但上方已证 key 与登记值一致,等价于可解)
if [ -n "${SOPS_AGE_KEY_FILE:-}${SOPS_AGE_KEY:-}" ]; then
  nix run nixpkgs#sops -- decrypt --extract '["user_password"]' secrets/secrets.yaml >/dev/null \
    && echo "     user_password 解密烟测通过 ✅" \
    || die "user_password 解密失败:检查 secrets.yaml 的路径名与 admin key"
fi

# ── [4/4] nixos-anywhere 推送安装 ─────────────────────
# 顺序契约(1.13 源码):kexec/安装器接管 → facter 采集写回本仓(--generate-
# hardware-config,自动 git add)→ 本地构建(配置错在此失败,盘未动)→
# disko → extra-files(host key 落 /mnt/etc/ssh,先于 nixos-install;chroot
# 激活时 sops 经它自解密,user_password 首启生效)→ nixos-install → 重启。
# 中断恢复:直接重跑本脚本(全程幂等:key 登记自动走换钥分支,disko 从头来)
echo "[4/4] 🚀 nixos-anywhere 推送安装..."
nix run nixpkgs#nixos-anywhere -- \
  --flake ".#$HOSTNAME" \
  --extra-files "$STAGE" \
  --generate-hardware-config nixos-facter "hosts/$HOSTNAME/.facter.json" \
  "$TARGET"

# nixos-anywhere 对 facter 只做 intent-to-add,正式入暂存区
git add "hosts/$HOSTNAME/.facter.json"
echo "=========================================================="
echo "✅ 安装完成!(主机: $HOSTNAME)"
echo "收尾清单:"
echo "  1. git commit(新 hosts/ 目录、.sops.yaml、secrets、facter 均已 staged)"
echo "  2. 新机取回配置:git clone git@github.com:FWW321/nixos-config.git"
echo "     (仓库公开,https 亦可;sops 的 ssh_key 已落在 ~/.ssh)"
echo "  3. 备份新机 /etc/ssh/ssh_host_ed25519_key —— 下次重装:"
echo "     ./install.sh $HOSTNAME --host-key <该文件> 即免 updatekeys"
echo "首次登录密码:secrets/secrets.yaml 的 user_password(sops 解密)。"
echo "=========================================================="
