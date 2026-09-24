# filepath: ~/nixos-config/users/fww/ai/agents/zcode/default.nix
# zcode 适配器:common 中立层 → programs.zcode 选项(纯数据,零机制)
# 机制见独立仓库 zcode-nix 的 modules/zcode.nix;本文件只做词汇翻译
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

  # common 端点键 → zcode kind(机械映射;教训见模块 providers.<n>.kind 描述:
  # kind:openai 是 Responses API,zhipu coding 端点须走 openai-compatible)
  kindByEndpoint = {
    anthropic = "anthropic";
    openai = "openai-compatible";
    responses = "openai";
  };
  # zcode 的 OAuth 槽位与目录模型词汇(2026-08-26 实测:v2/config.json 的
  # builtin:bigmodel-coding-plan.enabled=true + app.asar decodeCustomModelValue):
  # agent model 引用格式 = custom:<enc(providerId)>:<enc(modelId)>,providerId
  # 可为 builtin:*;OAuth 目录 id 是大写显示名,与 API 小写 id 不同词
  oauthZhipu = {
    slot = "builtin:bigmodel-coding-plan"; # 编程套餐槽(GUI 已启用)
    modelIds = {
      "glm-5.3" = "GLM-5.3";
      "glm-5.3-flash" = "GLM-5.3-Flash";
      "glm-5-turbo" = "GLM-5-Turbo";
      "glm-5.2" = "GLM-5.2";
    };
  };

  # 中立层 {provider, model} → zcode 引用串:zhipu 走 OAuth builtin 槽位,
  # 其余供应商走 custom 注入条目(下方 eligible)。未收录的 zhipu 模型
  # 显式炸在 eval(静默漂移无报错的对账原则,幽灵引用宁可编译期死)
  toZcodeModel =
    prov: mid:
    if prov == "zhipu" then
      let
        oid =
          oauthZhipu.modelIds.${mid}
            or (throw "zcode agents: ${prov}/${mid} 不在 oauthZhipu.modelIds(OAuth 目录词汇见 v2/config.json)");
      in
      "custom:" + lib.strings.escapeURL oauthZhipu.slot + ":" + lib.strings.escapeURL oid
    else
      "custom:" + lib.strings.escapeURL "custom:${prov}" + ":${mid}";

  # 每供应商选哪个端点键(默认 anthropic,如 minimax 主动缓存端点)
  endpointByProvider = {
    zhipu = "openai"; # coding key 须走 chat completions 消耗编程套餐
  };

  # zhipu 主用 BigModel oauth(编程套餐)不注入 —— OAuth 原生目录已含
  # GLM-5.3/GLM-5.3-Flash,subagents 的 zhipu 引用由 toZcodeModel 翻译成
  # builtin 槽位引用,不经 custom:*;恢复 API-key 模式:删掉下面的
  # zhipu 排除条件,custom:zhipu 条目随下次 switch 自动重建
  # minimax 曾因"内置模板 baseURL 一致"改走 GUI(2026-09-24),同日推翻:
  # 上游 catalog 对 MiniMax 全系 8 模型 reasoning 全 null,内置路
  # thoughtLevel 一样被吞(resolveRegistryThoughtLevel 静默忽略,源码
  # 三级实证);zcode-nix 1e8a5d5 落地双通道 reasoning 注入后恢复
  # custom —— apiKey 也回归 nix 接管,GUI 手填作废
  # mimo 不走内置另有硬伤:xiaomi-mimo 模板是按量端点
  # (api.xiaomimimo.com/anthropic ≠ token-plan-cn 域)且模型停在 v2.5 系,
  # token plan 的 tp- key 在按量端点不通用(官方 FAQ),必须 custom
  # schema 后键恒在:models 未声明 = {},apiKey 未声明 = null
  # (旧 `?` 存在性探测会恒真)
  eligible = lib.filterAttrs (
    name: p: p.models != { } && p.apiKey.secretFile != null && name != "zhipu"
  ) common.providers;

  # 中立思考档 → zcode CEL 方言(zcode-nix reasoning.map,agent 通道经
  # provider_config.json personal 规则注入):受限 CEL(asar
  # compileModelOptionMap 实证:三元/比较/对象字面量,返回值须为 JSON
  # object,{} 合法 = 不发参数),变量 reasoningLevel = 档名。
  # 值放 thinking.type 还是 output_config.effort 是端点协议方言,无法从
  # providers.nix levels 机械推导,按供应商显式声明(与 endpointByProvider
  # 同风格);新增供应商带思考档时必须同步补条目,缺失者 models 翻译处
  # throw(静默漂移防线)
  thoughtMapByProvider = {
    # M3 anthropic 端点:off=不发参数、on=thinking.type adaptive,无
    # effort 档(providers.nix 官方文档+实测)。曾建议先试 GLM 条
    # (adaptive + output_config.effort)—— 那会把 effort:"off"/"on" 发给
    # 不认 effort 的 M3 端点;若本条实测 400 再按需调整
    minimax = ''reasoningLevel == "on" ? {"thinking":{"type":"adaptive"}} : {}'';
    # v2.6 anthropic 端点纯开关:thinking.type enabled/disabled;off 档
    # 显式发 disabled(官方支持,与 M3 的"不发参数"不同)
    mimo = ''{"thinking":{"type":reasoningLevel == "on" ? "enabled" : "disabled"}}'';
    # step-5-preview anthropic 端点三档:output_config.effort(官方
    # Messages API 文档),档名与 wire 值恒等
    stepfun = ''{"output_config":{"effort":reasoningLevel}}'';
  };

  providers = lib.mapAttrs (
    name: p:
    let
      ep = endpointByProvider.${name} or "anthropic";
    in
    {
      kind = kindByEndpoint.${ep};
      baseURL = p.endpoints.${ep};
      apiKeyFile = p.apiKey.secretFile;
      models = lib.mapAttrs (
        _: m:
        let
          t = m.thinking.${ep};
        in
        {
          context = m.contextWindow;
          output = m.maxOutput;
        }
        // (lib.optionalAttrs (t != null) {
          # zcode-nix 语义:levels 末位 = 默认档(defaultLevel = values.at(-1)),
          # 把 providers.nix 的 default 档挪到末位,其余保持声明序
          reasoning = {
            levels = lib.remove t.default (builtins.attrNames t.levels) ++ [ t.default ];
            map =
              thoughtMapByProvider.${name}
                or (throw "zcode providers: ${name} 声明了 thinking.${ep} 但缺 CEL 方言(thoughtMapByProvider)");
          };
        })
      ) p.models;
    }
  ) eligible;

  # skill 依赖包(agent-browser 等)走模块 extraPackages,显式声明
  # (此前是蹭 opencode 的 skillPkgs,隐式依赖)
  skillPkgs = lib.catAttrs "package" (
    lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills)
  );

  selectedSkills = lib.filterAttrs (
    _: s: (s.defaultEnabled or false) && !(s ? runtime)
  ) common.skills;

  # common skill 形状 → 模块三态:entryFile 单文件 / source 目录
  skills = lib.mapAttrs (
    _: s: if s ? entryFile then "${s.source}/${s.entryFile}" else s.source
  ) selectedSkills;

  # common mcp 形状(local/remote) → 模块业界形状(command/url + file 引用)
  mcpServers = lib.mapAttrs (
    _: m:
    (
      if m ? local then
        {
          inherit (m.local) command;
          args = m.local.args or [ ];
          env = lib.mapAttrs (_: v: if v ? secretFile then { file = v.secretFile; } else v) (
            m.local.env or { }
          );
        }
      else
        {
          url = m.remote.url;
          headers = lib.mapAttrs (_: h: {
            file = h.secretFile;
            inherit (h) prefix;
          }) (m.remote.secretHeaders or { });
        }
    )
    // (lib.optionalAttrs (!(m.defaultEnabled or true)) { enabled = false; })
  ) common.mcp;
