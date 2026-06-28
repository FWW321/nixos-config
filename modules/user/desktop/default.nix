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

  # GitHub Token 配置
  home.activation.writeNixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN=$(cat /run/secrets/github_token)
    mkdir -p ~/.config/nix
    cat > ~/.config/nix/nix.conf << EOF
    access-tokens = github.com=$TOKEN
    EOF
  '';
}
