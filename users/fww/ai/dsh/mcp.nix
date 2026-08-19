# filepath: ~/nixos-config/users/fww/ai/dsh/mcp.nix
# dsh MCP + skills:从中立 common 层派生(同 opencode 的 adapter 模式)
# 密钥:secretFile 形态 → nixdsh 占位符 + wrapper 启动期注入(store 工件零密钥)
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  # common secretHeaders 值两种形态(opencode 同款语义):
  #   "/run/secrets/x"(裸路径)或 { secretFile; prefix? } → nixdsh secret 形态
  header =
    v:
    if builtins.isString v then { secretFile = v; }
    else { inherit (v) secretFile; } // lib.optionalAttrs (v ? prefix) { inherit (v) prefix; };

  # common 的 source 是 opencode 语义(整目录递归,可能指 skill 集合仓库根);
  # dsh 需要目录内有 SKILL.md。探测:<source>/SKILL.md 直取,否则试
  # skill 集合布局 <source>/skills/<名>/(git-workflow 等实测);
  # 都不中保持原值交给 nixdsh validateSkills throw(报错可见原始路径)。
  # entryFile(common)恒为 SKILL.md = 目录束语义,无须特判
  skillSource = name: s:
    let src = toString s.source; in
    if builtins.pathExists "${src}/SKILL.md" then s.source
    else if builtins.pathExists "${src}/skills/${name}/SKILL.md" then "${src}/skills/${name}"
    else s.source;
in
{
  programs.dsh.mcpServers = lib.mapAttrs
    (_: s:
      if s ? remote then {
        transport = "streamable-http";
        inherit (s.remote) url;
        headers = lib.mapAttrs (_: header) (s.remote.secretHeaders or { });
      } else {
        inherit (s.local) command;
        args = s.local.args or [ ];
        env = lib.mapAttrs (_: v:
          if v ? secretFile then { inherit (v) secretFile; } else v
        ) (s.local.env or { });
      })
    # dsh 两种 transport 都原生支持,全取
    (lib.filterAttrs (_: s: s.defaultEnabled) common.mcp);

  programs.dsh.skills = lib.mapAttrs
    (name: s: { source = skillSource name s; })
    (lib.filterAttrs (_: s: s.defaultEnabled) common.skills);

  # skill 绑定的工具进 PATH(agent-browser/pdf-inspector 等)
  home.packages = lib.catAttrs "package" (lib.attrValues common.skills);
}
