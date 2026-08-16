# filepath: ~/nixos-config/users/fww/ai/dsh/profiles/web.nix
# web profile:in-box bundle 组合 + 第三方插件
#
# 第三方插件两种写法并存(按需选):
#  A) nixvim 式 typed(见下方 plugins.dsh-status-rotator):
#     enable + 想改的键,patch 行自动渲染,插件源自动进列表
#  B) 原始列表(profiles.web.plugins 直接列源)
{ pkgs, inputs, ... }:

{
  # ── A) typed 插件声明(nixdsh/plugins-modules/status-rotator.nix 提供)──
  # 短路径 typed 体验;回填 plugins.dsh-status-rotator(source 免声明)
  programs.dsh.status-rotator = {
    enable = true;
    # 该插件为纯 client-inject(无 cordis patch 行),typed 面仅 enable/profiles;
    # 带bundle patch 的插件可完整 typed(见 module 内注释)
  };

  programs.dsh.profiles.web = {
    plugins = [
      "@deepseek-ai/dsh-base"
      "@deepseek-ai/dsh-web-app"
      # ── B) 原始写法(与 A 等价,适合无 typed module 的插件)──
      # (pkgs.fetchFromGitHub {
      #   owner = "someone"; repo = "dsh-foo";
      #   rev = "v1.0"; hash = "sha256-...";
      # })
    ];
    # 手写 patch 行(用户层,覆盖 base/bundle 同 id 行;config 整行替换语义)
    # userPatches = [ { id = "system-prompt"; config.persona = "..."; } ];
  };
}
