# filepath: ~/nixos-config/users/fww/ai/dsh/default.nix
# dsh (DeepSeek Harness) 消费配置 —— 目录聚合
#
# 模块来源:nixdsh 独立仓库(flake input nixdsh → homeManagerModules.dsh)
# 分层:package.nix 打包 + lib.nix profile 模型/mkDsh/applyPlugins
#       + hm-module.nix 消费面 + plugins/(dshPlugins registry)
#
# 本目录只留聚合与全局项;settings → settings.nix;profiles → profiles/
{ inputs, ... }:

{
  imports = [
    inputs.nixdsh.homeManagerModules.dsh-status-rotator # per-plugin typed module(按需逐个 import)
    ./providers.nix
    ./settings.nix
    ./search.nix
    ./plugins.nix
    ./profiles.nix
    ./mcp.nix
  ];
  programs.dsh = {
    enable = true;
    # 非交互/headless 调用(dsh "task")需要 profile;web/plugin 子命令自动排除
    defaultProfile = "headless";

    # 常驻 Web UI(open-design 同形态):127.0.0.1:3080,开机自启
    web = {
      enable = true;
      autoStart = true;
    };

    # 只用 zai-ai-cn(手声明 anthropic 路由):llmDeepseek 默认 null(禁,
    # 模型选择器不显示 deepseek 死条目)已是此语义;需要时 llmDeepseek = {} 显式启用

    # API key 等给常驻服务;sops 里尚无 deepseek secret,需要时:
    # environmentFiles = [ config.osConfig.sops.secrets.dsh-env.path ];
  };
}
