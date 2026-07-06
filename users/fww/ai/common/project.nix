# 项目级资源管理:registry + 全局 AGENTS.md 聚合 + 通用 skill 渲染
# 三职责:
#   (1) registry:nix 生成 JSON,供 agent 命令运行时查"名字→资源"(部署到 ~/.config/ai/)
#   (2) globalAgentsMd:全局 AGENTS.md = 通用规则 + defaultEnabled=true 资源的 guide 聚合
#   (3) skillRender:通用 skill 渲染脚本(agent sync 调用,symlink 到 .agents/skills/)
{ pkgs, lib, config, mcp, skills, rules }:
let
  # defaultEnabled=true 且有 guide 的资源(全局 AGENTS.md 聚合用)
  enabledGuides = lib.filterAttrs
    (_: r: (r.defaultEnabled or false) && (r ? guide))
    (mcp // skills);
in
{
  # (1) registry:agent 命令查"名字→资源信息"
  #     不含 secret(只存 source/defaultEnabled/guide/runtime)
  registry = pkgs.writeText "ai-registry.json" (builtins.toJSON {
    skills = lib.mapAttrs (_: s: {
      source = s.source or null;
      entryFile = s.entryFile or null;
      defaultEnabled = s.defaultEnabled or false;
      runtime = s.runtime or null;
      guide = s.guide or null;
    }) skills;
    mcp = lib.mapAttrs (_: m: {
      defaultEnabled = m.defaultEnabled or false;
      guide = m.guide or null;
      # 故意不含 command/env/secret:secret 全局 opencode.json/mcp.json 管,registry 只管元数据
    }) mcp;
  });

  # (2) 全局 AGENTS.md:通用规则 + 通用的有 guide 资源的指引
  #     opencode 的 AGENTS.md source 共用这个
  globalAgentsMd = pkgs.writeText "AGENTS.md" ''
    ${builtins.readFile rules}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: r: r.guide) enabledGuides)}'';

  # (3) 通用 skill 渲染:把 manifest 里的 skill symlink 到项目 .agents/skills/
  #     opencode 物理共读 .agents/skills/,渲染逻辑零差异
  skillRender = pkgs.writeShellScript "ai-skill-render" ''
    MANIFEST="''${1:-$PWD/.agents/manifest.json}"
    PROJECT="''${2:-$PWD}"
    REG="${config.xdg.configHome}/ai/registry.json"
    mkdir -p "$PROJECT/.agents/skills"
    for name in $(jq -r '.skills[]?' "$MANIFEST" 2>/dev/null); do
      src=$(jq -r --arg n "$name" '.skills[$n].source // empty' "$REG" 2>/dev/null)
      if [ -n "$src" ]; then
        ln -sfn "$src" "$PROJECT/.agents/skills/$name"
      else
        echo "[skill-render] warning: skill '$name' not in registry" >&2
      fi
    done
  '';
}
