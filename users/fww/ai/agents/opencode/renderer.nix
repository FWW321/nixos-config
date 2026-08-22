# filepath: ~/nixos-config/users/fww/ai/agents/opencode/renderer.nix
# opencode 项目级渲染器(被 agent sync 调用) + ai/registry.json
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
in
{
  xdg.configFile = {
    "ai/renderers/opencode.sh" = {
      source = pkgs.writeShellScript "opencode-render" ''
        # 契约:$1 = manifest 路径, $2 = 项目根
        # 读 manifest 的 mcp 列表,把全局定义(nix 渲染的完整 server def,单一真源)
        # 以 disabled:false 写入项目根 opencode.json。
        # ⚠ 必须写完整定义,不能只写 {"disabled":false} 残体:opencode v2 schema
        # 校验对缺 type/command 的 server 条目整层丢弃(2026-08-23 test 项目实测:
        # 残体致 debug config 项目层 .info={},会话永远只见全局;runtime PUT API
        # 绕过 schema 所以当时"看起来能通")——项目文件必须自包含
        MANIFEST="''${1:-$PWD/.agents/manifest.json}"
        ROOT="''${2:-$PWD}"
        CFG="$ROOT/opencode.json"
        GLOBAL="${config.xdg.configHome}/opencode/opencode.json"
        [ -f "$GLOBAL" ] || { echo "[opencode-render] no global config, skip"; exit 0; }
        for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
          def=$(jq -c --arg n "$name" '.mcp.servers[$n] // empty' "$GLOBAL")
          [ -n "$def" ] || { echo "[opencode-render] '$name' not in global config, skip"; continue; }
          if [ -f "$CFG" ]; then
            jq --arg n "$name" --argjson d "$def" \
              '.mcp.servers[$n] = ($d + {disabled:false})' "$CFG" > tmp && mv tmp "$CFG"
          else
            jq -n --arg n "$name" --argjson d "$def" \
              '{mcp:{servers:{($n):($d + {disabled:false})}}}' > "$CFG"
          fi
        done
      '';
      executable = true;
    };
    "ai/registry.json".source = common.project.registry;
  };
}
