# 中立数据聚合层:mcp/skills/providers/plugins/rules/project
# 文件名即分类器:mcp.nix/skills.nix = 通用(defaultEnabled=true)
#                   mcp-project.nix/skills-project.nix = 项目级(defaultEnabled=false)
# project 需要 config(xdg.configHome),调用方需传 config
{ pkgs, inputs, lib, config, ... }:
let
  # 合并通用 + 项目级,defaultEnabled 由文件名决定
  mcp =
    (lib.mapAttrs (_: m: m // { defaultEnabled = true; })
      (import ./mcp.nix { inherit pkgs; }))
    // (lib.mapAttrs (_: m: m // { defaultEnabled = false; })
      (import ./mcp-project.nix { }));

  skills =
    (lib.mapAttrs (_: s: s // { defaultEnabled = true; })
      (import ./skills.nix { inherit pkgs inputs lib; }))
    // (lib.mapAttrs (_: s: s // { defaultEnabled = false; })
      (import ./skills-project.nix { inherit inputs lib; }));
in
{
  inherit mcp skills;
  providers = import ./providers.nix;
  plugins = import ./plugins.nix { inherit pkgs inputs; };
  rules = ./rules.md;
  project = import ./project.nix {
    inherit pkgs lib config mcp skills;
    rules = ./rules.md;
  };
}
