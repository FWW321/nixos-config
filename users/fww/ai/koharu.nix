# filepath: ~/nixos-config/users/fww/ai/koharu.nix
# Koharu — ML 漫画翻译桌面应用(Tauri + CEF,本地推理)
#
# 包与 HM 模块在独立仓库 koharu-nix(github:FWW321/koharu-nix,
# 同 nixdsh/zcode-nix 模式):flake input overlay 提供 pkgs.koharu,
# 此处只挂模块 + 声明个人配置。模块语义(settings 对账/cacheDir/
# apiKeys keyutils 注入/卸载回收)见 koharu-nix/modules/koharu.nix 头注释。
#
# 数据落点:项目 ~/Documents/Koharu/,缓存 ~/.cache/koharu/(runtime+
# 模型 5-8GB,首启下载),配置 ~/.koharu/config.toml(GUI 活跃写区,
# settings 走节级对账不整文件接管)。
# 界面语言/主题是 CEF localStorage 前端状态,GUI 点一次即可,不归 nix 管。
#
# MiniMax 接线(2026-08-21 实测):
#   key 是国内站订阅(国内域 200 / 国际域 401)——koharu 内置 minimax
#   槽位写死 api.minimax.io(国际),直接用必 401 → 走 openai-compatible
#   槽位指向 api.minimaxi.com(与 common/providers.nix 的 minimax 同一
#   sops 条目 /run/secrets/minimax_api_key,单一 secret 双消费)。
#   anthropic 协议(api.minimaxi.com/anthropic,M3 实测通)在 koharu
#   0.77.4 无载体:claude 槽位的 ClaudeConfig 是空结构体,URL 编译期
#   写死 api.anthropic.com(源码 remote/claude.rs 实证,写 base_url 被
#   serde 静默丢弃);openai-compatible 槽位只讲 chat completions。
#   想走 anthropic 协议需上游 PR:ClaudeConfig 加 Option<Url> + 两处
#   URL 常量参数化(改动极小)。
{
  inputs,
  osConfig,
  lib,
  ...
}:

let
  # N 卡门控:宿主声明了 nvidia 驱动才部署 koharu(ML 推理的 CUDA 路径
  # 依赖它;非 N 卡机器上整个模块跳过,包/注入/对账全不发生)。
  # 求值期纯判断,无硬件探测;HM standalone(无 osConfig.services)时
  # 视为无 N 卡
  videoDrivers = osConfig.services.xserver.videoDrivers or [ ];
  hasNvidia = builtins.elem "nvidia" videoDrivers;
in
{
  imports = [ inputs.koharu-nix.homeManagerModules.koharu ];

  programs.koharu = {
    enable = hasNvidia;

    settings = {
      # MiniMax 国内域(OpenAI 协议,M3 实测通)
      providers.openai-compatible.base_url = "https://api.minimaxi.com/v1";
      pipeline.translation = {
        model = {
          provider = "openai-compatible";
          model = "MiniMax-M3";
          # M3 是推理模型(响应带 think 块),翻译场景关掉省 token/提速
          reasoning = false;
        };
        # 上游 PipelineConfig 反序列化必填(2026-08-22 闪退实证:
        # 缺 generation 即 "missing field `generation`" panic);
        # 深度合并后即便不写也会保留 GUI 已有值,但首启无存量时必须给
        generation = {
          reasoning = false;
          vision = true;
        };
        target_language = "zh-CN";
      };

      # 视觉管线模型(2026-08-22 选型,依据上游源码默认 + issues 实测:
      # 纯色气泡走快填不进模型,模型差异只在网纸/线稿/背景区域)。
      # 当前两值即上游默认,显式钉死防 GUI 误触;按症状换:
      #   OCR → manga-ocr:竖排振假名/手写体更强,长文本变弱(上游 #12)
      #   修补 → rorem-mixed:网纸被抹糊时上(漫画特化 SDXL,#341),
      #     每页慢一个量级;flux2-klein 生成上限最高也最慢
      pipeline.ocr.model = "paddleocr-vl-1.6";
      pipeline.inpainting.model = "lama";
    };

    # keyutils 注入:keyring:openai-compatible@koharu(运行时从 sops 读,
    # 每次登录重注入;GUI 手填的重启会丢,nix 管的不会)
    apiKeys.openai-compatible = "/run/secrets/minimax_api_key";

    # 缓存重定向(默认 ~/.cache;改值会重新下载 5-8GB,先手动 mv 旧缓存)
    # cacheDir = "/data/koharu";
  };
}
