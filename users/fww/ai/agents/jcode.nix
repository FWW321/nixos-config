# jcode agent — 完全自包含
# 从 common 拉取中立数据,转换为 jcode 格式
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║                    jcode vs opencode 能力对照                          ║
# ╠═════════════════╦═════════════════════════════════════════════════════╣
# ║ dcg(破坏性拦截) ║ ✅ jcode 内置 Safety System,更强:                   ║
# ║                 ║   两级分类(auto-allowed / requires-permission)      ║
# ║                 ║   [safety.rules] 可 promote/demote;覆盖 bash/PR/push║
# ║                 ║   /邮件/部署等,远超 dcg 的 shell 命令拦截            ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ herdr(终端多路) ║ ✅ jcode 内置 server/swarm:                          ║
# ║                 ║   jcode serve(守护进程)+ connect(多客户端)          ║
# ║                 ║   swarm = 多 agent DM/广播/worktree 协作             ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ handoff(会话)   ║ ✅ jcode --resume 更强:可跨 harness 恢复            ║
# ║                 ║   opencode / codex / claude code / pi 的会话        ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ agent-browser   ║ ✅ jcode 内置 browser 工具(Firefox Agent Bridge)   ║
# ║                 ║   `jcode browser setup` 即装,无需 skill 包装         ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ web-search-prime ║ ⚠️ jcode 内置 websearch(通用,非智谱定制)           ║
# ║ web-reader       ║ ⚠️ jcode 内置 webfetch(markdown 提取)              ║
# ║                 ║   远程 MCP 本可桥接,但 jcode 暂不支持 HTTP/SSE      ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ rtk(命令追踪/   ║ ❌ jcode 无等价物:                                   ║
# ║   改写/经济学)   ║   有 token 用量 overlay 和 agentgrep(增强 grep)    ║
# ║                 ║   但非 rtk 的命令级追踪/改写/成本经济学分析         ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ context7(库文档)║ ❌ 远程 MCP,jcode 跳过(issue #761 待合并)          ║
# ║ zread(仓库阅读) ║ ❌ 同上;有完整社区实现等作者合并                     ║
# ╠═════════════════╬═════════════════════════════════════════════════════╣
# ║ plugins(rtk/   ║ ❌ adapter(.ts/.js)绑 opencode 生命周期              ║
# ║  herdr/dcg.js)  ║   jcode 有自己的工具系统,plugin adapter 不兼容      ║
# ╚═════════════════╩═════════════════════════════════════════════════════╝
#
# Provider(GLM):命名 profile [providers.zhipu](v0.54+ 已入 failover 链,可作 default_provider)
# context_window 是核心:上游静态表 glm-5* 只认 5.2=1M,glm-5.3 误落 200K 泛匹配 →
# compaction 按 1/5 窗口提前压缩;命名 profile 的 per-model context_window 灌入
# 全局缓存(issue #366/#421),优先级高于静态家族表,TUI 表/压缩预算/模型切换全生效
# API key 仍走 env_file:config.toml 写变量名,activation 从 /run/secrets 读值落盘
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };
  p = common.providers.zhipu;

  # ── 全局 skill:与 opencode 同选择逻辑 ──
  selectedSkills = lib.filterAttrs (_: s: (s.defaultEnabled or false) && !(s ? runtime))
    common.skills;

  # ── Skill 链接:entryFile 单文件 vs 目录递归 ──
  # jcode SKILL.md 格式与 opencode 完全一致,直接 symlink 到 ~/.jcode/skills/
  # jcode 按 embedding 相似度按需注入,skill 工具/slash 命令手动激活
  linkSkill = name: s:
    if s ? entryFile then
      { ".jcode/skills/${name}/${s.entryFile}".source = "${s.source}/${s.entryFile}"; }
    else
      { ".jcode/skills/${name}" = { source = s.source; recursive = true; }; };

  skillPkgs = lib.catAttrs "package" (lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills));
  skillEnv = lib.foldl' (acc: s: acc // (s.env or { })) { } (lib.attrValues selectedSkills);

  # ── GLM coding plan 接入 jcode 的三个名字(全部由 profile 单点派生)──
  # 全部为了规避内置 zai(Z.AI 国际版)的认领,任一撞名都会被劫持到 api.z.ai:
  #  - profile 名:catalog.rs 别名表认领 "zhipu",命中即套用内置 zai,
  #    命名 profile 被遮蔽 → 启动 not configured → 空仓回落 claude-opus-5
  #  - key 变量:zai 凭据探测认领 ZHIPU_API_KEY(并从 zai.env 读 ZAI_API_KEY 兜底)
  #  - env 文件:相对 app_config_dir() = ~/.config/jcode 解析,不是 ~/.jcode
  glm = rec {
    profile = "bigmodel"; # 对应域名 open.bigmodel.cn,无任何内置认领
    keyEnv = "${lib.toUpper profile}_API_KEY";
    envFile = "${profile}.env";
  };

  # ── jcode 命名 provider profile:从中立 providers.nix 全量派生 ──
  # base_url/models/context_window/default_model 单一来源,与 opencode 同源永不漂移
  # maxOutput 无处安放(jcode model config 仅 context_window 字段),输出上限交给服务端
  glmProfile = {
    type = "openai-compatible";
    base_url = p.endpoints.openai;
    api_key_env = glm.keyEnv;
    env_file = glm.envFile;
    default_model = p.defaultModel;
    models = lib.mapAttrsToList (id: m: {
      inherit id;
      context_window = m.contextWindow;
    }) p.models;
  };

  # ── jcode MCP:从中立 common.mcp 派生(仅 local stdio;remote 跳过 — issue #761)──
  # enabled = defaultEnabled:项目级服务器注册但 enabled:false 不 spawn,项目 renderer 翻 true
  # zai-mcp-server 显式排除:bunx 每次冷启动拉包,会话启动延迟不可接受
  mcpExcluded = [ "zai-mcp-server" ];
  mcpLocal = lib.filterAttrs (n: m: m ? local && !builtins.elem n mcpExcluded) common.mcp;
  mcpTemplate = pkgs.writeText "jcode-mcp-template" (builtins.toJSON {
    mcpServers = lib.mapAttrs (_: m: {
      inherit (m.local) command;
      args = m.local.args or [ ];
      enabled = m.defaultEnabled or false;
      # secret 占位 null,activation 时从 /run/secrets 读出内联
      env = lib.mapAttrs (_: v: if v ? secretFile then null else v) (m.local.env or { });
    }) mcpLocal;
  });
  mcpSecrets = lib.concatLists (lib.mapAttrsToList (name: m:
    lib.mapAttrsToList (key: v: { inherit name key; file = toString v.secretFile; })
      (lib.filterAttrs (_: v: v ? secretFile) (m.local.env or { }))
  ) mcpLocal);
