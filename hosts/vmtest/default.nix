# filepath: ~/nixos-config/hosts/vmtest/
# VM 验证夹具主机 —— 运行:
#   nix build --out-link /tmp/vm .#nixosConfigurations.vmtest.config.system.build.vmWithDisko
#   /tmp/vm/bin/disko-vm   # headless(-nographic),Ctrl-C/timeout 退出
# 已验证(2026-08):disko 布局(diskoImages)在构建沙箱 QEMU 实际分区/格式化;
# VM 以镜像为根文件系统启动,systemd 激活至 greetd,无 panic/emergency。
# 已知未决:VM 内 home-manager-fww 单元失败(查因需交互式登录 VM:root 无密码
# 未开 + journalctl;真机无此问题,FWW-Desktop 每天正常激活 HM);smartd /
# nvidia-CDI 失败为 VM 无真实硬件的预期行为。
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
  # 内核换标准:①构建沙箱 QEMU(TCG)上 cachyos x86-64-v3 指令集有风险;
  # ②vmTools 桥接见下。被验证对象是分区/挂载/激活链,与内核发行版无关
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  # 桥接上游真空期:disko(2026-06 pin)给 vmTools 传 aggregateModules 模块树
  # (无 target attr),新 nixpkgs vmTools 直接 throw(disko master 未修)。
  # vmTools.override 链式累积,x86 Linux 内核镜像恒 bzImage → 显式钉住。
  # 夹具局部 overlay,生产主机不触及(diskoImages 无人构建)
  nixpkgs.overlays = [
    (_final: prev: {
      vmTools = prev.vmTools.override { kernelImage = "bzImage"; };
    })
  ];
  # dae:VM 无代理网络,且 dummy URL 会使其 crashloop(引导不受影响,但吵)
  services.dae.enable = lib.mkForce false;
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
    # 重生成(换硬件/固件升级):sudo nix run nixpkgs#nixos-facter -- -o ./.facter.json && ./redact.sh
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
