# filepath: ~/nixos-config/users/fww/ai/dsh/plugins.nix
# 插件声明(nixdsh README 语义模型 §4)
#
# 交互面(in-box web-app/headless 由模块表推导;registry 插件由收录时的
#   face= 标记推导,如 dsh-TUI)—— enable 即自动生成 face profile 与
#   dsh-<face> wrapper,face 名无需在此声明。
# 功能插件:enable 即装,profiles 缺省分发到所有交互面。
# (status-rotator 的 typed 短路径选项 programs.dsh.status-rotator 也在此层)
{ pkgs, ... }:

{
  programs.dsh.plugins = {
    # ── 交互面(face 自动推导)──
    web-app.enable = true;   # → face "web"(dsh web 子命令硬编码)
    headless.enable = true;  # → face "headless"
    dsh-tui = {              # → face "tui"(registry face= 标记)
      enable = true;
      source = pkgs.dshPlugins."@deepseek-harness-tui/dsh-tui";
    };
  };

  # typed 短路径模块(dsh-status-rotator)的声明面
  programs.dsh.status-rotator.enable = true;
}