in
{
  programs.zcode = {
    enable = true;
    agentsMd = common.project.globalAgentsMd;
    extraPackages = skillPkgs;
    inherit providers skills;
    mcp.servers = mcpServers;

    # 识图子 agent:核心定义在 common/subagents.nix(与 opencode 同源);
    # model 意图 → zcode 引用格式见 toZcodeModel(zhipu 走 OAuth builtin 槽,
    # 其余走 custom:<urlencoded>)
    # thoughtLevel = 中立思考档透传:zcode 目录 variants(config.json glm
    # low/max/high)与 providers.nix 中立档名同词,透传即正确;仅显式
    # model 下生效(vision 已设)。custom 注入供应商的档位自 zcode-nix
    # 1e8a5d5 起由 providers.<n>.models.<m>.reasoning 双通道注入支撑
    # (GUI 侧 variants + agent 侧 CEL map,见上方 thoughtMapByProvider)
    # tools 硬白名单是 zcode 端能力(自定义 tools 连 MCP/技能工具一并禁),
    # 对齐"只读分析者"职责:prompt 约束只是软边界,截图可能携带注入,
    # 不给 Bash/Edit/Write 等可写工具
    # injectAgentsMd=false:AGENTS.md 全是写行为纪律(Read 前置/Edit 增量/
    # devenv/测试指南),对零写工具的只读转述者 0% 适用 —— 注入只剩
    # token 成本与注意力噪声(zcode v3.7.1 起默认注入,显式关)
    agents.vision = {
      inherit (common.subagents.vision) description prompt;
      model = toZcodeModel common.subagents.vision.model.provider common.subagents.vision.model.model;
      thoughtLevel = common.subagents.vision.thinking;
      injectAgentsMd = false;
      tools = [
        "Read" # 读取图像文件
        "Glob" # 按名定位文件
        "Grep" # 按内容定位文本(图表 CSV 源等)
      ];
    };
  };
}
