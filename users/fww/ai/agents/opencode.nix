# opencode agent — 完全自包含
# 从 common 拉取数据，内联转换为 opencode 格式
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  # ── 全局 skill:defaultEnabled = true 的(通用),特殊的走项目级 agent skill add ──
  selectedSkills = lib.filterAttrs (_: s: (s.defaultEnabled or false) && !(s ? runtime))
    common.skills;

  p = common.providers.zhipu;

  # opencode 内置 provider 名映射
  modelMap = {
    "glm-5.2" = "zhipuai-coding-plan/glm-5.2";
    "glm-5.1" = "zhipuai-coding-plan/glm-5.1";
  };

  # ── MCP 格式转换：中立 → opencode ──
  toOpenCodeHeader = v:
    if builtins.isString v then "{file:${v}}"
    else "${v.prefix}{file:${v.secretFile}}";

  toOpenCodeMcp = _: s:
    if s ? remote then {
      type = "remote";
      enabled = s.defaultEnabled or false;
      url = s.remote.url;
      headers = lib.mapAttrs (_: toOpenCodeHeader) (s.remote.secretHeaders or { });
    } else {
      type = "local";
      enabled = s.defaultEnabled or false;
      command = [ s.local.command ] ++ (s.local.args or [ ]);
      environment = lib.mapAttrs (_: v:
        if v ? secretFile then "{file:${v.secretFile}}" else v
      ) (s.local.env or { });
    };

  # ── Skill 链接：entryFile 单文件 vs 目录递归 ──
  linkSkill = name: s:
    if s ? entryFile then
      { "opencode/skills/${name}/${s.entryFile}".source = "${s.source}/${s.entryFile}"; }
    else
      { "opencode/skills/${name}" = { source = s.source; recursive = true; }; };
  # ── 从选中的 skill 中提取包和 env ──
  skillPkgs = lib.catAttrs "package" (lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills));
  skillEnv = lib.foldl' (acc: s: acc // (s.env or { })) { } (lib.attrValues selectedSkills);
in
{
  # ── opencode 核心 ──
  programs.opencode = {
    enable = true;
    settings = {
      model = modelMap.${p.defaultModel};
      small_model = modelMap.${p.smallModel};
      lsp = true;
      mcp = lib.mapAttrs toOpenCodeMcp common.mcp;
      provider."zhipuai-coding-plan" = {
        options.apiKey = "{file:${p.apiKey.secretFile}}";
      };
    };
  };

  # ── Skills（静态 symlink）──
  xdg.configFile = lib.mkMerge [
    (lib.mergeAttrsList (lib.mapAttrsToList linkSkill selectedSkills))

    # ── Rules:聚合源(通用规则 + 通用资源 guide)──
    { "opencode/AGENTS.md".source = common.project.globalAgentsMd; }

    # ── Plugins：跨 agent（adapter 路径内联）──
    {
      "opencode/plugins/rtk.ts".source =
        "${common.plugins.rtk.source}/hooks/opencode/rtk.ts";
      "opencode/plugins/herdr-agent-state.js".source =
        "${common.plugins.herdr.source}/src/integration/assets/opencode/herdr-agent-state.js";
    }

    # ── opencode 项目级渲染器(被 agent sync 调用) + ai/registry.json ──
    {
      "ai/renderers/opencode.sh" = {
        source = pkgs.writeShellScript "opencode-render" ''
          # 契约:$1 = manifest 路径, $2 = 项目根
          # 读 manifest 的 mcp 列表,在项目根 opencode.json 启用(enabled:true override)
          MANIFEST="''${1:-$PWD/.agents/manifest.json}"
          ROOT="''${2:-$PWD}"
          CFG="$ROOT/opencode.json"
          for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
            if [ -f "$CFG" ]; then
              jq --arg n "$name" '.mcp[$n].enabled = true' "$CFG" > tmp && mv tmp "$CFG"
            else
              echo '{"mcp":{}}' | jq --arg n "$name" '.mcp[$n].enabled = true' > "$CFG"
            fi
          done
        '';
        executable = true;
      };
      "ai/registry.json".source = common.project.registry;
    }
  ];

  # ── Plugins：opencode 专属 npm ──
  programs.opencode.settings.plugin = [
    "opencode-pty"
    "opencode-handoff"
  ];

  # ── Motion AI Kit:只下载到中立目录,不全局 link ──
  # motion-ai-kit 的 defaultEnabled=false,靠 agent skill add 项目级 symlink 到 .agents/skills/
  home.activation.installMotionAiKit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _install_motion_ai_kit() {
    TOKEN_PATH="/run/secrets/motion_plus_token"
    if [ ! -f "$TOKEN_PATH" ]; then
      echo "WARNING: $TOKEN_PATH not found, skipping Motion AI Kit installation"
      return 0
    fi

    TOKEN=$(cat "$TOKEN_PATH")
    DATA_DIR="${config.xdg.dataHome}/motion-ai-kit/skills"
    SCRIPT=$(${pkgs.curl}/bin/curl -sL --retry 3 --retry-delay 2 \
      "https://api.motion.dev/registry/skills/motion-ai-kit?token=$TOKEN") || true

    if [ -z "$SCRIPT" ]; then
      echo "WARNING: motion-ai-kit 下载失败（网络/Token？），跳过本次安装"
      return 0
    fi

    eval "$(echo "$SCRIPT" | grep -E '^SKILL_(COUNT|[0-9]+_(NAME|FILE_COUNT|FILE_[0-9]+_(PATH|B64)))=')"

    # 1. 清理旧内容(中立目录 + opencode/skills 里旧的 symlink,迁移期兼容)
    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      rm -rf "$DATA_DIR/$skill_name"
      rm -rf "${config.xdg.configHome}/opencode/skills/$skill_name"
      i=$((i + 1))
    done

    # 2. 下载到中立目录(唯一一份真实内容,agent skill add 时 symlink 到 .agents/skills/)
    mkdir -p "$DATA_DIR"
    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      eval "file_count=\$SKILL_''${i}_FILE_COUNT"
      skill_dir="$DATA_DIR/$skill_name"

      j=1
      while [ "$j" -le "$file_count" ]; do
        eval "rel_path=\$SKILL_''${i}_FILE_''${j}_PATH"
        eval "file_data=\$SKILL_''${i}_FILE_''${j}_B64"
        full_path="$skill_dir$rel_path"

        mkdir -p "$(dirname "$full_path")"
        printf '%s' "$file_data" | base64 -d > "$full_path"
        j=$((j + 1))
      done
      i=$((i + 1))
    done
    }
    # 函数内 return 合法；任何异常被 || 兜住，不波及整个激活
    _install_motion_ai_kit || echo "WARNING: motion-ai-kit 安装异常，已跳过"
    # 不再全局 symlink;motion 走 agent skill add 项目级 .agents/skills/
  '';

  # ── 插件核心包 + skill 依赖包 ──
  home.packages = [
    common.plugins.rtk.package
  ] ++ skillPkgs;

  home.sessionVariables = skillEnv;
}
