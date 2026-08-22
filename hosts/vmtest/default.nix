# filepath: ~/nixos-config/hosts/vmtest/
# VM 验证夹具主机 —— 运行(建议经 herdr pane,非交互产物走 xchg):
#   NIX_EFI_VARS=/tmp/vars.fd TMPDIR=/tmp/vmx /tmp/vm/bin/disko-vm
#   产物落 $TMPDIR/nix-vm.*/xchg/{hm.log,facter.json,failed.txt,state.txt,DONE}
#   (NIX_EFI_VARS 独立文件避免多实例锁竞争;vmtest-export 服务自动导出)
# 已验证(2026-08):disko 布局(diskoImages)在构建沙箱 QEMU 实际分区/格式化;
# VM 以镜像为根启动,systemd 激活至 multi-user,home-manager-fww 成功;
# 仅剩 smartd / nvidia-CDI 失败 = VM 无真实硬件的预期。
# 本夹具曾挖出三只真虫(均已修入生产模块):
#   1. fww 家目录无人创建(activation 早于 /home 挂载,目录建在 @root 被遮蔽)
#      → modules/nixos/users.nix tmpfiles
#   2. sops 家目录符号链接同竞态全丢(ssh_key/gh-hosts/access-tokens)
#      → modules/nixos/secrets.nix tmpfiles
#   3. tmpfiles 补父目录默认 root 属主,HM 无法写入 → 显式 d 规则修正
# ⚠️ 绝不可用于真机:disko 指向 /dev/vda(QEMU 专用),内核为标准内核(绕 vmTools
# 与 cachyos 内核/TCG 的兼容性),dae 禁用(VM 无代理网络)。
#
# sops 策略(零生产文件妥协的代价即此两文件):
#   secrets-fixture.yaml = 全 dummy 值,收件人只有下面这把一次性 age 钥匙
#   age-key-fixture.txt  = 一次性私钥,进 store 安全——它只守着 dummy 数据,
#                          解不开真实 secrets.yaml,泄漏零价值
#   (真实 admin/host 钥匙永不可入 store:世界可读且随缓存传播)
# 维护契约:secrets.nix 新增 secret 时,fixture 文件需同步补 dummy 键
# (VM 激活会当场报 missing key,不会静默漂移)
{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  p = import ./params.nix;
in
{
  # ── VM 验证裁剪 ──────────────────────────────────────
  # dae:VM 无代理网络,且 dummy URL 会使其 crashloop(引导不受影响,但吵)
  services.dae.enable = lib.mkForce false;
  # root 串口登录备用(日常验证走下方 export 服务,无需登录)。
  # 注意必须用 password 而非 initialPassword:后者只在用户首次创建时生效,
  # root 在激活早期即存在 → initialPassword 永远不生效(实测登录错误)
  users.users.root.password = lib.mkForce "vmtest";
  # guest 内跑 nixos-facter,产物经 qemu-vm 内建 /tmp/xchg 双向共享导出
  environment.systemPackages = [ pkgs.nixos-facter ];
  # ── 启动可见性(诊断卡死用;mkForce 压过共享 boot.nix 的 0)──
  # quiet/loglevel=0/show_status=false 全关,串口全程叙述;systemd 单元
  # 卡在哪一步,pane 上一目了然
  boot.consoleLogLevel = lib.mkForce 7;
  boot.kernelParams = [
    "systemd.show_status=always"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];
  # 里程碑标记:走到哪一步就写一行到串口 + xchg(卡死时最后一条即卡点)
  systemd.services.vmtest-progress = {
    description = "vmtest: boot progress markers";
    wantedBy = [ "sysinit.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mark() { echo "PROGRESS: $1" > /dev/console; echo "$1" >> /tmp/xchg/boot-progress.log 2>/dev/null || true; }
      mark sysinit
    '';
  };
  systemd.services.vmtest-progress-basic = {
    description = "vmtest: basic.target marker";
    wantedBy = [ "basic.target" ];
    serviceConfig.Type = "oneshot";
    script = ''echo "PROGRESS: basic.target" > /dev/console; echo basic >> /tmp/xchg/boot-progress.log 2>/dev/null || true'';
  };
  systemd.services.vmtest-progress-multi = {
    description = "vmtest: multi-user.target marker";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''echo "PROGRESS: multi-user.target" > /dev/console; echo multi >> /tmp/xchg/boot-progress.log 2>/dev/null || true'';
  };

  # ── 非交互导出:验证产物自动落 xchg(host: $TMPDIR/nix-vm.*/xchg)──
  # 比串口交互登录可靠(agetty 时序/回显/locale 三重坑),CI 可无人值守跑
  systemd.services.vmtest-export = {
    description = "vmtest: HM journal + facter 导出到 /tmp/xchg";
    wantedBy = [ "multi-user.target" ];
    # after 该单元本身 = 同步等 HM 尝试完(无论成败)再导出,journal 完整
    after = [
      "home-manager-fww.service"
      "multi-user.target"
    ];
    serviceConfig.Type = "oneshot";
    unitConfig.ConditionPathIsDirectory = "/tmp/xchg";
    script = ''
      journalctl -u home-manager-fww.service --no-pager -n 300 > /tmp/xchg/hm.log || true
      systemctl --no-pager --failed > /tmp/xchg/failed.txt || true
      systemctl is-system-running > /tmp/xchg/state.txt || true
      ${pkgs.nixos-facter}/bin/nixos-facter -o /tmp/xchg/facter.json 2> /tmp/xchg/facter.err || true
      touch /tmp/xchg/DONE
    '';
  };
  # 桥接上游未知不兼容:disko make-disk-image 给 vmTools 传 aggregateModules
  # 模块树(无 target attr),新 nixpkgs vmTools 直接 throw(与内核选择无关)。
  # x86 内核镜像恒 bzImage → 显式钉住;上游 master 未修(2026-08 检索无既有
  # issue),上游修复或换 nixpkgs pin 后删此 overlay。issue 草稿在
  # /tmp/opencode/disko-issue.md(是否提交由仓库主人决定,未经许可不代发)
  nixpkgs.overlays = [
    (_final: prev: {
      vmTools = prev.vmTools.override { kernelImage = "bzImage"; };
    })
  ];
  # 镜像模式:imageSize 缺省 2G 装不下 ESP 4G + swap + root
  disko.devices.disk.system.imageSize = "10G";
  disko.memSize = 4096;
  # vmWithDisko 在 vmVariantWithDisko 嵌套求值里跑(qemu-vm.nix 只在那里
  # import)——headless/串口经官方注入点设置;内核 console 走其 consoles 默认
  virtualisation.vmVariantWithDisko.virtualisation.graphics = false;

  # ── sops 夹具数据源(声明全保留,仅换文件与钥匙)──────
  sops = {
    defaultSopsFile = lib.mkForce ./secrets-fixture.yaml;
    age.sshKeyPaths = lib.mkForce [ ]; # VM 无 host key
    # sops-nix 类型系统禁 store 路径(私钥不进 store 是上游强制的安全属性)。
    # 一次性钥匙经 /etc 转交:etc.text 本质仍在 store,但这把钥匙只守 dummy
    # 数据(secrets-fixture.yaml 收件人仅它),泄漏零价值 —— 威胁模型可接受
    age.keyFile = lib.mkForce "/etc/sops-vmtest-age-key";
  };
  environment.etc."sops-vmtest-age-key".text = builtins.readFile ./age-key-fixture.txt;

  # qemu-vm.nix 在 VM 变体里强制 videoDrivers=["modesetting"](mkVMOverride=优先级10),
  # nvidia 从 extraModulePackages 消失,而 facter 报告(真实硬件)给 initrd 带来的
  # nvidia 模块需求仍在 → modules-shrunk modprobe FATAL。用优先级 9 钉回 nvidia,
  # 三方(facter 模块需求/驱动包/断言)全部恢复自洽
  virtualisation.vmVariantWithDisko.services.xserver.videoDrivers = lib.mkOverride 9 [ "nvidia" ];

  # 镜像不灌 Nix store(vmWithDisko 的 VM 经 9p 共享用宿主 store);
  # 关掉同时绕开 make-disk-image 的 copyNixStore→vmTools→cachyos 内核
  # 缺 target attr 的死路(见 disko make-disk-image.nix:140 的门控)
  disko.imageBuilder.copyNixStore = false;

  imports = [
    # 硬件事实:nixpkgs 原生 hardware.facter(initrd 模块/微码/hostPlatform 推导)
    # 重生成(换硬件/固件升级):sudo nix run nixpkgs#nixos-facter -- -o ./.facter.json
    ./disko.nix
  ]
  ++ lib.optionals (p.gpu == "nvidia") [ ./nvidia.nix ]
  ++ [
    # 硬件模块(CPU profile 名由 params 提供;特定机型 quirk 见 nixos-hardware 目录树)
    inputs.nixos-hardware.nixosModules.${p.cpuProfile}
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  hardware.facter.reportPath = ./.facter.json;

  system.stateVersion = "26.05";
}
