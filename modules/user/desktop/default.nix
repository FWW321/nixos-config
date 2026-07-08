# filepath: ~/nixos-config/modules/user/desktop/default.nix
# 桌面环境用户配置：Wayland 合成器、输入法、截图工具
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
    inputs.noctalia.homeModules.default
    ./noctalia.nix
    ./niri.nix
    ./hyprland.nix
    ./media.nix
    ./input-method.nix
  ];

  # Wayland 工具包
  home.packages = with pkgs; [
    gpu-screen-recorder
    wl-clipboard
    jq
  ];

  # 如需切换到 KDE Plasma 桌面，在 flake inputs 加入 plasma-manager：
  #   inputs.plasma-manager.url = "github:nix-community/plasma-manager";
  # 然后在此处导入并启用：
  #   imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];
  #   programs.plasma.enable = true;
  # 即可声明式配置面板、小部件、KWin 窗口规则、快捷键、配色方案等。
  # 详见：https://github.com/nix-community/plasma-manager

  # 截图标注工具
  programs.satty = {
    enable = true;
    settings.general = {
      fullscreen = true;
      early-exit = true;
      initial-tool = "arrow";
      copy-command = "wl-copy";
    };
  };

  xresources.properties."Xft.dpi" = 144;

  home.sessionVariables = {
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  # nix.conf:声明式主体 + secret 片段 include 分离
  # access-tokens 含 token(不能进 store),由 activation 单独写 access-tokens.conf
  # nix.conf 主体声明式,将来可加非敏感设置不与 secret 冲突
  xdg.configFile."nix/nix.conf".text = ''
    include ${config.home.homeDirectory}/.config/nix/access-tokens.conf
  '';

  home.activation.nixAccessTokens = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN=$(cat /run/secrets/github_token)
    printf 'access-tokens = github.com=%s\n' "$TOKEN" > "$HOME/.config/nix/access-tokens.conf"
  '';
}
