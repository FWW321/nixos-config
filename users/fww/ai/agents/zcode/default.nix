# filepath: ~/nixos-config/users/fww/ai/agents/zcode/default.nix
# zcode 适配器:common 中立层 → programs.zcode 选项(纯数据,零机制)
# 机制见独立仓库 zcode-nix 的 modules/zcode.nix;本文件只做词汇翻译
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../../common { inherit pkgs inputs lib config; };

  # common 端点键 → zcode kind(机械映射;教训见模块 providers.<n>.kind 描述:
  # kind:openai 是 Responses API,zhipu coding 端点须走 openai-compatible)
  kindByEndpoint = {
    anthropic = "anthropic";
    openai = "openai-compatible";
    responses = "openai";
  };
  # 每供应商选哪个端点键(默认 anthropic,如 minimax 主动缓存端点)
  endpointByProvider = {
    zhipu = "openai"; # coding key 须走 chat completions 消耗编程套餐
  };

  # zhipu 主用 BigModel oauth(编程套餐)不注入;恢复 API-key 模式:
  # 删掉下面的 zhipu 排除条件,custom:zhipu 条目随下次 switch 自动重建
  eligible = lib.filterAttrs
    (name: p: (p ? endpoints) && (p ? apiKey) && (p ? models) && name != "zhipu")
    common.providers;

  providers = lib.mapAttrs (name: p:
    let ep = endpointByProvider.${name} or "anthropic";
    in {
      kind = kindByEndpoint.${ep};
      baseURL = p.endpoints.${ep};
      apiKeyFile = p.apiKey.secretFile;
      models = lib.mapAttrs (_: m: {
        context = m.contextWindow;
        output = m.maxOutput;
      }) p.models;
    }) eligible;

  # skill 依赖包(agent-browser 等)走模块 extraPackages,显式声明
  # (此前是蹭 opencode 的 skillPkgs,隐式依赖)
  skillPkgs = lib.catAttrs "package" (
    lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills)
  );

  selectedSkills = lib.filterAttrs (_: s: (s.defaultEnabled or false) && !(s ? runtime))
    common.skills;

  # common skill 形状 → 模块三态:entryFile 单文件 / source 目录
  skills = lib.mapAttrs (_: s:
    if s ? entryFile then "${s.source}/${s.entryFile}" else s.source)
    selectedSkills;

  # common mcp 形状(local/remote) → 模块业界形状(command/url + file 引用)
  mcpServers = lib.mapAttrs (_: m:
    (if m ? local then {
      inherit (m.local) command;
      args = m.local.args or [ ];
      env = lib.mapAttrs (_: v: if v ? secretFile then { file = v.secretFile; } else v)
        (m.local.env or { });
    } else {
      url = m.remote.url;
      headers = lib.mapAttrs (_: h: {
        file = h.secretFile;
        prefix = h.prefix;
      }) (m.remote.secretHeaders or { });
    })
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

    # 识图 subagent(MiniMax M3 原生视觉;glm 无视觉):description 是主模型的
    # 委派路由信号,调整触发词在此改、勿另设他处(与 opencode 侧 vision 对齐)
    agents.vision = {
      description = "识图专用视觉 agent:OCR 转录、报错截图诊断、UI 审查与设计稿对比、图表读数、架构图解读。主模型无视觉,凡图像/截图理解一律委托本 agent";
      model = "custom:custom%3Aminimax:MiniMax-M3";
      # 硬白名单对齐"只读分析者"职责:prompt 约束只是软边界,截图内容本身
      # 可能携带注入,不给 Bash/Edit/Write 等可写工具(官方文档:自定义
      # tools 会一并禁掉 MCP/技能工具 —— 识图场景本就不需要)
      tools = [
        "Read"  # 读取图像文件
        "Glob"  # 按名定位文件
        "Grep"  # 按内容定位文本(图表 CSV 源等)
      ];
      prompt = ''
        你是视觉分析专家。

        职责与准则:

        - **精确转述,不脑补**:只报告图像中确实可见的内容。文字、数字、颜色、布局要逐字/如实引用,不确定就说不确定。
        - **场景适配输出**:
          - 报错截图 → 完整转录错误文本 + 指出关键行
          - UI 截图 → 布局结构、组件状态、异常元素(溢出/遮挡/错位)
          - 图表/数据 → 数值与趋势的精确读数
          - 设计稿对比 → 差异清单,按显著度排序
        - **多图任务**:逐图分析再给汇总,保持图序与指代清晰。
        - **输出语言**跟随用户提问语言;引用界面文字时保留原文,不翻译。
        - 你是只读分析者:不改文件、不跑命令,专注把"看见的"变成"可用的文字"。
      '';
    };
  };
}
