# filepath: ~/nixos-config/users/fww/ai/agents/opencode/settings.nix
# opencode v2 核心配置(programs.opencode)
# v2 与 v1 同路径读 ~/.config/opencode/,但字段是 v2 原生后不要再喂给 v1
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../../common { inherit pkgs inputs lib config; };

  p = common.providers.zhipu;

  # opencode 内置 provider 名映射：model id → provider/id（自动从 providers 派生）
  modelMap = lib.mapAttrs (id: _: "zhipuai-coding-plan/${id}") p.models;

  # ── MCP 格式转换：中立 → opencode v2 ──
  # v2:mcp.servers 包一层,enabled 反转为 disabled,timeout 分 catalog/execution
  toOpenCodeHeader = v:
    if builtins.isString v then "{file:${v}}"
    else "${v.prefix}{file:${v.secretFile}}";

  toOpenCodeMcp = _: s:
    if s ? remote then {
      type = "remote";
      disabled = !(s.defaultEnabled or false);
      url = s.remote.url;
      headers = lib.mapAttrs (_: toOpenCodeHeader) (s.remote.secretHeaders or { });
    } else {
      type = "local";
      disabled = !(s.defaultEnabled or false);
      command = [ s.local.command ] ++ (s.local.args or [ ]);
      environment = lib.mapAttrs (_: v:
        if v ? secretFile then "{file:${v.secretFile}}" else v
      ) (s.local.env or { });
    };
in
{
  # ── opencode 核心(v2 包,nixpkgs 未收录,走 pkgs/opencode2) ──
  programs.opencode = {
    enable = true;
    package = pkgs.opencode2;
    settings = {
      # nix store 只读,v2 默认自动装更新必须关掉,版本由 flake 管理
      autoupdate = false;
      model = modelMap.${p.defaultModel};
      # v1 small_model 的 v2 原生位(title 生成用小模型)
      agents.title.model = modelMap.${p.smallModel};
      # v2 字段兼容保留(暂不启动 LSP,后续版本生效)
      lsp = true;
      snapshots = false;
      # websearch 引导(Exa/Firecrawl/Parallel/Tavily)的答案持久化在 opencode.json,
      # 而 opencode.json 是只读 store symlink —— TUI 写下的答案会被 rebuild 抹掉,
      # 引导反复弹出(孤儿 opencode.json.backup 即其残骸)。声明式写死一劳永逸;
      # exa 是四家里唯一有 key 的(EXA_API_KEY 由 bash.initExtra 注入),禁用 random
      # 轮选避免轮到无 key 的三家搜索失败
      websearch.provider = "exa";
      mcp.servers = lib.mapAttrs toOpenCodeMcp common.mcp;
      # glm-5-5.3 已收录 models.dev 目录,仅注入 apiKey,模型元数据用目录内置值
      # v2:provider→providers,options→settings;{file:...} 密钥语法 v2 保留
      providers."zhipuai-coding-plan".settings.apiKey = "{file:${p.apiKey.secretFile}}";
      # MiniMax Token Plan 同理:内置目录 minimax-cn-coding-plan(minimaxi.com 国内
      # 订阅版,勿混国际版 minimax-coding-plan);/model 切换用,默认仍是 glm
      providers."minimax-cn-coding-plan".settings.apiKey =
        "{file:${common.providers.minimax.apiKey.secretFile}}";
      # herdr 插件暂不启用(beta-17577 三坑:本地插件不能 import @opencode-ai/plugin、
      # v2 复数键 plugins 令 server 无声崩溃循环只能用 v1 单数键 plugin、
      # 自动发现不生效;且带 HERDR env 的 service 模式有 boot loop 疑似 bug)。
      # 移植版已备好在 agents/opencode-plugins/,stable 后启用下面两行并复检:
      # plugin = [ "./plugins/herdr-agent-state.js" ];
      #
      # ⚠ v2 是常驻后台服务(serve --service)架构,MCP 配置仅启动时加载一次,不重读磁盘。
      # 新增服务器已由 mcp-hot-sync.nix 免重启热同步(PUT /api/mcp,
      # 实测含 {file:} secret 语法均生效,会话零中断);
      # 删除/同名定义变更仍需手动 `opencode2 service restart`(不做热删:runtime API
      # 不区分全局/项目级注册,DELETE 可能误伤项目级 mcp add 的条目)
    };
  };
}
