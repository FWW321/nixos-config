# filepath: ~/nixos-config/modules/system/theme.nix
# Stylix 主题配置：字体、光标、配色
{ pkgs, ... }:

{
  stylix = {
    enable = true;
    polarity = "dark";
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
