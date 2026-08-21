# FWW-Desktop 主机配置 —— 自治:本机硬件文件 + nixos-hardware 模块在此 import,
# flake.nix 对本主机只挂 ./hosts/FWW-Desktop 一个入口
{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    # 硬件事实:nixpkgs 原生 hardware.facter(nixos-facter 报告驱动 initrd
    # 模块/微码/hostPlatform 等推导),取代 nixos-generate-config 手维护
    # hardware.nix。
    # 重生成(换硬件/固件升级时,需 root 读 SMBIOS):
    #   sudo nix run nixpkgs#nixos-facter -- -o ./.facter.json
    #   ./redact.sh   ← 必跑!公开仓库序列号脱敏(幂等;CI 会校验)
    ./disko.nix
    ./nvidia.nix

    # 硬件模块(主机相关,随主机走)
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  hardware.facter.reportPath = ./.facter.json;

  # 本机 ESP 1G(装机时既成事实,disko 改不了已装系统):单代实测 168M
  # (cachyos LTO + NVIDIA initrd 154M)→ 上限 ~5 代;与 nix.nix 的
  # nh clean --keep 5 对齐 = 实际可滚回深度。模板新机 ESP 4G 用默认 20
  boot.loader.systemd-boot.configurationLimit = 5;

  networking.hostName = "FWW-Desktop";

  boot.kernelModules = [
    "i2c-dev"
    "nct6775"
  ];
  hardware.i2c.enable = true;
  users.groups.i2c = { };
  users.users.fww.extraGroups = [ "i2c" ];
  environment.systemPackages = [ pkgs.ddcutil ];

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ca6", ATTRS{idProduct}=="0529", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="4617", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="1417", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  home-manager.users.fww = {
    programs.niri.settings.outputs."DP-1" = {
      mode = {
        width = 3840;
        height = 2160;
        refresh = 160.0;
      };
      scale = 1.5;
    };
    wayland.windowManager.hyprland.settings.monitor = {
      output = "DP-1";
      mode = "3840x2160@160";
      position = "0x0";
      scale = "1.5";
    };
  };

  system.stateVersion = "26.05";
}
