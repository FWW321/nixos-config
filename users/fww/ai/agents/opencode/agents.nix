# filepath: ~/nixos-config/users/fww/ai/agents/opencode/agents.nix
# 子 agent 定义:v2 发现 ~/.config/opencode/agents/<name>.md(路径即 ID)
# Markdown body = system prompt,frontmatter 同 agents.<id> 配置字段
# 参考 https://opencode.ai/v2/docs/agents
#
# 数据来自 common/subagents.nix(意图级:description/model 意图/prompt 单一真源),
# 本文件只做端翻译:frontmatter 渲染 + 端特有字段(extras)。
# 静默漂移防护:description/prompt 改一处多端生效,不再手动同步。
{ pkgs, lib, config, inputs, ... }:

let
  common = import ../../common { inherit pkgs inputs lib config; };

  # common provider 名 → opencode provider id(内置目录名,settings.nix 同源约定)
  providerId = {
    minimax = "minimax-cn-coding-plan";
  };

  # YAML 标量:字符串一律双引号(color 的 # 前缀、描述里的冒号都安全)
  yamlScalar =
    v:
    if lib.isInt v || lib.isBool v then toString v
    else "\"" + lib.strings.escape [ "\"" "\\" ] (toString v) + "\"";

  # 端特有字段(不进 common):mode/color/steps 是 opencode 的调节旋钮
  extras = {
    vision = {
      mode = "subagent";
      color = "#e0a458";
      steps = 12;
    };
  };

  # 意图 → opencode frontmatter md
  renderAgent =
    name: sa: e:
    pkgs.writeText "${name}.md" ''
      ---
      description: ${yamlScalar sa.description}
      mode: ${yamlScalar e.mode}
      model: ${yamlScalar "${providerId.${sa.model.provider}}/${sa.model.model}"}
      color: ${yamlScalar e.color}
      steps: ${toString e.steps}
      ---

      ${sa.prompt}
    '';
in
{
  xdg.configFile = lib.mapAttrs' (
    name: sa:
    lib.nameValuePair "opencode/agents/${name}.md" {
      source = renderAgent name sa (extras.${name} or (throw "opencode agents: ${name} 缺端特有字段定义(extras)"));
    }
  ) common.subagents;
}
