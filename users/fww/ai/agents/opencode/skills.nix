# filepath: ~/nixos-config/users/fww/ai/agents/opencode/skills.nix
# Skills 链接(静态 symlink) + 依赖包 + env + bash 集成
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  common = import ../../common {
    inherit
      pkgs
      inputs
      lib
      config
      ;
  };

  # ── 全局 skill:defaultEnabled = true 的(通用),特殊的走项目级 agent skill add ──
  selectedSkills = lib.filterAttrs (
    _: s: (s.defaultEnabled or false) && !(s ? runtime)
  ) common.skills;

  # ── Skill 链接：entryFile 单文件 vs 目录递归 ──
  linkSkill =
    name: s:
    if s ? entryFile then
      { "opencode/skills/${name}/${s.entryFile}".source = "${s.source}/${s.entryFile}"; }
    else
      {
        "opencode/skills/${name}" = {
          inherit (s) source;
          recursive = true;
        };
      };
  # ── 从选中的 skill 中提取包和 env ──
  skillPkgs = lib.catAttrs "package" (
    lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills)
  );
  skillEnv = lib.foldl' (acc: s: acc // (s.env or { })) { } (lib.attrValues selectedSkills);
in
{
  # ── Skills（静态 symlink）──
  xdg.configFile = lib.mkMerge [
    (lib.mergeAttrsList (lib.mapAttrsToList linkSkill selectedSkills))

    # ── Rules:聚合源(通用规则 + 通用资源 guide)──
    { "opencode/AGENTS.md".source = common.project.globalAgentsMd; }

    # opencode v2 运行时会改写 opencode.json(如 websearch provider 选择),symlink 被
    # 替换成普通文件 → switch 触发备份,旧 .backup 残留报 clobber
    # 声明式配置才是真源,运行时改动反正是要被覆盖的 → force 直接覆盖,不产生 .backup
    { "opencode/opencode.json".force = true; }

    # ── Plugin:herdr agent-state — 已禁用(beta 插件管线的坑,见 settings.nix 注释)──
    # 文件保留在 ../opencode-plugins/,stable 后随 settings.plugin 一起启用
    # {
    #   "opencode/plugins/herdr-agent-state.js".source =
    #     ../opencode-plugins/herdr-agent-state.js;
    # }
  ];

  # ── skill 依赖包 ──
  home.packages = skillPkgs;

  # EXA_API_KEY 保留(v2 内置 websearch 走 exa);
  # OPENCODE_ENABLE_EXA 是 v1 实验开关,v2 无此 flag 已删
  home.sessionVariables = skillEnv;

  # v2 二进制名是 opencode2(官方有意与 v1 区分);别名让肌肉记忆的 opencode 直接可用
  programs.bash.shellAliases.opencode = "opencode2";

  programs.bash.initExtra = ''
    [ -f /run/secrets/exa_api_key ] && export EXA_API_KEY="$(cat /run/secrets/exa_api_key)"
  '';
}
