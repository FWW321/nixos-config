# 中立数据聚合层:mcp/skills/providers/subagents/rules/project
# 文件名即分类器:mcp.nix/skills.nix = 通用(defaultEnabled=true)
#                   mcp-project.nix/skills-project.nix = 项目级(defaultEnabled=false)
# subagents 纯意图数据无分级概念,直接导出
# project 需要 config(xdg.configHome),调用方需传 config
# (plugins.nix 已删:dcg 移除 + herdr 插件改 agents/opencode-plugins/ 本地维护)
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  # 合并通用 + 项目级,defaultEnabled 由文件名决定
  mcp =
    (lib.mapAttrs (_: m: m // { defaultEnabled = true; }) (import ./mcp.nix { inherit pkgs; }))
    // (lib.mapAttrs (_: m: m // { defaultEnabled = false; }) (
      import ./mcp-project.nix { inherit lib config; }
    ));

  skillsRaw =
    (lib.mapAttrs (_: s: s // { defaultEnabled = true; }) (
      import ./skills.nix { inherit pkgs inputs lib; }
    ))
    // (lib.mapAttrs (_: s: s // { defaultEnabled = false; }) (
      import ./skills-project.nix { inherit inputs lib; }
    ));

  # skill source 存在性断言(偷 agent-skills-nix 的校验,不引其架构):
  # 上游改目录名/flake input 指错 subdir 时 eval 静默过、运行时 skill
  # 空壳(悬空 symlink)——静默漂移与 subagents 同科,在聚合层拦下。
  # 两条不变量对应消费端的两种 link 形态(opencode/zcode 同构):
  #   entryFile 条目: ${source}/${entryFile} 存在(消费端直接引用该文件)
  #   目录条目:       ${source}/SKILL.md 存在(agent skills 目录格式约定)
  #   缺 source:      报形状错——未来出现 runtime-only 之类新形状时,
  #                   此断言逼作者显式来这里改契约,而不是静默绕过
  skillsViolations = lib.concatLists (
    lib.mapAttrsToList (
      name: s:
      if !(s ? source) then
        [ "skill \"${name}\": 缺 source 字段" ]
      else if s ? entryFile then
        lib.optional (
          !(builtins.pathExists "${s.source}/${s.entryFile}")
        ) "skill \"${name}\": ${s.source}/${s.entryFile} 不存在(上游改名/移动?)"
      else
        lib.optional (
          !(builtins.pathExists "${s.source}/SKILL.md")
        ) "skill \"${name}\": ${s.source}/SKILL.md 不存在(目录 skill 须含 SKILL.md)"
    ) skillsRaw
  );

  skills = lib.throwIf (skillsViolations != [ ]) (
    "skill source 违约(common/skills*.nix):\n  " + lib.concatStringsSep "\n  " skillsViolations
  ) skillsRaw;
in
{
  inherit mcp skills;
  providers = import ./providers-schema.nix lib (import ./providers.nix);
  subagents = import ./subagents.nix;
  rules = ./rules.md;
  project = import ./project.nix {
    inherit
      pkgs
      lib
      config
      mcp
      skills
      ;
    rules = ./rules.md;
  };
}
