# filepath: ~/nixos-config/users/fww/ai/dsh/plugins.nix
# 插件声明(nixdsh README 语义模型 §4)
#
# 交互面(face 自动推导):enable 即自动生成 face profile 与子命令入口
#   `dsh <face>`(web 走上游原生子命令)。
# 功能插件:enable 即装,profiles 缺省分发到所有交互面。
# (status-rotator 的 typed 短路径选项 programs.dsh.status-rotator 也在此层)
{ ... }:

{
  programs.dsh.plugins = {
    # ── 交互面(face/registry 全自动)──
    web-app.enable = true;   # → face "web"(上游 dsh web 原生子命令)
    headless.enable = true;  # → face "headless"(in-box 表推导)
    dsh-tui = {
      enable = true;                       # → face "tui"(registry 键名反查 + face= 元数据,零 source)
      excludedPresets = [ "liangshen" ];   # 接管黑名单:不进 farm 不重放;上游播种照旧(UI 仍可选),默认不再指向它
      # defaultPreset/permissionMode 不设 → 回落全局(standard / workspace-write,见 search.nix)
    };
  };

  # typed 短路径模块(dsh-status-rotator)的声明面
  programs.dsh.status-rotator.enable = true;
}
