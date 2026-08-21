# filepath: ~/nixos-config/users/fww/default.nix
# 用户 fww 的 Home Manager 配置
{
  config,
  lib,
  pkgs,
  inputs,
  osConfig,
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
    # programs.zcode 通用模块已迁独立仓库 zcode-nix;数据适配器在 ./ai/agents/zcode/
    inputs.zcode-nix.homeManagerModules.zcode
    # dsh 模块经 flake.nix sharedModules 挂载(inputs.nixdsh.homeManagerModules.dsh)
    ./development
    ./docs.nix
  ];
  # 常用工具(nh 由系统级 programs.nh 提供 NH_FLAKE,见 modules/system/nix.nix)
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
      xwayland-satellite
      # MiniMax Token Plan CLI(终端直接可用;opencode skill 侧见 ai/common/skills.nix)
      mmx-cli
    ];

  # bash 配置整体在 ./terminal.nix(enable/aliases/各集成),此处不重复声明

  # Koharu 配置已迁 users/fww/ai/koharu.nix(programs.koharu)

  # Git/Jujutsu 配置迁至 ./vcs/(见上方 imports)

  # SSH 配置(forge host 块迁至 ./vcs/forge.nix,数据驱动与 insteadOf/username 同源)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # 全局兜底:所有 ssh 连接统一用 id_ed25519 一把身份钥(forge 认证/jj 签名/手动连机同源)
    # 不再为任何用途单独造钥;known_hosts 钉死见 modules/system/ssh.nix
    settings."*" = {
      identityFile = osConfig.sops.secrets.ssh_key.path;
      identitiesOnly = true;
    };
  };
}
