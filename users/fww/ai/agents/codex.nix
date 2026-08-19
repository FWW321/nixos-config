# codex agent — 完全自包含
# 从 common 拉取中立数据,转换为 codex 格式
#
# 桌面端(unified ChatGPT/Codex)与 CLI 共享 CODEX_HOME(~/.codex):
# config.toml/AGENTS.md/skills 对两者同时生效;桌面端由 pkgs.chatgpt
# overlay 提供(见 pkgs/chatgpt/),其 resources/codex symlink 到同一
# pkgs.codex 二进制 → CLI/桌面单一版本来源
#
# secret 全走进程环境变量(codex 原生设计,值不落 nix store):
#   - provider env_key → ZHIPU_API_KEY / MINIMAX_API_KEY(从 secret 文件名派生)
#   - 远程 MCP Authorization Bearer → bearer_token_env_var(同一 ZHIPU_API_KEY)
#   - 远程 MCP 普通命名 header(context7) → env_http_headers(header 名即 env 名)
#   - 本地 stdio MCP secret env → wrapper 脚本 cat secret file 后 exec
# 注意:桌面端从 compositor 启动时无 shell env,provider key/远程 MCP 仅
# CLI 可用;桌面端走 ChatGPT 账号登录即可
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  # ── codex 可用 provider:声明了 responses 端点的(codex 0.84+ 仅支持 responses)──
  # siliconflow(仅 embedding/openai 端点)被此过滤自动排除
  codexProviders = lib.filterAttrs (_: v: v.endpoints ? responses) common.providers;
  # 默认 provider 与默认模型(zhipu coding plan)
  defaultProvider = "zhipu";
  p = codexProviders.${defaultProvider};

  # ── secret file → 环境变量名(/run/secrets/zhipu_api_key → ZHIPU_API_KEY)──
  # 单一来源:env var 名由 secret 文件名派生(大写+中划线转下划线),
  # config.toml 引用与 bash 导出同源生成,永不漂移
  secretToEnv = file:
    lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ]
      (baseNameOf (toString file)));

  # ── 全局 skill:与 opencode 同选择逻辑 ──
  # (曾因 git-workflow 上游无 frontmatter 设排除列表,该 skill 移除后已无排除项)
  selectedSkills = lib.filterAttrs (_: s: (s.defaultEnabled or false) && !(s ? runtime))
    common.skills;

  # ── Skill:entryFile 单文件(值=path→file,模块生成 <name>/SKILL.md) vs 目录(symlink) ──
  codexSkills = lib.mapAttrs (_: s:
    if s ? entryFile then "${s.source}/${s.entryFile}" else s.source
  ) selectedSkills;

  skillPkgs = lib.catAttrs "package" (lib.attrValues (lib.filterAttrs (_: s: s ? package) selectedSkills));
  skillEnv = lib.foldl' (acc: s: acc // (s.env or { })) { } (lib.attrValues selectedSkills);

  # ── MCP 格式转换:中立 → codex config.toml ──
  # stdio:env 值不支持 {file:...} → 有 secret 时包一层 wrapper 脚本
  #        (home-manager programs.mcp 集成的 wrapEnvFilesCommand 同款手法)
  # remote:Authorization Bearer → bearer_token_env_var;命名 header → env_http_headers
  #
  # 排除慢启动 server(2026-08 codex 0.147 实测,证据链完整):
  # 智谱系(open.bigmodel.cn)端点 + context7 是仅有的"需网络握手"server,npx 桥
  # ~2s 就绪;0.147 的 prewarm 对慢 server 双 spawn 桥进程(日志 PID 428436/428516
  # 两代),竞争把工具注册弄丢 —— server 层 Service initialized + tools/list 全通,
  # 但 turn 工具快照永远缺失(exec 首 turn + resume 二 turn 均 MISSING),TUI 报
  # "MCP startup interrupted"。属 codex client bug(#20982 智谱端点 initialized
  # 回 200 空 body 的兼容问题 + 0.147 prewarm 竞争),配置层无解。
  # 这些工具在 opencode 侧全部正常 → codex 只留原生快 server(github/nixos；
  # minimax MCP 已移除,搜索走 codex 原生 web_search,媒体生成放弃,见 mcp.nix 注释)
  mcpExcluded = [
    "context7"       # 远程 HTTP,慢启动受害者(同下)
    "web-reader"     # 智谱端点 npx 桥
    "web-search-prime"
    "zread"
  ];

  toCodexLocal = name: m:
    let
      envs = m.local.env or { };
      secrets = lib.filterAttrs (_: v: v ? secretFile) envs;
      plains = lib.filterAttrs (_: v: !(v ? secretFile)) envs;
      needsWrapper = secrets != { };
      wrapper = pkgs.writeShellScript "codex-mcp-${name}" ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList
          (k: v: ''export ${k}="$(cat ${lib.escapeShellArg v.secretFile} 2>/dev/null || true)"'')
          secrets)}
        exec ${lib.escapeShellArg m.local.command} ${lib.escapeShellArgs (m.local.args or [ ])}
      '';
      transport =
        if needsWrapper then { command = toString wrapper; }
        else { inherit (m.local) command; args = m.local.args or [ ]; };
      # 中立层 autoApproveTools → codex per-tool approval_mode="approve"
      # (无 readOnlyHint 的 MCP 工具默认要审批,exec 非交互下直接 Abort)
      toolApprovals = lib.listToAttrs (map (t: lib.nameValuePair t {
        approval_mode = "approve";
      }) (m.autoApproveTools or [ ]));
    in
    { enabled = m.defaultEnabled or false; } // transport
    // lib.optionalAttrs (plains != { }) { env = plains; }
    // lib.optionalAttrs (toolApprovals != { }) { tools = toolApprovals; };

  # ── 远程 MCP:两种形态 ──
  # 常规:url + bearer_token_env_var/env_http_headers(codex 原生 streamable-http)
  # 智谱系(open.bigmodel.cn)必须走 mcp-remote stdio 桥:智谱服务端对
  # notifications/initialized 返回 200 空 body(而非推荐的 202),codex 的 rmcp
  # 客户端只认 202/204/JSON → 空 body 触发反序列化错误,通道被当关闭,
  # 报 "Transport channel closed, when send initialized notification"
  # (openai/codex#20982/#35459,客户端兼容 bug,无开关可绕;mcp-remote 基于
  # 官方 TS SDK,容忍此类响应,是 issue 里双重复核的唯一通路)
  # 桥接 wrapper 运行时读 secret 文件,值不进 store;用 nodejs 而非 slim(slim 不带 npx)
  # npx 冷启动 + 远端延迟可能超默认 30s → startup_timeout_sec 放宽(官方超时报错指引的字段)
  toCodexRemote = name: m:
    let
      headers = m.remote.secretHeaders or { };
      bearer = headers.Authorization or null;
      isBearer = (bearer ? secretFile) && ((bearer.prefix or "") == "Bearer ");
      plainHeaders = lib.filterAttrs (_: v: builtins.isString v) headers;
      needsBridge = lib.hasPrefix "https://open.bigmodel.cn/" m.remote.url;
      bridge = pkgs.writeShellScript "codex-mcp-${name}" ''
        exec ${lib.getExe' pkgs.nodejs "npx"} -y mcp-remote ${lib.escapeShellArg m.remote.url} \
          --header "Authorization: Bearer $(cat ${lib.escapeShellArg bearer.secretFile} 2>/dev/null || true)"
      '';
    in
    if needsBridge then {
      enabled = m.defaultEnabled or false;
      command = toString bridge;
      startup_timeout_sec = 90;
    } else
      { enabled = m.defaultEnabled or false; url = m.remote.url; startup_timeout_sec = 60; }
      // (lib.optionalAttrs isBearer { bearer_token_env_var = secretToEnv bearer.secretFile; })
      // (lib.optionalAttrs (plainHeaders != { }) {
        env_http_headers = lib.mapAttrs (_: secretToEnv) plainHeaders;
      });

  codexMcp = lib.mapAttrs (name: m:
    if m ? local then toCodexLocal name m else toCodexRemote name m
  ) (lib.filterAttrs (n: _: !(builtins.elem n mcpExcluded)) common.mcp);

  # ── 需要导出的 secret env:provider key + 远程 MCP 的 secret(lib.unique 去重)──
  remoteSecretEnvs = lib.concatLists (lib.mapAttrsToList (_: m:
    lib.optionals (m ? remote) (
      let
        headers = m.remote.secretHeaders or { };
        b = headers.Authorization or null;
        fromBearer = lib.optional (b ? secretFile) {
          env = secretToEnv b.secretFile;
          inherit (b) secretFile;
        };
        fromPlain = lib.mapAttrsToList (_: v: { env = secretToEnv v; secretFile = v; })
          (lib.filterAttrs (_: v: builtins.isString v) headers);
      in
      fromBearer ++ fromPlain
    )
  ) common.mcp);

  secretEnvExports = lib.unique (
    # 所有 codex provider 的 key + 远程 MCP 的 secret
    (lib.mapAttrsToList (_: v: {
      env = secretToEnv v.apiKey.secretFile;
      inherit (v.apiKey) secretFile;
    }) codexProviders)
    ++ remoteSecretEnvs
  );
  # ── codex 模型目录(models.json):官方要求声明 GLM 模型元数据 ──
  # codex 内置目录无 GLM,无声明则模型选择器不显示/参数错误
  # context_window 从 providers.nix 单一来源派生;字段照抄官方文档模板
  # (priority/experimental_supported_tools 等都是必填,缺一个 codex 直接报解析错误)
  catalogEntry = idx: id: {
    slug = id;
    display_name = id;
    description = "Z.ai coding model";
    default_reasoning_level = "max";
    supported_reasoning_levels = [
      { effort = "low"; description = "Light reasoning"; }
      { effort = "high"; description = "Enhanced reasoning"; }
      { effort = "max"; description = "Deep reasoning"; }
    ];
    shell_type = "shell_command";
    visibility = "list";
    supported_in_api = true;
    priority = idx; # 模型选择器排序
    base_instructions = "";
    supports_reasoning_summaries = true;
    default_reasoning_summary = "none";
    support_verbosity = false;
    apply_patch_tool_type = "freeform";
    truncation_policy.mode = "bytes";
    truncation_policy.limit = 10000;
    context_window = p.models.${id}.contextWindow;
    max_context_window = p.models.${id}.contextWindow;
    effective_context_window_percent = 95;
    supports_parallel_tool_calls = true;
    experimental_supported_tools = [ ];
    input_modalities = [ "text" ];
  };
  modelsJson = pkgs.writeText "codex-models.json" (builtins.toJSON {
    # 只声明默认模型 glm-5.3(providers.nix 已只留 5.3,5.2 全线退役)
    models = [ (catalogEntry 0 p.defaultModel) ];
  });

  # ── provider → codex model_providers 段(单一来源自动派生)──
  # env_key 从 secret 文件名派生,与 bash 导出同源;wire_api 全 responses
  toCodexProvider = n: v: {
    name = (lib.toUpper (lib.substring 0 1 n)) + lib.substring 1 (-1) n;
    base_url = v.endpoints.responses;
    env_key = secretToEnv v.apiKey.secretFile;
    wire_api = "responses";
  };

  # ── 切换 profile:codex --profile chatgpt(默认) / zhipu / minimax ──
  # codex 无"模型→provider"映射,picker 选了别的 provider 的模型会打到错误端点 →
  # 非 openai provider 不进默认 picker,只走 profile(同时钉住 provider+model)
  #
  # 2026-08 决策:codex 默认 = ChatGPT 订阅(gpt 系)。glm 全家迁移到 opencode 侧:
  # codex 的智谱系 MCP(桥接)存在 0.147 prewarm 双 spawn 工具丢失 bug(见 mcpExcluded
  # 注释),glm 在 codex 侧只剩裸模型;且 ChatGPT 登录态会向所有 provider 会话叠加
  # OpenAI 官方指令。codex 专职 gpt + 快 server,glm/minimax 场景用 opencode
  providerProfiles =
    # zhipu profile:GLM 完整体(钉 provider+model + 静态目录,供偶尔回切)
    # model_catalog_json 不能放全局 —— 它是硬替换(StaticModelsManager,
    # model-provider/src/provider.rs),屏蔽 ChatGPT 登录态的后端动态目录,
    # 导致 login 后 picker 仍只有 glm、desktop 模型面板空白(2026-08 实测)
    {
      ${defaultProvider} = {
        model = p.defaultModel;
        model_context_window = p.models.${p.defaultModel}.contextWindow;
        model_reasoning_effort = "max";
        model_catalog_json = "~/.codex/models.json";
      };
    }
    // lib.mapAttrs' (n: v: lib.nameValuePair n {
      model_provider = n;
      model = v.defaultModel;
      model_context_window = v.models.${v.defaultModel}.contextWindow;
    }) (lib.filterAttrs (n: _: n != defaultProvider) codexProviders);
  # chatgpt 不是生成的 profile —— 它就是全局默认(下方 settings),无需切换入口
