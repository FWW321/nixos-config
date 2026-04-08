{ config, pkgs, ... }:

let
  agentBrowserSkill = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md";
    sha256 = "0m8ai678bl28whp2n3763gzcvr5xyn4kc2fdgkkasq0n3q4wnhdk";
  };
in
{
  sops.templates."hermes-env" = {
    owner = "hermes";
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder.zhipu_api_key}
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder.telegram_bot_token}
      TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.telegram_allowed_users}
    '';
  };

  sops.templates."hermes-config" = {
    owner = "hermes";
    content = ''
      model:
        default: glm-5.1
        provider: custom
        base_url: https://open.bigmodel.cn/api/coding/paas/v4
      terminal:
        backend: local
        timeout: 180
      compression:
        enabled: true
        summary_model: glm-5.1
        summary_provider: main
      auxiliary:
        vision:
          provider: main
          model: glm-4.6v
        web_extract:
          provider: main
          model: glm-5.1
      platform_toolsets:
        telegram: [hermes-telegram]
      mcp_servers:
        context7:
          url: https://mcp.context7.com/mcp
          headers:
            CONTEXT7_API_KEY: ${config.sops.placeholder.context7_key}
          enabled: true
        zread:
          url: https://open.bigmodel.cn/api/mcp/zread/mcp
          headers:
            Authorization: Bearer ${config.sops.placeholder.zhipu_api_key}
          enabled: true
        web-reader:
          url: https://open.bigmodel.cn/api/mcp/web_reader/mcp
          headers:
            Authorization: Bearer ${config.sops.placeholder.zhipu_api_key}
          enabled: true
        web-search-prime:
          url: https://open.bigmodel.cn/api/mcp/web_search_prime/mcp
          headers:
            Authorization: Bearer ${config.sops.placeholder.zhipu_api_key}
          enabled: true
        zai-mcp-server:
          command: bunx
          args:
            - -y
            - '@z_ai/mcp-server'
          env:
            Z_AI_API_KEY: ${config.sops.placeholder.zhipu_api_key}
            Z_AI_MODE: ZHIPU
          enabled: true
    '';
  };

  services.hermes-agent = {
    enable = true;
    configFile = config.sops.templates."hermes-config".path;
    environmentFiles = [
      config.sops.templates."hermes-env".path
    ];
    extraPackages = [ pkgs.bun pkgs.brave ];
    extraArgs = [ "run" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes/.hermes/skills/agent-browser 0750 hermes hermes - -"
    "L+ /var/lib/hermes/.hermes/skills/agent-browser/SKILL.md - - - - ${agentBrowserSkill}"
  ];

  environment.variables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.brave}/bin/brave";
}
