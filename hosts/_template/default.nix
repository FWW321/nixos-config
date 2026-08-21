# filepath: ~/nixos-config/hosts/_template/default.nix
# 新主机模板 —— install.sh 向导按探测结果替换占位符后物化为 hosts/<name>/
#
# 装机后仍需手动补的项(探测不出"意图"的部分,均已留 TODO 锚点):
#   - 显示器布局/缩放(niri/hyprland outputs)
#   - 主板传感器模块(nct6775 等)与 i2c/ddcutil
#   - HID udev 规则(键鼠 vendor:product)
#   - 本机专属包/服务
{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    # 硬件事实:nixpkgs 原生 hardware.facter(initrd 模块/微码/hostPlatform 推导)
    # 重生成(换硬件/固件升级):sudo nix run nixpkgs#nixos-facter -- -o ./.facter.json && ./redact.sh
    ./disko.nix
    {{GPU_IMPORT}}

    # 硬件模块(CPU profile 由向导探测填入;特定机型 quirk 见 nixos-hardware 目录树)
    inputs.nixos-hardware.nixosModules.{{CPU_PROFILE}}
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  hardware.facter.reportPath = ./.facter.json;

  networking.hostName = "{{HOSTNAME}}";

  # TODO 装机后(参考 FWW-Desktop 同段):
  # boot.kernelModules = [ "i2c-dev" "nct6775" ];  # 主板传感器
  # hardware.i2c.enable = true;
  # environment.systemPackages = [ pkgs.ddcutil ];
  # services.udev.extraRules = ''...'';            # 键鼠 udev
  # home-manager.users.fww.programs.niri.settings.outputs."DP-1" = { ... };  # 显示器

  system.stateVersion = "26.05";
}
