# 通用 MCP(全局启用,环境无关的纯工具)
# defaultEnabled 由 common/default.nix 注入(true),此文件只管数据
{ pkgs, ... }:
{
  context7 = {
    remote = {
      url = "https://mcp.context7.com/mcp";
      secretHeaders.CONTEXT7_API_KEY = "/run/secrets/context7_key";
    };
  };

  "zai-mcp-server" = {
    local = {
      command = "bunx";
      args = [ "-y" "@z_ai/mcp-server" ];
      env = {
        Z_AI_API_KEY.secretFile = "/run/secrets/zhipu_api_key";
        Z_AI_MODE = "ZHIPU";
      };
    };
  };

  "web-search-prime" = {
    remote = {
      url = "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp";
      secretHeaders.Authorization = {
        prefix = "Bearer ";
        secretFile = "/run/secrets/zhipu_api_key";
      };
    };
  };

  "web-reader" = {
    remote = {
      url = "https://open.bigmodel.cn/api/mcp/web_reader/mcp";
      secretHeaders.Authorization = {
        prefix = "Bearer ";
        secretFile = "/run/secrets/zhipu_api_key";
      };
    };
  };

  zread = {
    remote = {
      url = "https://open.bigmodel.cn/api/mcp/zread/mcp";
      secretHeaders.Authorization = {
        prefix = "Bearer ";
        secretFile = "/run/secrets/zhipu_api_key";
      };
    };
  };

  nixos = {
    local = {
      command = "${pkgs.uv}/bin/uvx";
      args = [ "mcp-nixos" ];
    };
  };

  github = {
    local = {
      command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
      args = [ "stdio" "--toolsets" "default,actions,dependabot,notifications" ];
      env.GITHUB_PERSONAL_ACCESS_TOKEN.secretFile = "/run/secrets/github_token";
    };
  };

  codegraph = {
    guide = builtins.readFile ./guides/codegraph.md;
    local = {
      command = "npx";
      args = [ "-y" "@colbymchenry/codegraph" "serve" "--mcp" ];
    };
  };
}
