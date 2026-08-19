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
    # dsh 模块经 flake.nix sharedModules 挂载(inputs.nixdsh.homeManagerModules.dsh)
    ./development
    ./docs.nix
  ];

  # 系统工具
  home.packages =
    with pkgs;
    [
      qq
      fd
      curl
      btop
      ripgrep
      dust
      hyperfine
      ouch
      wireshark-cli
      nh
      xwayland-satellite
      # MiniMax Token Plan CLI(终端直接可用;opencode skill 侧见 ai/common/skills.nix)
      mmx-cli
    ];

  programs.bash.enable = true;

  # Git/Jujutsu 配置迁至 ./vcs/(见上方 imports)

  # SSH 配置(forge host 块迁至 ./vcs/forge.nix,数据驱动与 insteadOf/username 同源)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
}