in
{
  # ── codex 核心:CLI(pkgs.codex,模块默认)+ config.toml 声明式 ──
  programs.codex = {
    enable = true;
    settings = {
      # 默认 = ChatGPT 订阅(内置 openai provider + codex login 登录态,Plus 订阅):
      # 模型目录从 ChatGPT 后端动态拉取(后端序列:gpt-5.6-sol/terra/luna/5.5/...),
      # 无 env_key 依赖;glm/minimax 走 profile 切换(见 providerProfiles 注释)
      model = "gpt-5.6-sol";
      model_provider = "openai";
      # gpt 系 reasoning 最高 xhigh(max 是 GLM 专属档)
      model_reasoning_effort = "xhigh";
      # 模型目录不设(全局硬替换会屏蔽 ChatGPT 动态目录,见 providerProfiles 注释)
      # 版本由 nix 管理,关启动更新检查(与 opencode autoupdate=false 同理)
      check_for_update_on_startup = false;
      # 注:codex_apps(connectors)依赖 ChatGPT 登录态(~/.codex/auth.json,codex login 产生),
      # 已登录,保持默认开启;其工具列表从 chatgpt.com 后端拉取,冷启动较慢属正常

      # 全部 codex 可用 provider(含 zhipu/minimax)自动派生:
      # 0.84+ 移除 chat wire_api,各 responses 端点见 common/providers.nix
      model_providers = lib.mapAttrs toCodexProvider codexProviders;

      mcp_servers = codexMcp;

      # ── 项目信任:nixos-config 本体声明式登记(bootstrap);其余项目走 TUI
      # 信任屏,写入由下方 home.activation.codexMutableConfig 物化的可写文件 ──
      projects."${config.home.homeDirectory}/nixos-config".trust_level = "trusted";
    };

    # 全局规则:codex 原生读 CODEX_HOME/AGENTS.md
    # context 只收 lines/path 字面量,derivation 会被误判为 text → readFile 内联
    context = builtins.readFile common.project.globalAgentsMd;

    # provider 切换 profile:codex --profile minimax(见上 providerProfiles 注释)
    profiles = providerProfiles;

    skills = codexSkills;
  };

  # ── 模型目录:~/.codex/models.json(config.toml 的 model_catalog_json 指向它)──
  home.file.".codex/models.json".source = modelsJson;

  # ── config.toml 物化为可写文件:修信任屏 batchWrite 失败 ──
  # codex 运行时会写 config.toml(信任屏 [projects]/TUI 主题/hook 开关等,
  # 见 codex-rs ConfigEditsBuilder),只读 symlink 下信任屏永远报错。而 HM 的
  # linkGeneration 对挡路的普通文件按 backupFileExtension 挪 .backup,残留
  # 会在下次 switch 撞 clobber。方案(显式锚定顺序,不依赖 dag 平级排序):
  #   capture     checkLinkTargets 前:把物化过的运行时文件拆走 —— [projects.*]
  #               块(信任/untrusted,精确路径键无通配)存入缓存,文件删除 →
  #               linkGeneration 无冲突,全程不产生 .backup;其余运行时键
  #               (主题等)以 nix 为准,丢弃
  #   materialize linkGeneration 后:新 symlink 物化为 600 普通文件,续回缓存
  #               里新配置没有的 projects 块(声明式已有的路径,声明式赢)
  # 激活中断于两段之间时 config.toml 暂为 symlink(信任屏会再报错一次),
  # 下次激活 materialize 自动补齐,自愈
  home.activation.codexConfigCapture = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    codex_capture() {
      local cfg="$HOME/.codex/config.toml" cache="$HOME/.codex/.projects.cache"
      [ -f "$cfg" ] && [ ! -L "$cfg" ] || return 0
      awk '/^\[projects\./ { keep = 1; print; next }
           /^\[/           { keep = 0; next }
           keep { print }' "$cfg" >"$cache" || :
      rm -f "$cfg"
    }
    codex_capture
  '';

  home.activation.codexConfigMaterialize = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    codex_materialize() {
      local cfg="$HOME/.codex/config.toml" cache="$HOME/.codex/.projects.cache"
      [ -L "$cfg" ] || return 0
      local src tmp extra
      src="$(readlink -f "$cfg")"
      tmp="$(mktemp "$HOME/.codex/.config.toml.XXXXXX")"
      cat "$src" >"$tmp"
      if [ -s "$cache" ]; then
        extra="$(awk -v known="$src" '
          BEGIN { while ((getline l < known) > 0) seen[l]=1 }
          /^\[projects\./ { keep = !(($0) in seen); if (keep) print; next }
          /^\[/            { keep = 0; next }
          keep { print }
        ' "$cache")"
        [ -z "$extra" ] || printf '\n%s\n' "$extra" >>"$tmp"
      fi
      chmod 600 "$tmp"
      mv -f "$tmp" "$cfg"
    }
    codex_materialize
  '';

  # ── 桌面端(unified ChatGPT/Codex,PR #551713 打包)──
  # resources/codex symlink 到 pkgs.codex,与上面 CLI 同一二进制
  home.packages = [ pkgs.chatgpt ] ++ skillPkgs;

  # ── Provider/MCP key 注入进程环境(codex env_key/bearer_token_env_var 读这里)──
  programs.bash.initExtra = lib.concatStringsSep "\n"
    (map (s: ''  [ -f ${s.secretFile} ] && export ${s.env}="$(cat ${s.secretFile})"'') secretEnvExports);

  # ── 项目级渲染器(被 agent sync 调用)──
  # 契约:$1 = manifest 路径, $2 = 项目根
  # codex 树配置 <git-root>/.codex/config.toml 覆盖全局(mcp_servers 不在项目层拒绝列表)
  # 注意:树配置需项目被信任(codex 首次进入新项目的信任提示)才生效
  xdg.configFile."ai/renderers/codex.sh" = {
    source = pkgs.writeShellScript "codex-render" ''
      MANIFEST="''${1:-$PWD/.agents/manifest.json}"
      ROOT="''${2:-$PWD}"
      CFG="$ROOT/.codex/config.toml"
      mkdir -p "$ROOT/.codex"
      for name in $(jq -r '.mcp[]?' "$MANIFEST" 2>/dev/null); do
        if ! grep -q "^\[mcp_servers\.$name\]" "$CFG" 2>/dev/null; then
          printf '\n[mcp_servers.%s]\nenabled = true\n' "$name" >> "$CFG"
        fi
      done
    '';
    executable = true;
  };

  home.sessionVariables = skillEnv;
}
