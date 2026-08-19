# 中立数据聚合层:mcp/skills/providers/rules/project
# 文件名即分类器:mcp.nix/skills.nix = 通用(defaultEnabled=true)
#                   mcp-project.nix/skills-project.nix = 项目级(defaultEnabled=false)
# project 需要 config(xdg.configHome),调用方需传 config
# (plugins.nix 已删:dcg 移除 + herdr 插件改 agents/opencode-plugins/ 本地维护)
{ pkgs, inputs, lib, config, ... }:
let
  # 合并通用 + 项目级,defaultEnabled 由文件名决定
  mcp =
    (lib.mapAttrs (_: m: m // { defaultEnabled = true; })
      (import ./mcp.nix { inherit pkgs; }))
    // (lib.mapAttrs (_: m: m // { defaultEnabled = false; })
      (import ./mcp-project.nix { inherit lib config; }));

  skills =
    (lib.mapAttrs (_: s: s // { defaultEnabled = true; })
      (import ./skills.nix { inherit pkgs inputs lib; }))
    // (lib.mapAttrs (_: s: s // { defaultEnabled = false; })
      (import ./skills-project.nix { inherit inputs lib; }));
in
{
  inherit mcp skills;
  providers = import ./providers.nix;
  rules = ./rules.md;
  project = import ./project.nix {
    inherit pkgs lib config mcp skills;
    rules = ./rules.md;
  };
}
