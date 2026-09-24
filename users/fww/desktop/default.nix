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
  # 字体(2026-09-23 排障):satty 文字工具的 femtovg/fontdb 不走 fontconfig,
  # 只扫 XDG 数据目录 —— 系统字体(含 stylix 的 JetBrainsMono Nerd Font)全在
  # store 经 fonts.conf 注册,fontdb 看不见,默认字体一直加载失败(此前挂
  # noctalia 下 stderr 进 journal 不可见)。修法:普通 ttf 链入 fontdb 扫描区。
  # 注意字段在 [font] 段(family/fallback),[general] 不收 font-family
  # (satty 0.22 实测,写错段名 satty 直接拒启)。fallback 补 CJK:JetBrains
  # 无汉字字形,中文标注回退霞鹜文楷(Noto CJK 的 VF.ttc fontdb 解析不动,
  # 只能选普通 ttf 的中文字体)。
  programs.satty = {
    enable = true;
    settings = {
      general = {
        fullscreen = true;
        early-exit = true;
        initial-tool = "arrow";
        copy-command = "wl-copy";
      };
      font = {
        family = "JetBrainsMono Nerd Font";
        fallback = [ "LXGW WenKai" ];
      };
    };
  };
  xdg.dataFile."fonts/JetBrainsMonoNerdFont-Regular.ttf".source =
    "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/JetBrainsMonoNerdFont-Regular.ttf";
  xdg.dataFile."fonts/LXGWWenKai-Regular.ttf".source =
    "${pkgs.lxgw-wenkai}/share/fonts/truetype/LXGWWenKai-Regular.ttf";
  # 置空的 GTK 样式覆盖:仅为消掉 satty 每次「overrides.css does not exist」
  # 的启动提示(该文件可选,空 = 用内置样式)
  xdg.configFile."satty/overrides.css".text = "/* managed by home-manager */\n";

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
