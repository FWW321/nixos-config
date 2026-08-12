# dcg (Destructive Command Guard) — 独立 CLI 工具
# 二进制 + 全局配置,agent 无关(opencode/codex/任何 agent 都通过 stdin JSON 协议调用)
# opencode 的 adapter plugin 链接留在 agents/opencode.nix
{ config, pkgs, lib, inputs, ... }:

let
  common = import ./common { inherit pkgs inputs lib config; };
in
{
  # ── 二进制 ──
  home.packages = [ common.plugins.dcg.package ];

  # ── 全局配置 ──
  # core.filesystem + core.git 永久开启(不可关);system.disk 默认开启,无需列出
  # interactive mode 不适用(dcg-guard.js 设 DCG_ROBOT=1,无 TTY)
  # 被拦截 → dcg allow-once <code> 或 dcg allowlist add <rule> 手动放行
  xdg.configFile."dcg/config.toml".text = ''
    [packs]
    enabled = [
      "database.postgresql",
      "database.mysql",
      "database.sqlite",
      "database.redis",
      "database.mongodb",
      "platform.github",
      "system.permissions",
    ]
  '';
}
