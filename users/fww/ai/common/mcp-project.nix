# 项目级 MCP(依赖特定技术栈/环境,项目级 agent mcp add 启用)
# defaultEnabled 由 common/default.nix 注入(false)
{ lib, config, ... }:
{
  # Motion AI Kit 官方托管 MCP(https://motion.dev/docs/ai-kit-install)
  # 旧 npx registry.tgz+TOKEN 本地 stdio 流程已废弃;Motion+ 端点鉴权实测支持
  # Bearer token(与 OAuth 等价),复用 /run/secrets/motion_plus_token,无需 OAuth 登录
  motion = {
    remote = {
      url = "https://mcp.motion.dev";
    };
  };
  motion-plus = {
    remote = {
      url = "https://mcp.motion.dev/plus";
      secretHeaders.Authorization = {
        prefix = "Bearer ";
        secretFile = "/run/secrets/motion_plus_token";
      };
    };
  };

  "mcp-server-tauri" = {
    local = {
      command = "npx";
      args = [
        "-y"
        "@hypothesi/tauri-mcp-server"
      ];
    };
  };

  shadcn = {
    local = {
      command = "npx";
      args = [
        "-y"
        "shadcn@latest"
        "mcp"
      ];
    };
  };

  # Open Design stdio MCP → 本机 daemon(设计项目里操作 OD 项目/制品/需求简报)
  # 启动规范与上游 buildMcpInstallPayload 一致:od mcp --daemon-url <url>
  # command/端口/数据目录全部从 services.open-design 派生,与 daemon 配置永不漂移
  open-design = {
    local = {
      command = lib.getExe config.services.open-design.package;
      args = [
        "mcp"
        "--daemon-url"
        "http://127.0.0.1:${toString config.services.open-design.port}"
      ];
      env.OD_DATA_DIR = toString config.services.open-design.dataDir;
    };
  };

  # Blender MCP:AI 建模(opencode ↔ blender-mcp server ↔ Blender 内 addon,TCP 9876)
  # server 出自 blender-cuda 组装件(与 addon 同 derivation,版本构造性一致)。
  # 按名引用(同上 npx 条目先例,PATH 解析):bin/blender-mcp 只随 desktop/
  # blender.nix 的 N 卡门控部署,这里不插值 store path——非 N 卡主机的 HM 闭包
  # 不会被牵进 CUDA 构建。前置:Blender 已启动且 N 面板 Start MCP Server
  "blender-mcp" = {
    local = {
      command = "blender-mcp";
    };
  };

  # Blender Lab 官方 MCP:文档检索与场景分析(捆绑 bpy API/手册 rst,主打
  # "写代码前现查权威文档")。与上面 ahujasid 套件互补而非替代:建模/资产走
  # blender-mcp,查 API/分析场景走这套。server 认 BLENDER_MCP_PORT 连 addon
  # (端口由 blender-cuda 的 SYSTEM_SCRIPTS 启动脚本钉 9877,避开 9876)
  "blender-lab" = {
    local = {
      command = "blender-lab-mcp";
      env.BLENDER_MCP_PORT = "9877";
    };
  };
}
