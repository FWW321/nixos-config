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
    ./nautilus.nix
  ];

  # Wayland 工具包
  home.packages = with pkgs; [
    gpu-screen-recorder
    grim
    slurp
    wl-clipboard
    jq
    (writeShellScriptBin "noctalia-shell-env" ''
      export NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY=$(cat ${config.sops.secrets.zhipu_api_key.path})
      exec ${config.programs.noctalia-shell.package}/bin/noctalia-shell "$@"
    '')
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

  # XWayland DPI
  xresources.properties."Xft.dpi" = 144;

  # Fcitx5 输入法
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
        fcitx5-pinyin-zhwiki
      ];
      settings = {
        globalOptions."Hotkey/TriggerKeys"."0" = "Shift_L";
        inputMethod = {
          "Groups/0" = { Name = "Default"; "Default Layout" = "us"; DefaultIM = "keyboard-us"; };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "pinyin";
          GroupOrder."0" = "Default";
        };
        addons.cloudpinyin.globalSection.CloudPinyinEnabled = false;
      };
    };
  };

  systemd.user.services.fcitx5-daemon.Service = {
    Restart = "always";
    RestartSec = "3";
  };

  home.sessionVariables = {
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  sops.secrets.zhipu_api_key = { };

  # GitHub Token 配置
  home.activation.writeNixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN=$(cat /run/secrets/github_token)
    mkdir -p ~/.config/nix
    cat > ~/.config/nix/nix.conf << EOF
    access-tokens = github.com=$TOKEN
    EOF
  '';
}
