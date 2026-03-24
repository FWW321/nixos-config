# filepath: ~/nixos-config/modules/system/users.nix
# 用户、组、权限、tmpfiles 规则
{ config, pkgs, ... }:

{
  users.groups = {
    shared = { };
    sops-keys = { };
  };

  users.users.fww = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "shared" "sops-keys" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.nushell;
  };

  # 共享数据目录
  systemd.tmpfiles.rules = [
    "z /etc/ssh/ssh_host_ed25519_key 0640 root sops-keys - -"
    "d /data/public 2775 root shared - -"
    "d /data/public/games 2775 root shared - -"
    "d /data/public/games/steam 2775 root shared - -"
    "d /data/public/music 2775 root shared - -"
    "d /data/public/videos 2775 root shared - -"
    "d /data/public/pictures 2775 root shared - -"
    "d /data/private 0755 root root - -"
    "d /data/private/fww 0700 fww users - -"
  ];

  # sudo 配置
  security.sudo.extraConfig = "Defaults lecture = never";
  security.polkit.enable = true;
}
