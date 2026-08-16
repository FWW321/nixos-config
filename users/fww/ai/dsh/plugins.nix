# filepath: ~/nixos-config/users/fww/ai/dsh/plugins.nix
# 插件声明(交互面 + 功能插件,统一一层;nixdsh README 语义模型 §4)
#
# 交互面 = face 插件:自动生成 profile([base+source] 配方由模块编码),
#   不参与跨 profile 分发(交互面 bundle 互斥)。face 数 = profile 数。
# 功能插件 = 无 face:enable 即装,profiles 缺省分发到所有交互面。
# (status-rotator 的 typed 短路径选项 programs.dsh.status-rotator 也在此层)
{ pkgs, ... }:

{
  programs.dsh.plugins = {
    # ── 交互面(in-box;dsh web 子命令固定 boot 名为 "web" 的 profile)──
    web-app = {
      enable = true;
      face = "web";
      source = "@deepseek-ai/dsh-web-app";
    };
    headless = {
      enable = true;
      face = "headless";
      source = "@deepseek-ai/dsh-headless";
    };

    # ── 交互面(第三方 TUI;registry 插件,needsBuild 构建路径)──
    dsh-tui = {
      enable = true;
      face = "tui";
      source = pkgs.dshPlugins."@deepseek-harness-tui/dsh-tui";
    };
  };

  # typed 短路径模块(dsh-status-rotator)的声明面
  programs.dsh.status-rotator.enable = true;
}
