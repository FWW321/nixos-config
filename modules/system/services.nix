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

  # 运行非 NixOS 二进制文件（下载的闭源软件、patchelf 过 interpreter 的二进制）
  # 注意：只对 interpreter 设为 nix-ld 的二进制生效；cargo install 的二进制
  # interpreter 是 nix glibc ld（不走 nix-ld），仍需 LD_LIBRARY_PATH（见 development.nix）
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      openssl # libssl.so.3
      stdenv.cc.cc # libstdc++.so（C++ 预编译二进制常用）
      zlib # 常见压缩库依赖
    ];
  };

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
