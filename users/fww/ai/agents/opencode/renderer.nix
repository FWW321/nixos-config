# filepath: ~/nixos-config/users/fww/ai/agents/opencode/renderer.nix
# opencode 项目级渲染器(被 agent sync 调用) + ai/registry.json
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../../common { inherit pkgs inputs lib config; };
in
{
  xdg.configFile = {
    "ai/renderers/opencode.sh" = {
      source = pkgs.writeShellScript "opencode-render" ''
        # 契约:$1 = manifest 路径, $2 = 项目根
        # 读 manifest 的 mcp 列表,在项目根 opencode.json 启用(v2:disabled:false override)
        MANIFEST="''${1:-$PWD/.agents/manifest.json}"
        ROOT="''${2:-$PWD}"
        CFG="$ROOT/opencode.json"
        for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
          if [ -f "$CFG" ]; then
            jq --arg n "$name" '.mcp.servers[$n].disabled = false' "$CFG" > tmp && mv tmp "$CFG"
          else
            echo '{"mcp":{"servers":{}}}' | jq --arg n "$name" '.mcp.servers[$n].disabled = false' > "$CFG"
          fi
        done
      '';
      executable = true;
    };
    "ai/registry.json".source = common.project.registry;
  };
}
