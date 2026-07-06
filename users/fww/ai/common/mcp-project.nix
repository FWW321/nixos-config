# 项目级 MCP(依赖特定技术栈/环境,项目级 agent mcp add 启用)
# defaultEnabled 由 common/default.nix 注入(false)
{ ... }:
{
  "motion-studio" = {
    local = {
      command = "npx";
      args = [ "-y" "https://api.motion.dev/registry.tgz?package=motion-studio-mcp&version=latest" ];
      env.TOKEN.secretFile = "/run/secrets/motion_plus_token";
    };
  };

  "mcp-server-tauri" = {
    local = {
      command = "npx";
      args = [ "-y" "@hypothesi/tauri-mcp-server" ];
    };
  };

  shadcn = {
    local = {
      command = "npx";
      args = [ "-y" "shadcn@latest" "mcp" ];
    };
  };
}
