# filepath: ~/nixos-config/pkgs/jcode/hm-module.nix
# jcode Home Manager 模块 —— programs.jcode
# 与打包(default.nix)同目录内聚:关于 jcode 的一切都在 pkgs/jcode/
#
# settings 与 ~/.jcode/config.toml 一一对应(pkgs.formats.toml 生成,freeform,
# 同 programs.helix.settings 思路;上游每周多发版、config 面极大,逐键建模必腐化)
# 键定义与注释模板见上游 crates/jcode-base/src/config/default_file.rs
# (含 [keybindings] [display] [features] [provider] [agents] [terminal] [hooks] [safety] 等)
#
# 注意:
# - 环境变量优先于 config.toml;TUI 内 `/config` 可查看运行时生效值
# - jcode 运行时会写回此文件(如 /model Ctrl+B 保存默认模型);home.file 是只读
#   symlink,写回会把 symlink 替换成普通文件,下次 activation 被 backupFileExtension
#   收留 → 需要持久化的偏好统一写进 programs.jcode.settings
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.jcode;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.jcode = {
    enable = lib.mkEnableOption "jcode(Rust TUI AI 编码 agent)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jcode;
      defaultText = lib.literalExpression "pkgs.jcode";
      description = "jcode 包(本目录 default.nix 提供,已含 --no-update + 遥测禁用 wrapper)";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = {
        provider = {
          default_provider = "openai-compatible";
          default_model = "glm-4.7";
        };
        display.reasoning_display = "current";
      };
      description = ''
        写入 ~/.jcode/config.toml 的内容,节/键同名透传,如
        `settings.display.show_thinking = true` → `[display] show_thinking = true`。
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # 空配置也写文件:接管声明权,避免首启自动生成脱离 flake 管理的默认配置
    home.file.".jcode/config.toml".source =
      tomlFormat.generate "config.toml" cfg.settings;
  };
}
