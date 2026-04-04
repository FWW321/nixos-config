{ config, pkgs, ... }:

let
  zhipuKey = "/run/secrets/zhipu_api_key";
  context7Key = "/run/secrets/context7_key";
in
{
  programs.opencode = {
    enable = true;
    settings = {
      model = "zhipuai-coding-plan/glm-5.1";
      small_model = "zhipuai-coding-plan/glm-5v-turbo";
      provider."zhipuai-coding-plan".options.apiKey = "{file:${zhipuKey}}";
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          headers.CONTEXT7_API_KEY = "{file:${context7Key}}";
          enabled = true;
        };
        "zai-mcp-server" = {
          type = "local";
          enabled = true;
          command = [ "bunx" "-y" "@z_ai/mcp-server" ];
          environment = {
            Z_AI_API_KEY = "{file:${zhipuKey}}";
            Z_AI_MODE = "ZHIPU";
          };
        };
        "web-search-prime" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
        "web-reader" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/web_reader/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
        "zread" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/zread/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
      };
    };
  };
}
