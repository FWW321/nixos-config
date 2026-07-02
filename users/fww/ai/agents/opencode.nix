# opencode agent — 完全自包含
# 从 common 拉取数据，内联转换为 opencode 格式
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib; };

  # ── 拉取资源 ──
  selectedMcp = lib.getAttrs [
    "context7" "zai-mcp-server" "web-search-prime" "web-reader" "zread"
    "motion-studio" "mcp-server-tauri" "shadcn" "nixos" "github" "codegraph"
  ] common.mcp;

  selectedSkills = lib.filterAttrs (_: v: !(v ? runtime))
    (lib.getAttrs [
      "agent-browser" "humanizer-zh" "herdr"
      "git-workflow" "surrealdb" "shadcn"
      "grill-with-docs" "grilling" "domain-modeling"
      "understand" "understand-chat" "understand-dashboard" "understand-diff"
      "understand-domain" "understand-explain" "understand-knowledge" "understand-onboard"
      "makepad-2.0-animation" "makepad-2.0-app-structure" "makepad-2.0-design-judgment"
      "makepad-2.0-dsl" "makepad-2.0-events" "makepad-2.0-layout"
      "makepad-2.0-migration" "makepad-2.0-performance" "makepad-2.0-shaders"
      "makepad-2.0-splash" "makepad-2.0-theme" "makepad-2.0-troubleshooting"
      "makepad-2.0-vector" "makepad-2.0-widgets"
    ] common.skills);

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
      enabled = true;
      url = s.remote.url;
      headers = lib.mapAttrs (_: toOpenCodeHeader) (s.remote.secretHeaders or { });
    } else {
      type = "local";
      enabled = true;
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
      mcp = lib.mapAttrs toOpenCodeMcp selectedMcp;
      provider."zhipuai-coding-plan" = {
        options.apiKey = "{file:${p.apiKey.secretFile}}";
      };
    };
  };

  # ── Skills（静态 symlink）──
  xdg.configFile = lib.mkMerge [
    (lib.mergeAttrsList (lib.mapAttrsToList linkSkill selectedSkills))

    # ── Rules ──
    { "opencode/AGENTS.md".source = common.rules; }

    # ── Plugins：跨 agent（adapter 路径内联）──
    {
      "opencode/plugins/rtk.ts".source =
        "${common.plugins.rtk.source}/hooks/opencode/rtk.ts";
      "opencode/plugins/herdr-agent-state.js".source =
        "${common.plugins.herdr.source}/src/integration/assets/opencode/herdr-agent-state.js";
    }
  ];

  # ── Plugins：opencode 专属 npm ──
  programs.opencode.settings.plugin = [
    "opencode-pty"
    "opencode-handoff"
  ];

  # ── Motion AI Kit（运行时下载 skill）──
  home.activation.installMotionAiKit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN_PATH="/run/secrets/motion_plus_token"
    if [ ! -f "$TOKEN_PATH" ]; then
      echo "WARNING: $TOKEN_PATH not found, skipping Motion AI Kit installation"
      return 0
    fi

    TOKEN=$(cat "$TOKEN_PATH")
    SKILLS_DIR="${config.xdg.configHome}/opencode/skills"
    SCRIPT=$(${pkgs.curl}/bin/curl -sL "https://api.motion.dev/registry/skills/motion-ai-kit?token=$TOKEN")

    if [ -z "$SCRIPT" ]; then
      echo "ERROR: Failed to download Motion AI Kit script"
      return 1
    fi

    eval "$(echo "$SCRIPT" | grep -E '^SKILL_(COUNT|[0-9]+_(NAME|FILE_COUNT|FILE_[0-9]+_(PATH|B64)))=')"

    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      rm -rf "$SKILLS_DIR/$skill_name"
      i=$((i + 1))
    done

    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      eval "file_count=\$SKILL_''${i}_FILE_COUNT"
      skill_dir="$SKILLS_DIR/$skill_name"

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
  '';

  # ── 插件核心包 + skill 依赖包 ──
  home.packages = [
    common.plugins.rtk.package
  ] ++ skillPkgs;

  home.sessionVariables = skillEnv;
}
