# filepath: ~/nixos-config/modules/system/theme.nix
# Stylix 主题配置：Catppuccin Mocha
{ pkgs, ... }:

{
  stylix = {
    enable = true;
    # base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";

    # 4K 二次元壁纸 - Sousou no Frieren (葬送的芙莉莲)
    # 来自 orangci/walls-catppuccin-mocha 仓库，作为 Stylix 动态取色来源
    # image = pkgs.fetchurl {
    #  url = "https://raw.githubusercontent.com/orangci/walls-catppuccin-mocha/master/sousou-no-frieren-flowers.png";
    #  hash = "sha256-BjtLliCPtyC6tP6dZhh4FC27E8qj1JXxNtDgBMeG0bc=";
    # };

    # 本地壁纸（放在仓库 wallpapers/ 目录下，直接引用相对路径）
    image = ../../wallpapers/wallhaven-pkw6y3.jpg;

    fonts = {
      monospace = {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
      sansSerif = {
        name = "Noto Sans CJK SC";
        package = pkgs.noto-fonts-cjk-sans;
      };
      sizes = {
        applications = 12;
        desktop = 12;
        popups = 12;
        terminal = 14;
      };
    };

    cursor = {
      name = "catppuccin-mocha-dark-cursors";
      package = pkgs.catppuccin-cursors.mochaDark;
      size = 24;
    };

    opacity = {
      applications = 0.95;
      terminal = 0.85;
      desktop = 0.85;
      popups = 0.90;
    };
  };
}
