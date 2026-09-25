# filepath: ~/nixos-config/users/fww/ai/agents/opencode/settings.nix
# opencode v2 核心配置(programs.opencode)
# v2 与 v1 同路径读 ~/.config/opencode/,但字段是 v2 原生后不要再喂给 v1
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  common = import ../../common {
    inherit
      pkgs
      inputs
      lib
      config
      ;
  };

  p = common.providers.zhipu;

  # opencode 内置 provider 名映射：model id → provider/id（自动从 providers 派生）
  modelMap = lib.mapAttrs (id: _: "zhipuai-coding-plan/${id}") p.models;

  # ── MCP 格式转换：中立 → opencode v2 ──
  # v2:mcp.servers 包一层,enabled 反转为 disabled,timeout 分 catalog/execution
  toOpenCodeHeader =
    v: if builtins.isString v then "{file:${v}}" else "${v.prefix}{file:${v.secretFile}}";

  toOpenCodeMcp =
    _: s:
    if s ? remote then
      {
        type = "remote";
        disabled = !(s.defaultEnabled or false);
        url = s.remote.url;
        headers = lib.mapAttrs (_: toOpenCodeHeader) (s.remote.secretHeaders or { });
      }
    else
      {
        type = "local";
        disabled = !(s.defaultEnabled or false);
        command = [ s.local.command ] ++ (s.local.args or [ ]);
        environment = lib.mapAttrs (_: v: if v ? secretFile then "{file:${v.secretFile}}" else v) (
          s.local.env or { }
        );
        # 中立层的 timeout(ms)v2 stable 全系拒收(2.0.11~2.0.16 实测,带此键的
        # server 整条被 schema 丢弃,2026-09-25 open-design MCP 静默失踪根因);
        # dev 线 schema 已重新收录 —— stable 恢复时 opencode2-mcp 检查红灯提醒,
        # 届时恢复渲染(见 common/mcp-project.nix open-design 注释)
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

      # ── 权限:放行 /tmp 外部目录(2026-08-30) ──
      # v2 permissions 为有序规则数组,last match wins,未匹配默认 ask。
      # /tmp 在项目 Location 之外 → external_directory 边界默认 ask,agent 每次
      # 读写 /tmp 都弹审批;底层 read/edit 默认本就 allow,只补边界层这一条。
      # 全局规则追加于 agent 默认之后,对 build/plan/explore/子 agent 全体生效。
      # /tmp/* 的 * 含 / 但全值匹配不覆盖 /tmp 自身,故两条;显式外部路径先
      # canonicalize 再匹配,/tmp 下指向敏感位置的软链会解析回真实路径落回
      # ask,不被此规则绕过(shell 命令内嵌路径不归本层管,仅 best-effort 警告)。
      # 注:上游自管临时目录 /tmp/opencode 本就豁免,这里放行的是通用 /tmp;
      # 生效需 opencode2 service restart(常驻服务启动读一次配置)
      permissions = [
        {
          action = "external_directory";
          resource = "/tmp";
          effect = "allow";
        }
        {
          action = "external_directory";
          resource = "/tmp/*";
          effect = "allow";
        }
      ];

      # ── 上下文机制(v2 与 codex 完全不同,2026-08 调研;全部不设吃默认)──
      # 窗口来源:models.dev 目录内置 limit.context(glm-5.3 走 zhipuai-coding-plan
      # 目录条目;providers.nix 的 contextWindow=1000000 仅喂 codex 静态目录,本侧
      # 不消费)。目录错值/自定义模型可覆盖:providers.<id>.models.<mid>.limit.context
      # 自动压缩触发 = 估算 tokens > limit.context − max(请求 output, buffer);
      # 估算 = 请求 JSON 序列化字节/4,粗略。provider 报 context overflow 时还有
      # 一次性压缩重试兜底(auto=false 也生效,最多一次防循环)
      # 可调项(compaction.*):auto=true / keep.tokens=15000(压缩时逐字保留的最近
      # 上下文预算,tool 输出截 2000 字符)/ buffer=20000(触发前预留余量,调大
      # 即更早压缩)。无绝对阈值字段(codex 的 model_auto_compact_token_limit
      # 等价物不存在,anomalyco/opencode#27706 在要 trigger_at;提前触发只能加大
      # buffer,或调小 providers.models.limit.context 的覆盖值)

      # websearch 引导(Exa/Firecrawl/Parallel/Tavily)的答案持久化在 opencode.json,
      # 而 opencode.json 是只读 store symlink —— TUI 写下的答案会被 rebuild 抹掉,
      # 引导反复弹出(孤儿 opencode.json.backup 即其残骸)。声明式写死一劳永逸;
      # exa 是四家里唯一有 key 的(EXA_API_KEY 由 bash.initExtra 注入),禁用 random
      # 轮选避免轮到无 key 的三家搜索失败
      websearch.provider = "exa";
      mcp.servers = lib.mapAttrs toOpenCodeMcp common.mcp;
      # glm-5-5.3 已收录 models.dev 目录,仅注入 apiKey,模型元数据用目录内置值
      # v2:provider→providers,options→settings;{file:...} 密钥语法 v2 保留
      providers."zhipuai-coding-plan" = {
        settings.apiKey = "{file:${p.apiKey.secretFile}}";
        # glm-5.3-flash(2026-08-26 发布)models.dev 目录尚未收录(beta-18286
        # 当日缓存仍无此条目)→ 本地补模型元数据:/models 可选 + limit.context
        # 供自动压缩触发(缺省 = context 0,压缩永不触发,长会话静默溢出)。
        # 字段为 v2 config schema 模型条目的合法闭集(additionalProperties
        # false);目录收录后本块删除,与 glm-5.3 同策略(仅留 apiKey)
        models."glm-5.3-flash" = {
          name = "GLM-5.3-Flash";
          attachment = true; # 多模态输入开关(对齐目录里 glm-5v-turbo 的标法)
          reasoning = true; # 思考常开(端点强制,目录里 glm-5.3 同为 true)
          tool_call = true;
          modalities = {
            input = [
              "text"
              "image"
              "video"
              "pdf"
            ];
            output = [ "text" ];
          };
          limit = {
            context = 1000000;
            output = 131072;
          };
        };
      };
      # MiniMax Token Plan 同理:内置目录 minimax-cn-coding-plan(minimaxi.com 国内
      # 订阅版,勿混国际版 minimax-coding-plan);/model 切换用,默认仍是 glm
      providers."minimax-cn-coding-plan".settings.apiKey =
        "{file:${common.providers.minimax.apiKey.secretFile}}";
      # MiMo Token Plan(国内 cn 集群):内置目录 xiaomi-token-plan-cn,baseURL
      # token-plan-cn.xiaomimimo.com/v1 与 providers.nix 一致(opencode.db 目录
      # 缓存核对,2026-09-24);与按量 xiaomi 条目(api.xiaomimimo.com)是两个
      # provider,勿混;/model 切换用
      providers."xiaomi-token-plan-cn".settings.apiKey =
        "{file:${common.providers.mimo.apiKey.secretFile}}";
      # StepFun Step Plan:内置目录 stepfun-step-plan,baseURL
      # api.stepfun.com/step_plan/v1 与 providers.nix 一致(同上核对);
      # 与按量 stepfun 条目同理勿混;/model 切换用
      providers."stepfun-step-plan".settings.apiKey =
        "{file:${common.providers.stepfun.apiKey.secretFile}}";
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
