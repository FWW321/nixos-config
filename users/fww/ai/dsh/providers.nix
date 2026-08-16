# filepath: ~/nixos-config/users/fww/ai/dsh/providers.nix
# LLM 供应商:ai/common 中立 provider 数据 → dsh llm-pi-ai 用户层路由
# 落盘面(实测 rc.5 源码):settings.yaml `llm-pi-ai.providers` 段 +
# `agent-default-model` 段(默认模型选择;上游无 `models` 命名空间)
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  p = common.providers.zhipu;

  # dsh 模型行:maxOutput(中立)→ maxTokens(dsh);supportsVision 是 catalog
  # 字段,手声明路由不需要
  toDshModel = id: m: {
    inherit id;
    contextWindow = m.contextWindow;
    maxTokens = m.maxOutput;
  };
in
{
  programs.dsh = {
    # 手声明路由:zhipu coding plan 的 anthropic 兼容端点(dsh 走
    # anthropic-messages 线协议,同 Claude Code;模型元数据不进 Nix 之外的
    # 任何 catalog —— common/providers.nix 是唯一数据源)
    providers."zhipu-coding-plan" = {
      apiKeyEnv = "ZHIPU_API_KEY";
      api = "anthropic-messages";
      baseURL = p.endpoints.anthropic;
      models = lib.mapAttrsToList toDshModel p.models;
    };

    # 默认模型选择(typed;渲染进 agent-default-model 命名空间段,
    # schema 实测于源码)
    defaultModel = {
      provider = "zhipu-coding-plan";
      model = p.defaultModel;
    };

    # 常驻 web 服务的凭证:activation 物化 KEY=val 文件(jcode 同模式,
    # sops 原始值不是 EnvironmentFile 格式,须转换;umask 077)
    environmentFiles = [ "${config.xdg.configHome}/deepseek-harness/dsh-env" ];
  };

  # CLI 场景:交互 shell 注入(EXA 同模式;wrapper 运行时读环境变量)
  programs.bash.initExtra = ''
    [ -f ${p.apiKey.secretFile} ] && export ZHIPU_API_KEY="$(cat ${p.apiKey.secretFile})"
  '';

  home.activation.dshProviderEnv =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      _dsh_env="${config.xdg.configHome}/deepseek-harness/dsh-env"
      _key=""
      [ -f ${p.apiKey.secretFile} ] && _key="$(cat ${p.apiKey.secretFile} 2>/dev/null || true)"
      mkdir -p "$(dirname "$_dsh_env")"
      if [ -n "$_key" ]; then
        (umask 077; printf 'ZHIPU_API_KEY=%s\n' "$_key" > "$_dsh_env")
      else
        rm -f "$_dsh_env"
        echo "WARNING: dsh provider env 生成失败(secret 缺失),已移除旧文件" >&2
      fi
    '';
}
