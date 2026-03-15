{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      user_password.neededForUsers = true;
      opencode_api_key.owner = "fww";
      opencode_context7_key.owner = "fww";
    };
    templates."opencode/opencode.json" = {
      owner = "fww";
      content = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        model = "zhipuai-coding-plan/glm-5";
        small_model = "zhipuai-coding-plan/glm-4.7";
        provider."zhipuai-coding-plan".options.apiKey = config.sops.placeholder.opencode_api_key;
        mcp = {
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp";
            headers.CONTEXT7_API_KEY = config.sops.placeholder.opencode_context7_key;
            enabled = true;
          };
          "zai-mcp-server" = {
            type = "local";
            enabled = true;
            command = [
              "bunx"
              "-y"
              "@z_ai/mcp-server"
            ];
            environment = {
              Z_AI_API_KEY = config.sops.placeholder.opencode_api_key;
              Z_AI_MODE = "ZHIPU";
            };
          };
          "web-search-prime" = {
            type = "remote";
            enabled = true;
            url = "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp";
            headers.Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
          };
          "web-reader" = {
            type = "remote";
            enabled = true;
            url = "https://open.bigmodel.cn/api/mcp/web_reader/mcp";
            headers.Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
          };
          "zread" = {
            type = "remote";
            enabled = true;
            url = "https://open.bigmodel.cn/api/mcp/zread/mcp";
            headers.Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
          };
        };
      };
    };
  };
}
