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

  # providers 中立层(schema 校验后的形状,思考档对账同源取数)
  providers = import ./providers-schema.nix lib (import ./providers.nix);

  # subagents 思考档对账(与 skills 存在性断言同科:静默漂移防线):
  # 档名必须是该模型全部声明端点 levels 键的**交集**成员 —— 交集语义 =
  # 跨端一致的通用词汇,单端点专属档名(如 mimo responses 的 low=on 等价档)
  # 不配进中立层;拼错的档名两端各自静默无效/报错不一,在此统一拦下
  subagentsRaw = import ./subagents.nix;
  subagentThinkingViolations = lib.concatLists (
    lib.mapAttrsToList (
      name: sa:
      lib.optionals (sa ? thinking) (
        let
          m = providers.${sa.model.provider}.models.${sa.model.model};
          levelSets = lib.mapAttrs (_: t: builtins.attrNames t.levels) (
            lib.filterAttrs (_: t: t != null) m.thinking
          );
          sets = lib.attrValues levelSets;
          common =
            if sets == [ ] then
              [ ] # 模型无任何思考控制声明
            else
              lib.foldl' lib.intersectLists (lib.head sets) (lib.tail sets);
        in
        if sets == [ ] then
          [
            "subagent \"${name}\": 设了 thinking \"${sa.thinking}\",但 ${sa.model.provider}/${sa.model.model} 未声明任何 thinking(思考不可控)"
          ]
        else
          lib.optional (!(builtins.elem sa.thinking common))
            "subagent \"${name}\": thinking \"${sa.thinking}\" 不在 ${sa.model.provider}/${sa.model.model} 各端点 levels 交集(${toString common})中"
      )
    ) subagentsRaw
  );
  subagents = lib.throwIf (subagentThinkingViolations != [ ]) (
    "subagent 思考档违约(common/subagents.nix):\n  " + lib.concatStringsSep "\n  " subagentThinkingViolations
  ) subagentsRaw;
in
{
  inherit
    mcp
    skills
    providers
    subagents
    ;
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
