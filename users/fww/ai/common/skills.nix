# 通用 skill(全局启用,工作流/知识类,环境无关)
# defaultEnabled 由 common/default.nix 注入(true),此文件只管数据
#
# 注:skill 注册表是 opencode 服务启动时的快照——新增/删除 skill 目录后
# 新会话/等待/周期刷新都不可见(2026-08 实测:探针 skill 仅 service restart
# 后出现,删目录后运行时仍缓存到下次重启)。与 MCP 不同,skill 无
# PUT/DELETE 运行时注册 API(仅 GET /api/skill 列表 + session 级激活),
# 故 mcp-hot-sync.nix 式热同步无法复刻;变更生效统一走
# `opencode2 service restart`(进行中的工具调用会被中断,属预期)。
{ pkgs, inputs, lib, ... }:
let
  understandDirs = [
    "understand"
    "understand-chat"
    "understand-dashboard"
    "understand-diff"
    "understand-domain"
    "understand-explain"
    "understand-knowledge"
    "understand-onboard"
  ];
in
{
  # 单文件 skill(只取 SKILL.md)
  "agent-browser" = {
    source = "${inputs.agent-browser-skill}/skills/agent-browser";
    entryFile = "SKILL.md";
    package = pkgs.agent-browser;
    env.AGENT_BROWSER_EXECUTABLE_PATH = "brave";
  };
  "humanizer-zh" = {
    source = inputs.humanizer-zh;
    entryFile = "SKILL.md";
  };
  "herdr" = {
    source = "${inputs.herdr}/skills/herdr";
    entryFile = "SKILL.md";
  };
  # 本地 skill(仓库内,非 flake input): pdf-inspector CLI + SKILL.md
  # package 绑 pkgs.pdf-inspector → pdf2md/detect-pdf 进 skill 上下文 PATH
  "pdf-inspector" = {
    source = ../skills/pdf-inspector;
    entryFile = "SKILL.md";
    package = pkgs.pdf-inspector;
  };
  # 本地 skill: MiniMax Token Plan 官方 CLI
  # SKILL.md vendored 自 MiniMax-AI/cli v1.0.19(仅改 Prerequisites 段为 nix 安装说明)
  # package 绑 pkgs.mmx-cli → mmx 进 skill 上下文 PATH
  # 已据此移除 mcp.nix 的 minimax/minimax-media 两个 MCP(见该文件注释)
  "mmx-cli" = {
    source = ../skills/mmx-cli;
    entryFile = "SKILL.md";
    package = pkgs.mmx-cli;
  };
  # 本地 skill: 纯 prompt 写词方法论(songwriter council + 反 cliché 质检门)
  # SKILL.md vendored 自 ChrisWieduwilt/aimusicpreneur(6★但纯文本零依赖,star 信号弱)
  # Suno 段落已适配 mmx(仅 [intro]/[verse]/[chorus]/[bridge]/[outro],人声走 --vocals)
  # 写完词经 mmx music generate --lyrics-file 出音频,与 mmx-cli skill 衔接
  "song-lyrics" = {
    source = ../skills/song-lyrics;
    entryFile = "SKILL.md";
  };
  # 本地 skill: Nix 判断层(工作流约束/防坑),vendored 自 wimpysworld/nix-config(2026-08-19)
  # 适配:mcp-nixos v3 统一接口(nix/nix_versions);补 devenv 优先约束(与全局 AGENTS.md 一致)
  # 与 nixpkgs 分工:nix = 判断/约束层,nixpkgs = 打包 API 参考;包名/选项查证走 mcp.nix 的 nixos
  "nix" = {
    source = ../skills/nix;
    entryFile = "SKILL.md";
  };
  # 本地 skill: nixpkgs 打包参考(callPackage/builders/fetchers/overrides/overlays),
  # vendored 自 Jylhis/claude-marketplace plugins/nix-dev(2026-08-19,属性名均为新式
  # build-system/dependencies/hash 无 legacy 痕迹)
  # 适配:删 OpenCode/codex 均不识别的 frontmatter user-invocable 字段
  "nixpkgs" = {
    source = ../skills/nixpkgs;
    entryFile = "SKILL.md";
  };
  # 目录 skill: NixOS 系统运维(rebuild/generation/装机/disko/LUKS/impermanence/监控/反模式),
  # vendored 自 michalzubkowicz/nixos-management-skill nixos-managing/(2026-08-19,9 文件,
  # SKILL.md 决策表索引 + 8 专题)。适配:mcp-nixos 改为直接用(本环境常驻)
  # 与 nix/nixpkgs 分工:本条 = 系统运维,nix = 判断/约束层,nixpkgs = 打包参考
  "nixos-managing" = {
    source = ../skills/nixos-managing;
  };

  # 目录 skill(整个目录递归)
  # (git-workflow 已移除 2026-08-19:上游无 frontmatter codex 拒载,内容与
  #  git-workflow skill 生态重叠度低,不再维护)
  "grilling" = {
    source = "${inputs.matt-skills}/skills/productivity/grilling";
  };
  "writing-for-agents" = {
    source = "${inputs.matt-skills}/skills/productivity/writing-for-agents";
  };
}
// (lib.genAttrs understandDirs (dir: {
  source = "${inputs.understand-anything}/understand-anything-plugin/skills/${dir}";
}))
