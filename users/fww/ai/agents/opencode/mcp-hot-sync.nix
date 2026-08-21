# filepath: ~/nixos-config/users/fww/ai/agents/opencode/mcp-hot-sync.nix
# ── MCP 免重启热同步:activation 时对账 file 配置 → 运行中服务 ──
# v2 服务启动时加载一次配置即不再读盘,新增 MCP 服务器对运行中服务不可见。
# 热路径:PUT /api/mcp/{name}(实测:立即 connected,{file:} secret 语法生效,
# 不写盘,会话零中断 —— 完整验证记录见 2026-08 会话)。
# 只热加不热删:runtime API 不区分全局/项目级注册,DELETE 会误伤项目级
# mcp add 的条目;删除/同名定义变更场景留给 service restart(见 settings.nix 注释)
{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.activation.syncOpencodeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _sync_oc_mcp() {
      # 服务未运行 → 无漂移(下次启动自然读新配置),绝不顺手拉起
      pgrep -f 'opencode2 serve --service' >/dev/null 2>&1 || return 0
      local oc="${pkgs.opencode2}/bin/opencode2"
      local jq="${pkgs.jq}/bin/jq"
      local cfg="${config.xdg.configHome}/opencode/opencode.json"
      [ -f "$cfg" ] || return 0
      # 运行时已注册名单(空/超时 → 服务僵死,不动它)
      local rt
      rt=$(timeout 10 "$oc" api GET /api/mcp 2>/dev/null | "$jq" -r '.data[].name' 2>/dev/null | sort)
      [ -n "$rt" ] || return 0
      # file 有 && runtime 无 → PUT 热加(disabled:true 的定义也照推,注册不连接,
      # 与重启后语义一致)
      comm -23 <("$jq" -r '.mcp.servers | keys[]' "$cfg" | sort) <(printf '%s\n' "$rt") \
        | while read -r name; do
            def=$("$jq" -c --arg n "$name" '.mcp.servers[$n]' "$cfg")
            body=$("$jq" -cn --argjson d "$def" '{config:$d}')
            timeout 10 "$oc" api PUT "/api/mcp/$name" -d "$body" >/dev/null 2>&1 || true
          done
    }
    _sync_oc_mcp || echo "WARNING: opencode MCP 热同步失败,新增服务器需 service restart 生效"
  '';
}
