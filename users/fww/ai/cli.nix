# agent 命令:项目级 AI 资源管理(add/sync/remove/list)
# 读项目根 .agents/manifest.json + ~/.config/ai/registry.json
# sync 三步:① 通用 skill symlink → .agents/skills/  ② 各 agent mcp 渲染器  ③ AGENTS.md managed section
{ config, pkgs, lib, inputs, ... }:
let
  common = import ./common { inherit pkgs inputs lib config; };
  skillRender = common.project.skillRender;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "agent" ''
      CMD="''${1:-}"
      shift || true
      MANIFEST="''${MANIFEST:-$PWD/.agents/manifest.json}"
      REG="''${XDG_CONFIG_HOME:-$HOME/.config}/ai/registry.json"
      REND="''${XDG_CONFIG_HOME:-$HOME/.config}/ai/renderers"

      ensure_manifest() {
        mkdir -p "$(dirname "$MANIFEST")"
        [ -f "$MANIFEST" ] || echo '{"skills":[],"mcp":[]}' > "$MANIFEST"
      }

      # 同名聚合:registry 里 skill 和 mcp 都有就都加
      add_to_manifest() {
        local name="$1" type="$2"
        ensure_manifest
        jq --arg n "$name" --arg t "$type" \
          'if $t == "skill" then .skills = ((.skills // []) + [$n] | unique)
           else .mcp = ((.mcp // []) + [$n] | unique) end' \
          "$MANIFEST" > tmp && mv tmp "$MANIFEST"
      }

      del_from_manifest() {
        local name="$1"
        [ -f "$MANIFEST" ] || return 0
        jq --arg n "$name" \
          '.skills = ((.skills // []) - [$n]) | .mcp = ((.mcp // []) - [$n])' \
          "$MANIFEST" > tmp && mv tmp "$MANIFEST"
      }

      sync_all() {
        echo "[agent] syncing $PWD ..."
        # ① 通用 skill symlink → .agents/skills/(三 agent 共读)
        ${skillRender} "$MANIFEST" "$PWD"
        # ② 各 agent mcp 渲染器(遍历 ~/.config/ai/renderers/*.sh)
        if [ -d "$REND" ]; then
          for r in "$REND"/*.sh; do
            [ -x "$r" ] && "$r" "$MANIFEST" "$PWD"
          done
        fi
        # ③ AGENTS.md managed section(聚合 manifest 资源的 guide)
        update_managed_section
        echo "[agent] sync done."
      }

      update_managed_section() {
        local agentsmd="$PWD/AGENTS.md"
        [ -f "$agentsmd" ] || { echo "[agent] no AGENTS.md, skip managed section"; return 0; }
        [ -f "$REG" ] || { echo "[agent] no registry, skip managed section"; return 0; }

        # 从 registry 收集 manifest 里资源的 guide
        local guides=""
        local names
        names=$(jq -r '(.mcp // []) + (.skills // []) | .[]' "$MANIFEST" 2>/dev/null)
        for name in $names; do
          g=$(jq -r --arg n "$name" \
            '(.mcp[$n].guide // .skills[$n].guide) // empty' "$REG" 2>/dev/null)
          [ -n "$g" ] && guides="$guides$g"$'\n'
        done

        # 无 managed 区块则追加;有则替换区块内容(区块外手写内容不动)
        if ! grep -q '<!-- ai:managed -->' "$agentsmd"; then
          {
            printf '\n<!-- ai:managed -->\n'
            printf '<!-- 由 agent sync 自动生成,勿手改 -->\n'
            printf '%s' "$guides"
            printf '<!-- /ai:managed -->\n'
          } >> "$agentsmd"
        else
          awk -v g="$guides" '
            /<!-- ai:managed -->/ { print; inb=1; if (length(g)>0) print g; next }
            /<!-- \/ai:managed -->/ { inb=0 }
            !inb { print }
          ' "$agentsmd" > tmp && mv tmp "$agentsmd"
        fi
      }

      case "$CMD" in
        add)
          NAME="''${1:-}"
          [ -z "$NAME" ] && { echo "usage: agent add <name>"; exit 1; }
          HAS_SKILL=$(jq -r --arg n "$NAME" '(.skills[$n] // null) != null' "$REG" 2>/dev/null)
          HAS_MCP=$(jq -r --arg n "$NAME" '(.mcp[$n] // null) != null' "$REG" 2>/dev/null)
          if [ "$HAS_SKILL" != "true" ] && [ "$HAS_MCP" != "true" ]; then
            echo "[agent] '$NAME' not in registry"; exit 1
          fi
          [ "$HAS_SKILL" = "true" ] && add_to_manifest "$NAME" skill
          [ "$HAS_MCP" = "true" ] && add_to_manifest "$NAME" mcp
          sync_all ;;
        skill)
          SUB="''${1:-}"; NAME="''${2:-}"
          case "$SUB" in
            add) add_to_manifest "$NAME" skill; sync_all ;;
            remove) del_from_manifest "$NAME"; sync_all ;;
            *) echo "usage: agent skill add|remove <name>"; exit 1 ;;
          esac ;;
        mcp)
          SUB="''${1:-}"; NAME="''${2:-}"
          case "$SUB" in
            add) add_to_manifest "$NAME" mcp; sync_all ;;
            remove) del_from_manifest "$NAME"; sync_all ;;
            *) echo "usage: agent mcp add|remove <name>"; exit 1 ;;
          esac ;;
        remove)
          NAME="''${1:-}"
          del_from_manifest "$NAME"; sync_all ;;
        sync)
          sync_all ;;
        list)
          [ -f "$MANIFEST" ] && jq '.' "$MANIFEST" || echo "no manifest at $MANIFEST" ;;
        ""|-h|--help)
          cat <<'EOF'
agent - 项目级 AI 资源管理
usage:
  agent add <name>         同名聚合 skill+mcp
  agent skill add <name>   只加 skill
  agent skill remove <name>
  agent mcp add <name>     只加 mcp
  agent mcp remove <name>
  agent remove <name>      同名移除
  agent sync               重建本地状态(symlink + 渲染 + managed section)
  agent list               显示当前 manifest
EOF
          ;;
        *)
          echo "unknown command: $CMD (try --help)"; exit 1 ;;
      esac
    '')
  ];
}
