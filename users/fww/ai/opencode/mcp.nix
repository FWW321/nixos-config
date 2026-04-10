{ config, pkgs, ... }:

let
  zhipuKey = "/run/secrets/zhipu_api_key";
  context7Key = "/run/secrets/context7_key";
  githubToken = "/run/secrets/github_token";
in
{
  programs.opencode.settings.mcp = {
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
    "motion-studio" = {
      type = "local";
      enabled = true;
      command = [ "npx" "-y" "https://api.motion.dev/registry.tgz?package=motion-studio-mcp&version=latest" ];
      environment.TOKEN = "{file:/run/secrets/motion_plus_token}";
    };
    "mcp-server-tauri" = {
      type = "local";
      enabled = true;
      command = [ "npx" "-y" "@hypothesi/tauri-mcp-server" ];
    };
    "shadcn" = {
      type = "local";
      enabled = true;
      command = [ "npx" "-y" "shadcn@latest" "mcp" ];
    };
    "nixos" = {
      type = "local";
      enabled = true;
      command = [ "${pkgs.uv}/bin/uvx" "mcp-nixos" ];
    };
    "github" = {
      type = "local";
      enabled = true;
      command = [ "${pkgs.github-mcp-server}/bin/github-mcp-server" "stdio" "--toolsets" "default,actions,dependabot,notifications" ];
      environment.GITHUB_PERSONAL_ACCESS_TOKEN = "{file:${githubToken}}";
    };
  };
}
