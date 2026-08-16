# filepath: ~/nixos-config/users/fww/ai/dsh/profiles/tui.nix
# tui profile:ccch1mneyyy/dsh-TUI(交互式终端前端,带 cordis bundle patch
# 的真 layer 插件 — 进 bundles 层序,与 in-box 同权)
#
# 收录流程实录(验证 registry 机制闭环):
#   echo ccch1mneyyy/dsh-TUI >> nixdsh/plugins/names.txt
#   bash nixdsh/plugins/update.sh <nixdsh>     # v0.7.2 + hash + bundlePatch 自动物化
#   → pkgs.dshPlugins."@deepseek-harness-tui/dsh-tui"(packageName 取自上游 package.json)
{ pkgs, ... }:

{
  programs.dsh.profiles.tui = {
    plugins = [
      "@deepseek-ai/dsh-base"
      pkgs.dshPlugins."@deepseek-harness-tui/dsh-tui"
    ];
  };
}
