# filepath: ~/nixos-config/modules/nixos/boot.nix
# 启动、内核、性能调优
# (kernel/proton 的 overlay 注册已集中 overlays/default.nix,此处只管 boot.*)
{ pkgs, ... }:

{
  boot = {
    initrd = {
      systemd.enable = true;
      verbose = false;
    };

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
      efi.canTouchEfiVariables = true;
      timeout = 1;
    };

    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v3;

    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "udev.log_priority=3"
      "rd.systemd.show_status=false"
      "transparent_hugepage=always"
    ];

    kernel.sysfs.kernel.mm.transparent_hugepage.defrag = "defer+madvise";
  };

  # scx 调度器 - sched_ext BPF 调度器,提升交互响应
  # flash:上游 1.0.15 起官方建议默认(commit c25ecbb,性能反超 bpfland;
  # bpfland 仍受支持,回切只改此行)
  services.scx = {
    enable = true;
    scheduler = "scx_flash";
  };

  # 电源管理
  services.power-profiles-daemon.enable = true;
  services.irqbalance.enable = true;

  # zram 压缩交换
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 30;
    priority = 100;
  };
}
