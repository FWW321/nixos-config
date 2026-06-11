# filepath: ~/nixos-config/modules/system/services.nix
# 系统服务：SSH、防火墙、存储维护
{ pkgs, ... }:

{
  # OpenSSH 安全配置
  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
    hostKeys = [{
      type = "ed25519";
      path = "/etc/ssh/ssh_host_ed25519_key";
    }];
  };

  # 运行非 NixOS 二进制文件
  programs.nix-ld.enable = true;

  # 系统工具
  environment.systemPackages = with pkgs; [ lm_sensors ];

  # 防火墙
  networking.firewall.enable = true;

  # 存储维护
  services.btrfs.autoScrub.enable = true;
  # TRIM 由 btrfs discard=async 挂载选项实时处理，无需 fstrim 定时任务
  services.smartd.enable = true; # 磁盘 SMART 健康监控
  services.fwupd.enable = true; # 固件更新（主板/SSD/外设）
}
