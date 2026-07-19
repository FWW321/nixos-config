# filepath: ~/nixos-config/users/fww/default.nix
# 用户 fww 的 Home Manager 配置
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  home.username = "fww";
  home.homeDirectory = "/home/fww";
  home.stateVersion = "26.05";

  # home-manager 26.05 改了 gtk.gtk4.theme 默认值，保持 GTK4 跟随 Stylix 全局主题
  gtk.gtk4.theme = lib.mkForce config.gtk.theme;

  # home-manager 新增 qt.kvantum 模块与 Stylix 冲突，用 mkForce 覆盖
  xdg.configFile."Kvantum/kvantum.kvconfig" = lib.mkForce {
    source = (pkgs.formats.ini { }).generate "kvantum.kvconfig" { General.theme = "Base16Kvantum"; };
  };

  imports = [
    ./ai
    ./browsers
    ./vcs
    ./editors
    ../../modules/user/desktop
    ../../modules/user/terminal.nix
    ./development
    ./docs.nix
  ];

  # SOPS 密钥管理
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../secrets/secrets.yaml;
    secrets.vcs_ssh_key.path = "${config.home.homeDirectory}/.ssh/vcs_key";
    secrets.zhipu_api_key = { };
  };

  # 系统工具
  home.packages =
    with pkgs;
    [
      qq
      fd
      curl
      btop
      ripgrep
      wireshark-cli
      nh
      xwayland-satellite
      nvtopPackages.nvidia
    ];

  programs.bash.enable = true;

  # Git/Jujutsu 配置迁至 ./vcs/(见上方 imports)

  # SSH 配置(forge host 块迁至 ./vcs/forge.nix,数据驱动与 insteadOf/username 同源)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
}
