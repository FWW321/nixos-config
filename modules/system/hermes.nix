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
      ZHIPU_API_KEY=${config.sops.placeholder.zhipu_api_key}
      CONTEXT7_API_KEY=${config.sops.placeholder.context7_key}
      FEISHU_APP_ID=${config.sops.placeholder.feishu_hermes_id}
      FEISHU_APP_SECRET=${config.sops.placeholder.feishu_hermes_secret}
      QQ_APP_ID=${config.sops.placeholder.qq_hermes_id}
      QQ_CLIENT_SECRET=${config.sops.placeholder.qq_hermes_secret}
    '';
  };

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    environmentFiles = [
      config.sops.templates."hermes-env".path
    ];
    environment = {
      FEISHU_DOMAIN = "feishu";
      FEISHU_CONNECTION_MODE = "websocket";
    };
    extraPackages = [ pkgs.bun pkgs.brave ];
    extraDependencyGroups = [ "messaging" ];
    extraArgs = [ "run" ];

    settings = {
      model = {
        default = "glm-5.1";
        provider = "custom";
        base_url = "https://open.bigmodel.cn/api/coding/paas/v4";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      compression = {
        enabled = true;
        threshold = 0.50;
        protect_last_n = 20;
        protect_first_n = 3;
      };
      auxiliary = {
        vision = {
          provider = "main";
          model = "glm-4.6v";
        };
        web_extract = {
          provider = "main";
          model = "glm-5.1";
        };
        compression = {
          model = "glm-5.1";
          provider = "main";
        };
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      approvals.mode = "smart";
      display = {
        language = "zh";
        tool_progress = "all";
        platforms.telegram.tool_progress = "verbose";
      };
      streaming = {
        enabled = true;
        transport = "edit";
      };
      checkpoints = {
        enabled = true;
        max_snapshots = 20;
      };
      timezone = "Asia/Shanghai";
      agent = {
        max_turns = 90;
        reasoning_effort = "medium";
      };
      security.redact_secrets = true;
      platform_toolsets = {
        telegram = [ "hermes-telegram" ];
        feishu = [ "hermes-feishu" ];
        qq = [ "hermes-qq" ];
      };
    };

    mcpServers = {
      context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "\${CONTEXT7_API_KEY}";
        enabled = true;
      };
      zread = {
        url = "https://open.bigmodel.cn/api/mcp/zread/mcp";
        headers.Authorization = "Bearer \${ZHIPU_API_KEY}";
        enabled = true;
      };
      web-reader = {
        url = "https://open.bigmodel.cn/api/mcp/web_reader/mcp";
        headers.Authorization = "Bearer \${ZHIPU_API_KEY}";
        enabled = true;
      };
      web-search-prime = {
        url = "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp";
        headers.Authorization = "Bearer \${ZHIPU_API_KEY}";
        enabled = true;
      };
      zai-mcp-server = {
        command = "bunx";
        args = [ "-y" "@z_ai/mcp-server" ];
        env = {
          Z_AI_API_KEY = "\${ZHIPU_API_KEY}";
          Z_AI_MODE = "ZHIPU";
        };
        enabled = true;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes/.hermes/skills/agent-browser 0750 hermes hermes - -"
    "L+ /var/lib/hermes/.hermes/skills/agent-browser/SKILL.md - - - - ${agentBrowserSkill}"
  ];

  environment.variables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.brave}/bin/brave";
}
