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
  # timeout(2026-09-07):opencode v2 connectTimeout 吃 mcp.timeout,缺省 30s;
  # od mcp 冷启动先做 daemon 健康探测 + 首次调用建观测会话,daemon 忙时
  # (设计 run 进行中)握手可拖过 30s → 客户端记 "failed: Connection closed"。
  # v2 的 failed 状态缓存在常驻服务的项目实例里不自愈(仅配置内容变更或
  # service restart 重连),拉长到 120s 避免误入;同时是工具调用超时,
  # start_run/get_run 轮询本身分钟级,放宽无害(codex 侧 startup_timeout_sec 先例)
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
    timeout = 120000;
  };

  # Blender MCP:AI 建模(opencode ↔ blender-mcp server ↔ Blender 内 addon,TCP 9876)
  # server 出自 blender-cuda 组装件(与 addon 同 derivation,版本构造性一致)。
  # 按名引用(同上 npx 条目先例,PATH 解析):bin/blender-mcp 只随 desktop/
  # blender.nix 的 N 卡门控部署,这里不插值 store path——非 N 卡主机的 HM 闭包
  # 不会被牵进 CUDA 构建。前置:Blender 已启动且 N 面板 Start MCP Server
  #
  # autoApproveAll:codex 侧渲染为 server 级 default_tools_approval_mode="approve"
  # (枚举 auto/prompt/writes/approve,0.147 serde 报错实证)。上游工具全无
  # readOnlyHint → codex 默认逐调用审批,exec/桌面 app 等非交互上下文直接
  # "user cancelled MCP tool call"。server 级优于逐工具清单:上游 bump 新
  # 工具自动覆盖,无清单同步负担(2026-08 桌面端实测踩坑后由逐工具清单泛化)
  "blender-mcp" = {
    local = {
      command = "blender-mcp";
    };
    autoApproveAll = true;
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
    autoApproveAll = true;
  };

  # Godot MCP(Coding-Solo,nixpkgs 收编):AI 游戏开发闭环 —— run_project
  # (-d 调试运行)→ get_debug_output 回流运行时报错 → 修复重跑;场景 CRUD
  # 走 headless GDScript 桥(每操作独立 spawn godot,无编辑器内 addon/端口,
  # 与 blender 双套的 TCP 依赖完全不同源,不存在串行纪律)。文档检索由全局
  # context7 覆盖(godotengine 文档在列),不另设 server —— 对位 blender-lab
  # 的"写代码前现查权威文档"角色。GODOT_PATH 不设:上游探测顺序 PATH 裸名
  # godot 排第一,desktop/godot.nix 同 profile 部署即中(彩排夹具除外,
  # 按名引用避免夹具闭包牵连 1GB 模板,同 blender-mcp 先例)。autoApproveAll
  # 同 blender 双套理由:上游工具无 readOnlyHint,codex 非交互上下文会逐调用
  # 审批直接 "user cancelled"。脚手架 game-init 见 desktop/godot.nix
  "godot-mcp" = {
    local = {
      command = "godot-mcp";
    };
    autoApproveAll = true;
  };
}
