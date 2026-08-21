# 通用 MCP(全局启用,环境无关的纯工具)
# defaultEnabled 由 common/default.nix 注入(true),此文件只管数据
{ pkgs, ... }:
{
  # context7 走本地 stdio 官方 server(opencode 侧,2026-08-19):
  # opencode2 二进制内嵌 Bun main 预发布版(自报 v1.4.0,npm 无此版),其 fetch 对
  # mcp.context7.com(AWS ELB,Amazon ECDSA-384 cross-signed 链)必现
  # "unknown certificate verification error";同机 curl/node/bun 1.3.13 全正常,
  # NODE_USE_SYSTEM_CA/NODE_EXTRA_CA_CERTS 无效 —— Bun 把握手期连接重置也统一
  # 打成证书错误标签(oven-sh/bun#31950)。同日 beta-17570~17595 同源 Bun,
  # 升级无解 → npx 起 @upstash/context7-mcp(Node TLS)绕开;opencode 换修好的
  # Bun 后可改回 remote(url https://mcp.context7.com/mcp + secretHeaders)。
  # codex 侧本就 mcpExcluded 不受影响;npx 冷启动 ~2s,服务常驻只付一次
  context7 = {
    local = {
      command = "npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
      env.CONTEXT7_API_KEY.secretFile = "/run/secrets/context7_key";
    };
  };

  # 智谱识图 MCP(@z_ai/mcp-server)已停用(2026-08,条目注释保留待恢复):
  # 8 个工具 = GLM 视觉模型 + 场景化 prompt 模板,静态识图已双覆盖 ——
  # opencode 走 vision subagent(MiniMax-M3 原生视觉,见 agents/opencode/
  # agents.nix,其 frontmatter description 即主模型的委派路由信号),
  # 各 agent 可用 mmx-cli skill(mmx vision describe,Token Plan 包干)兜底;
  # 本条按量计费,且 codex 侧因 bunx 冷启动排除(恢复时须同步改 codex.nix
  # mcpExcluded,加入 "zai-mcp-server")
  # - 唯一独占 analyze_video(≤8MB)随之退役:M3 视频输入未实测,需要时取消注释
  # - dsh 无 subagent 机制,识图回落 mmx vision describe;
  #   zhipu_api_key 继续服务下方 web-search-prime/web-reader/zread
  #
  # "zai-mcp-server" = {
  #   local = {
  #     command = "bunx";
  #     args = [ "-y" "@z_ai/mcp-server" ];
  #     env = {
  #       Z_AI_API_KEY.secretFile = "/run/secrets/zhipu_api_key";
  #       Z_AI_MODE = "ZHIPU";
  #     };
  #   };
  # };

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
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };

  # MiniMax MCP(minimax/minimax-media)已移除(2026-08):
  # 全模态生成/搜索/看图改走 mmx-cli skill(见 skills.nix "mmx-cli",music-3.0 级模型)
  # - opencode:智谱栈(search)+ mmx 双覆盖(vision 后移交 vision subagent,见上方识图 MCP 注释)
  # - codex:原生 web_search 工具 + 多模态贴图;沙箱 shell 无网络,mmx 跑不了,
  #   媒体生成从 codex 侧放弃(需要时 curl API 或恢复此条目)
  # - voice_clone/voice_design 无 mmx 等价,随 minimax-media 一并移除,按需恢复

  github = {
    local = {
      command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
      args = [
        "stdio"
        "--toolsets"
        "default,actions,dependabot,notifications"
      ];
      env.GITHUB_PERSONAL_ACCESS_TOKEN.secretFile = "/run/secrets/github_token";
    };
  };
}
