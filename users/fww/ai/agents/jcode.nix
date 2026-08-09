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
# Provider(GLM):走 openai-compatible,config.toml 声明式管理(同 opencode 思路)
# API key 通过 env_file 机制:config.toml 写变量名,~/.config/jcode/zhipu.env 写值
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };
  p = common.providers.zhipu;

  # ── config.toml:用内置 openai-compatible 类型(在 failover 链里)──
  # 不用自定义 [providers.xxx](不在 failover 链,发送时被忽略)
  # 不用内置 zai(zai 硬编码 api.z.ai 国际域名,非 open.bigmodel.cn 国内 coding plan)
  # endpoint/model/key 通过 openai-compatible.env 注入(见 activation 脚本)
  configToml = ''
    [provider]
    default_provider = "openai-compatible"
    default_model = "${p.defaultModel}"

    # ── Embedding / 记忆系统 ──
    # 本地 ONNX(MiniLM-L6-v2,384 维,tract 纯 Rust CPU 推理)
    # 远程 embedding 需注入 OPENAI_API_KEY 到进程环境(jcode 多子系统硬编码检查)
    # 副作用:model catalog sweeper 拿此 key 刷 api.openai.com → 401 噪音
    # 且 memory sidecar 也依赖此变量判断 LLM 可达性,不设则记忆系统休眠
    # 综合考量:本地 embedding 够用,不折腾
  '';

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
in
{
  # ── jcode 二进制(含 --no-update + JCODE_NO_TELEMETRY wrapper)──
  home.packages = [ pkgs.jcode ] ++ skillPkgs;

  # ── Skills(静态 symlink → ~/.jcode/skills/) + 全局规则 + Provider ──
  home.file = lib.mkMerge [
    (lib.mergeAttrsList (lib.mapAttrsToList linkSkill selectedSkills))
    { ".jcode/AGENTS.md".source = common.project.globalAgentsMd; }
    { ".jcode/config.toml".text = configToml; }
  ];

  # ── 全局 MCP:~/.jcode/mcp.json ──
  # jcode 的 env 不支持 {file:...} 引用,secret 需 activation 时读 /run/secrets 内联
  # 仅 local stdio server;remote MCP 跳过(jcode issue #761 待合并 Streamable HTTP/SSE)
  home.activation.generateJcodeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gen_jcode_mcp() {
      mkdir -p "$HOME/.jcode"
      local out="$HOME/.jcode/mcp.json"
      local jq="${pkgs.jq}/bin/jq"

      # ── 收集 secret(activation 时读 /run/secrets)──
      local gh_token="" zai_token=""
      [ -f "${common.mcp.github.local.env.GITHUB_PERSONAL_ACCESS_TOKEN.secretFile}" ] \
        && gh_token=$(cat "${common.mcp.github.local.env.GITHUB_PERSONAL_ACCESS_TOKEN.secretFile}" 2>/dev/null || true)
      [ -f "${common.mcp."zai-mcp-server".local.env.Z_AI_API_KEY.secretFile}" ] \
        && zai_token=$(cat "${common.mcp."zai-mcp-server".local.env.Z_AI_API_KEY.secretFile}" 2>/dev/null || true)

      "$jq" -n \
        --arg nixos_cmd "${common.mcp.nixos.local.command}" \
        --arg gh_cmd "${common.mcp.github.local.command}" \
        --argjson gh_args '${builtins.toJSON (common.mcp.github.local.args or [ ])}' \
        --arg gh_token "$gh_token" \
        --arg zai_token "$zai_token" \
        '{
          mcpServers: {
            nixos: { command: $nixos_cmd },
            github: (if $gh_token != "" then {
              command: $gh_cmd,
              args: $gh_args,
              env: { GITHUB_PERSONAL_ACCESS_TOKEN: $gh_token }
            } else {} end),
            "zai-mcp-server": (if $zai_token != "" then {
              command: "bunx",
              args: ["-y","@z_ai/mcp-server"],
              env: { Z_AI_API_KEY: $zai_token, Z_AI_MODE: "ZHIPU" }
            } else {} end)
          }
        }' > "$out"
    }
    _gen_jcode_mcp || echo "WARNING: jcode mcp.json 生成失败,跳过"
  '';

  # ── Provider env: ~/.config/jcode/openai-compatible.env (chat) ──
  home.activation.generateJcodeProvider = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gen_jcode_provider() {
      local chat_dir="${config.xdg.configHome}/jcode"
      mkdir -p "$chat_dir"

      # Provider key(智谱 GLM coding plan)
      local zhipu_key=""
      [ -f "${p.apiKey.secretFile}" ] \
        && zhipu_key=$(cat "${p.apiKey.secretFile}" 2>/dev/null || true)

      (umask 077; {
        printf 'JCODE_OPENAI_COMPAT_API_BASE=${p.endpoints.openai}\n'
        printf 'JCODE_OPENAI_COMPAT_DEFAULT_MODEL=${p.defaultModel}\n'
        [ -n "$zhipu_key" ] && printf 'OPENAI_COMPAT_API_KEY=%s\n' "$zhipu_key"
      } > "$chat_dir/openai-compatible.env")

      # 清理旧格式 env 文件
      rm -f "$chat_dir/zhipu.env" "$chat_dir/zai.env" "$HOME/.jcode/openai.env" 2>/dev/null || true
    }
    _gen_jcode_provider || echo "WARNING: jcode provider env 生成失败,跳过"
  '';

  # ── 项目级渲染器(被 agent sync 调用)──
  # 契约:$1 = manifest 路径, $2 = 项目根
  # 读 manifest 的 mcp 列表,在项目根 .jcode/mcp.json 标记 shared:true
  xdg.configFile."ai/renderers/jcode.sh" = {
    source = pkgs.writeShellScript "jcode-render" ''
      MANIFEST="''${1:-$PWD/.agents/manifest.json}"
      ROOT="''${2:-$PWD}"
      CFG="$ROOT/.jcode/mcp.json"
      for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
        if [ -f "$CFG" ]; then
          jq --arg n "$name" '.mcpServers[$n].shared = true' "$CFG" > tmp && mv tmp "$CFG"
        else
          echo '{"mcpServers":{}}' | jq --arg n "$name" '.mcpServers[$n].shared = true' > "$CFG"
        fi
      done
    '';
    executable = true;
  };

  home.sessionVariables = skillEnv;
}
