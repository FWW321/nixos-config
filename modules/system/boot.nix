# filepath: ~/nixos-config/modules/system/boot.nix
# 启动、内核、性能调优
{ pkgs, inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.default
    inputs.nix-gaming-edge.overlays.proton-cachyos
  ];

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

  # scx 调度器 - 现代 BPF 调度器，提升交互响应
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  # 电源管理
  services.power-profiles-daemon.enable = true;
  services.irqbalance.enable = true;

  # zram 压缩交换
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
}
