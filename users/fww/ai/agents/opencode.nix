# opencode agent — 完全自包含
# 从 common 拉取数据，内联转换为 opencode 格式
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  # ── 全局 skill:defaultEnabled = true 的(通用),特殊的走项目级 agent skill add ──
  selectedSkills = lib.filterAttrs (_: s: (s.defaultEnabled or false) && !(s ? runtime))
    common.skills;

  p = common.providers.zhipu;

  # opencode 内置 provider 名映射：model id → provider/id（自动从 providers 派生）
  modelMap = lib.mapAttrs (id: _: "zhipuai-coding-plan/${id}") p.models;

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
      snapshot = false;
      mcp = lib.mapAttrs toOpenCodeMcp common.mcp;
      # glm-5.3/5.2 已收录 models.dev 目录,仅注入 apiKey,模型元数据用目录内置值
      provider."zhipuai-coding-plan".options.apiKey = "{file:${p.apiKey.secretFile}}";
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
      "opencode/plugins/dcg-guard.js".source =
        "${common.plugins.dcg.source}/dcg-guard.js";
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


  # ── 插件核心包 + skill 依赖包 ──
  # dcg 二进制 + 配置在 dcg.nix(agent 无关)
  home.packages = [
    common.plugins.rtk.package
  ] ++ skillPkgs;

  home.sessionVariables = skillEnv // {
    OPENCODE_ENABLE_EXA = "1";
  };

  programs.bash.initExtra = ''
    [ -f /run/secrets/exa_api_key ] && export EXA_API_KEY="$(cat /run/secrets/exa_api_key)"
  '';
}
