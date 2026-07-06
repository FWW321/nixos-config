# 通用 skill(全局启用,工作流/知识类,环境无关)
# defaultEnabled 由 common/default.nix 注入(true),此文件只管数据
{ pkgs, inputs, lib, ... }:
let
  understandDirs = [
    "understand"
    "understand-chat"
    "understand-dashboard"
    "understand-diff"
    "understand-domain"
    "understand-explain"
    "understand-knowledge"
    "understand-onboard"
  ];
in
{
  # 单文件 skill(只取 SKILL.md)
  "agent-browser" = {
    source = "${inputs.agent-browser-skill}/skills/agent-browser";
    entryFile = "SKILL.md";
    package = pkgs.agent-browser;
    env.AGENT_BROWSER_EXECUTABLE_PATH = "brave";
  };
  "humanizer-zh" = {
    source = inputs.humanizer-zh;
    entryFile = "SKILL.md";
  };
  "herdr" = {
    source = inputs.herdr;
    entryFile = "SKILL.md";
  };

  # 目录 skill(整个目录递归)
  "git-workflow" = {
    source = inputs.git-workflow-skill;
  };
  "grill-with-docs" = {
    source = "${inputs.matt-skills}/skills/engineering/grill-with-docs";
  };
  "grilling" = {
    source = "${inputs.matt-skills}/skills/productivity/grilling";
  };
  "domain-modeling" = {
    source = "${inputs.matt-skills}/skills/engineering/domain-modeling";
  };
}
// (lib.genAttrs understandDirs (dir: {
  source = "${inputs.understand-anything}/understand-anything-plugin/skills/${dir}";
}))
