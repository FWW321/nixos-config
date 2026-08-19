# filepath: ~/nixos-config/users/fww/ai/open-design.nix
# Open Design — 本地优先的开源 Claude Design 替代品
#
# 通过 Home Manager 模块运行：daemon（od CLI，:7457）+ 内置 Caddy 提供 Web SPA（:5174）。
# 数据落在 ~/.od/。daemon 自动扫描 PATH 发现 agent CLI（opencode 等）。
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
{ config, osConfig, pkgs, lib, ... }:

{
  services.open-design = {
    # 显式声明数据目录：SQLite + projects/<id>/ + artifacts/，与模块默认值一致
    dataDir = "${config.home.homeDirectory}/.od";
    enable = true;
    autoStart = true; # systemd --user 开机自启
    webFrontend.enable = true; # 起内置 Caddy，提供同源 SPA + /api 反代
    environmentFile = osConfig.sops.templates.open-design-env.path;
    extraEnv = {
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
