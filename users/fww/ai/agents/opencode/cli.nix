# filepath: ~/nixos-config/users/fww/ai/agents/opencode/cli.nix
# CLI/TUI 偏好(cli.json)— v2 把 v1 的 tui.json 更名为 cli.json
#
# stylix 的 opencode target 只写旧名 tui.json(v1 死重);theme.name 在此声明,
# 主题文件 themes/stylix.json 仍由 stylix 生成
#
# TUI 设置面板(Ctrl+P → Open settings)运行时会改写此文件,symlink 被换成
# 普通文件 → 与 opencode.json 同理(见 skills.nix 注释):声明式为真源,
# force 直接覆盖不产生 .backup,面板里的临时改动 rebuild 后回滚
{
  xdg.configFile."opencode/cli.json" = {
    force = true;
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/v2/cli.json";
      theme.name = "stylix";
      keybinds."session.toggle.thinking" = "ctrl+y";
      session = {
        thinking = "hide";
        # assistant 消息底部显示输出 tok/s(opencode.ai/v2/docs/cli/config)
        tps = true;
      };
    };
  };
}
