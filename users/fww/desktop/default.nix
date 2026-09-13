# filepath: ~/nixos-config/users/fww/desktop/default.nix
# 桌面环境用户配置：Wayland 合成器、输入法、截图工具
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
    # programs.noctalia 改用 home-manager 内置模块(HM fdc36b1 起收录,
    # 与 noctalia-shell flake 的 nix/home-module.nix 逐字同源;双加载即
    # option 重复声明,inputs.noctalia 已退场)
    ./noctalia.nix
    ./niri.nix
    ./hyprland.nix
    ./drawy.nix
    ./blender.nix
    ./godot.nix
    ./media.nix
    ./input-method.nix
    ./xdg-user-dirs.nix
  ];

  # Wayland 工具包(jq 由 programs.jq.enable 在 terminal.nix 装,不重复)
  home.packages = with pkgs; [
    gpu-screen-recorder
    wl-clipboard
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
  # access-tokens.conf 由系统 sops 模板渲染(见 modules/nixos/secrets.nix),token 不经手 shell
  xdg.configFile."nix/nix.conf".text = ''
    include ${config.home.homeDirectory}/.config/nix/access-tokens.conf
  '';
}