in
{
  # ── jcode 模块:二进制(wrapper 内置)+ config.toml 声明式 ──
  programs.jcode = {
    enable = true;
    settings = {
      provider = {
        default_provider = glm.profile;
        default_model = p.defaultModel;
      };
      providers.${glm.profile} = glmProfile;

      # ── Embedding / 记忆系统 ──
      # 默认本地 ONNX(MiniLM-L6-v2,384 维,tract 纯 Rust CPU 推理),无需配置
      # 远程 embedding 需注入 OPENAI_API_KEY 到进程环境(jcode 多子系统硬编码检查):
      # 副作用是 model catalog sweeper 拿此 key 刷 api.openai.com → 401 噪音,
      # 且 memory sidecar 也依赖此变量判断 LLM 可达性。综合考量:本地够用,不折腾
    };
  };

  # ── Skill 运行时依赖包(skills 自带 package 字段时;jcode 二进制由模块提供)──
  home.packages = skillPkgs;

  # ── Skills(静态 symlink → ~/.jcode/skills/) + 全局规则 ──
  # 全局规则走 prompt-overlay.md:jcode 不读 ~/.jcode/AGENTS.md(它只认 ~/AGENTS.md
  # 和 <项目>/AGENTS.md);在默认 system prompt 之上叠加指引的官方钩子是
  # ~/.jcode/prompt-overlay.md(prompt.rs load_prompt_overlay_files_from_dir)
  home.file = lib.mkMerge [
    (lib.mergeAttrsList (lib.mapAttrsToList linkSkill selectedSkills))
    { ".jcode/prompt-overlay.md".source = common.project.globalAgentsMd; }
  ];

  # ── 全局 MCP:~/.jcode/mcp.json ──
  # jcode env 不支持 {file:...} 引用,secret 在 activation 时从 /run/secrets 读出内联;
  # secret 文件缺失 → 该服务器 enabled=false(env 值置空),注册保留但跳过 spawn
  home.activation.generateJcodeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gen_jcode_mcp() {
      mkdir -p "$HOME/.jcode"
      local out="$HOME/.jcode/mcp.json"
      local jq="${pkgs.jq}/bin/jq"
      cp "${mcpTemplate}" "$out"
      ${lib.concatMapStringsSep "\n      " (s: ''
        _sec_v=""
        [ -f "${s.file}" ] && _sec_v=$(cat "${s.file}" 2>/dev/null || true)
        if [ -n "$_sec_v" ]; then
          "$jq" --arg n "${s.name}" --arg k "${s.key}" --arg v "$_sec_v" \
            '.mcpServers[$n].env[$k] = $v' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
        else
          "$jq" --arg n "${s.name}" --arg k "${s.key}" \
            '.mcpServers[$n].enabled = false | .mcpServers[$n].env[$k] = ""' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
        fi
      '') mcpSecrets}
    }
    _gen_jcode_mcp || echo "WARNING: jcode mcp.json 生成失败,跳过"
  '';

  # ── Provider key 落盘:~/.config/jcode/${glm.envFile} ──
  # 目录依据与命名约束见上方 glm 注释;值从 /run/secrets 读出
  home.activation.generateJcodeProvider = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gen_jcode_provider() {
      local dir="${config.xdg.configHome}/jcode"
      local out="$dir/${glm.envFile}"
      mkdir -p "$dir"

      # Provider key(智谱 GLM coding plan)
      local glm_key=""
      [ -f "${p.apiKey.secretFile}" ] \
        && glm_key=$(cat "${p.apiKey.secretFile}" 2>/dev/null || true)

      (umask 077; {
        [ -n "$glm_key" ] && printf '${glm.keyEnv}=%s\n' "$glm_key"
      } > "$out")
    }
    _gen_jcode_provider || echo "WARNING: jcode provider env 生成失败,跳过"
  '';

  # ── 项目级渲染器(被 agent sync 调用)──
  # 契约:$1 = manifest 路径, $2 = 项目根
  # jcode 项目文件整体覆盖同名全局条目(无深合并),孤立的 {shared:true} 会被
  # merge 逻辑当非 stdio 条目丢弃 → 必须从全局 ~/.jcode/mcp.json 取完整定义,
  # 连同 enabled:true 一起写入项目根 .jcode/mcp.json
  # 注意:定义已内联 secret → .jcode/ 应加入项目 .gitignore
  xdg.configFile."ai/renderers/jcode.sh" = {
    source = pkgs.writeShellScript "jcode-render" ''
      MANIFEST="''${1:-$PWD/.agents/manifest.json}"
      ROOT="''${2:-$PWD}"
      CFG="$ROOT/.jcode/mcp.json"
      GLOBAL="$HOME/.jcode/mcp.json"
      [ -f "$GLOBAL" ] || { echo "[jcode-render] warning: no global mcp.json, skip" >&2; exit 0; }
      [ -f "$CFG" ] || echo '{"mcpServers":{}}' > "$CFG"
      for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
        def=$(jq --arg n "$name" '.mcpServers[$n] // empty' "$GLOBAL" 2>/dev/null)
        if [ -n "$def" ]; then
          jq --arg n "$name" --argjson d "$def" \
            '.mcpServers[$n] = ($d + {enabled:true})' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
        else
          echo "[jcode-render] warning: '$name' not in global mcp.json" >&2
        fi
      done
    '';
    executable = true;
  };

  home.sessionVariables = skillEnv;
}
