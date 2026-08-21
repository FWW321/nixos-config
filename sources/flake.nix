# 源码引用登记表:全部 flake=false 源码树集中于此,主 flake.nix 只保留
# 一个 sources 入口(path input) —— 源码噪音整体逐出主 flake。
#
# 机制(2026-08-21 lab 三项实测):
#   - 主 flake.lock 完整钉住每个源的 rev(锁图经 sources 节点传递,
#     可复现性不降级)
#   - 主侧 outputs 用 `inputs // sources.pins` 摊平,消费者按原名
#     引用零改动
#   - 更新:nix flake update sources/<name>(单个)/
#     nix flake update sources(全表)
#
# 新增源:在下方 inputs 加一行即可,主 flake.nix 无需改动。
# (flake.nix 求值器只吃字面 attrset,无法在主文件内 mapAttrs 去重
#  —— 结构外移是唯一消音路径)
{
  description = "源码引脚登记表(flake=false source registry)";
  inputs = {
    # AI agent skills → users/fww/ai/common/skills.nix
    shadcn-ui = {
      url = "github:shadcn-ui/ui";
      flake = false;
    }; # shadcn
    surreal-skills = {
      url = "github:24601/surreal-skills";
      flake = false;
    }; # surrealdb
    understand-anything = {
      url = "github:Egonex-AI/Understand-Anything";
      flake = false;
    }; # understand-* (8)
    matt-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    }; # grilling, writing-for-agents
    agent-browser-skill = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    }; # agent-browser
    humanizer-zh = {
      url = "github:op7418/Humanizer-zh";
      flake = false;
    }; # humanizer-zh
    makepad-skills = {
      url = "github:ZhangHanDong/makepad-skills";
      flake = false;
    }; # makepad-* (14)
    # motion-ai-kit 走 ssh:motiondivision org 禁止 >366 天寿命的 fine-grained PAT
    # 访问其 REST API(github: URL 依赖 api.github.com → 403),SSH 协议不受限
    motion-ai-kit = {
      url = "git+ssh://git@github.com/motiondivision/ai-kit";
      flake = false;
    }; # motion skill (→ skills-project.nix)
    # 工具/编辑器
    multicursor-nvim = {
      url = "github:jake-stewart/multicursor.nvim";
      flake = false;
    }; # nvim (→ editor/plugins.nix)
  };
  outputs =
    { self, ... }@ins:
    {
      pins = builtins.removeAttrs ins [ "self" ];
    };
}
