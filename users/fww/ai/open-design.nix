# filepath: ~/nixos-config/users/fww/ai/open-design.nix
# Open Design — 本地优先的开源 Claude Design 替代品
#
# 通过 Home Manager 模块运行：daemon（od CLI，:7457）+ 内置 Caddy 提供 Web SPA（:5174）。
# 数据落在 ~/.od/。daemon 自动扫描 PATH 发现 agent CLI（opencode 等）。
#
# ── better-sqlite3 13 graft(崩溃根治,第二版补丁)──────────────────────
# nodejs 24.x ObjectWrap cleanup hooks 回归(#63642/#63923,修复 #63985 未
# 回补 v24)× better-sqlite3 12.10.0 Statement 析构 → GC 时机不巧即 ABRT
# (open-design#6462)。第一版补丁 = 重绑 node 24.18.1,实测同中招仅频率低,
# 已废弃。第二版 = pkgs/open-design-daemon-bsq13:整树 graft 13.0.3
# (N-API 重构,断言链结构性消失;npm 包自带 prebuilds/linux-x64.node,
# 零编译)——node 版本无关,跟随主 nixpkgs。
#
# 拆除条件:open-design lockfile bump 到 better-sqlite3 ≥13
# 届时删除本 let 块 + package 行 + flake.nix 的 overlay 行 + 包目录。
#
# 密钥说明：OD 不直接调 LLM，而是 spawn PATH 里的 agent CLI（你的 opencode）
# 来跑设计任务，模型 key 由 opencode 自己的配置负责 —— 默认无需在 OD 填任何 key。
# 媒体调度器（/api/tools/media/generate，od media generate）走四层注入：
#   1. OD_MINIMAX_API_KEY     — sops 模板（environmentFile），key 不落盘
#   2. OD_MINIMAX_IMAGE_BASE_URL — extraEnv；image 渲染器只认此 env，
#      刻意忽略 credentials.baseUrl（见 daemon media/index.js 注释）。
#      值不带 /v1（代码自己拼 ${base}/v1/image_generation）
#   3. TTS baseUrl 只能从 ~/.od/media-config.json 读（env 无此槽位），
#      默认域 api.minimaxi.chat 已拒收国内订阅 key（实测 invalid api key），
#      由 home.activation 幂等合并为 https://api.minimaxi.com/v1
#   4. OD_MEDIA_MODEL_ALIASES — daemon #1277 别名机制：ctx.wireModel ≠
#      ctx.model 时优先于硬编码 MINIMAX_TTS_MODEL_MAP，把 TTS 从内置的
#      speech-02-turbo(2024 代)升到 speech-2.8-hd
#      (2026-08-18 实测 t2a_v2 + 订阅 key 接受 2.8-hd，status 0)。
#      image-01 仍为当前旗舰无需别名；model 键(单模型钉死)不用，别名更细粒度。
# 视频：模型目录有 minimax-video-01 但无渲染器（0.19.2 源码确认），
# 走 mmx-cli skill 的 `mmx video generate`（原 minimax-media MCP 已移除）。
{ config, osConfig, pkgs, lib, inputs, ... }:

let
  # better-sqlite3 13 graft 包(flake.nix inline overlay 提供;
  # daemon 源与 dsh-runtime 同一 inputs.open-design pin)
  odDaemonFixed = pkgs.open-design-daemon-bsq13;
in
{
  services.open-design = {
    # bsq13 graft 后的 daemon(见文件头补丁说明);上游 bump bsq13 后
    # 还原为默认值(删除本行)即可
    package = odDaemonFixed;
    # 显式声明数据目录：SQLite + projects/<id>/ + artifacts/，与模块默认值一致
    dataDir = "${config.home.homeDirectory}/.od";
    enable = true;
    autoStart = true; # systemd --user 开机自启
    webFrontend.enable = true; # 起内置 Caddy，提供同源 SPA + /api 反代
    environmentFile = osConfig.sops.templates.open-design-env.path;
    extraEnv = {
      # dsh profile 探测前置检查(OD daemon hasOpenDesignProfile)读进程 env 的
      # DSH_HOME,缺省回退 ~/.dsh(与 nixdsh 物化位置不一致→误判"profile 缺失"
      # →弹"安装连接组件"窗)。
      # 注意:不能直接用 programs.dsh.dshHome 的值($HOME 字面量)——nixdsh 的
      # $HOME 约定靠 bash wrapper 展开,OD 的 systemd Environment= 不展开,
      # daemon 会把 $HOME 当相对路径。此处求值期替换为绝对路径,同一事实源
      DSH_HOME = lib.replaceStrings [ "$HOME" ] [ config.home.homeDirectory ]
        config.programs.dsh.dshHome;
      OD_MINIMAX_IMAGE_BASE_URL = "https://api.minimaxi.com";
      # TTS 模型升级：daemon 硬编码 speech-02-turbo(2024 代)，经 #1277 别名
      # 机制覆写为 speech-2.8-hd(见文件头注释第 4 点)。JSON 原文进 env，
      # 两个单引号串免转义
      OD_MEDIA_MODEL_ALIASES = ''{"minimax-tts":"speech-2.8-hd"}'';
    };
  };

  home.activation.od-media-config =
    lib.hm.dag.entryAnywhere # bash
    ''
      # MiniMax TTS 域名修正：media-config.json 是 OD 的可变设置文件（Settings
      # UI 整表重写），此处仅钉住 baseUrl 这一个键（声明式键声明式赢），
      # 其余 provider 条目/UI 编辑经 jq 原样保留
      _odCfg="$HOME/.od/media-config.json"
      mkdir -p "$HOME/.od"
      if [ -f "$_odCfg" ]; then
        _tmp=$(mktemp)
        if ${lib.getExe pkgs.jq} '.providers.minimax.baseUrl = "https://api.minimaxi.com/v1"' "$_odCfg" > "$_tmp"; then
          mv "$_tmp" "$_odCfg"
        else
          rm -f "$_tmp"
        fi
      else
        printf '%s' '{"providers":{"minimax":{"baseUrl":"https://api.minimaxi.com/v1"}}}' > "$_odCfg"
      fi
      unset _odCfg _tmp
    '';
}
