# filepath: ~/nixos-config/modules/nixos/chrome.nix
# Google Chrome 系统级扩展策略
#
# 为什么在系统域:HM 的 programs.google-chrome 在 Linux 上断言禁用 extensions
# (私有 Chrome 只认系统级外部扩展目录,用户目录装不进)→ 声明式装扩展只能走
# Chrome 官方策略目录 /etc/opt/chrome/policies/managed/(environment.etc)。
# 目录只被 google-chrome stable 读取,不影响 chromium(/etc/chromium)与
# brave(/etc/brave)。
#
# installation_mode=normal_installed:自动安装,用户仍可禁用/移除 —— 与 zen 侧
# HM extensions.packages 的行为对齐(非 forcelist 的不可卸载强锁)。
# 副作用:任何策略存在都会让 Chrome 菜单显示"由贵单位管理",属固有提示。
{
  environment.etc."opt/chrome/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionSettings = {
      # 陪读蛙 Read Frog(zen 侧同款,AMO 自打包见 users/fww/browsers/zen.nix;
      # chrome 走官方商店,无需打包)
      "modkelfkcfjpgbfmnbnllalkiogfofhb" = {
        installation_mode = "normal_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };
      # KISS Translator(brave 时代旧扩展,一并迁入;不用删本条即可)
      "bdiifdefkgmcblbcghdlonllpjhhjgof" = {
        installation_mode = "normal_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };
    };
  };

  # WebRTC 防泄漏:本机持公网 IPv6(passthrough),授过 mic/cam 权限的页面可从
  # ICE host candidate 读到真实地址——候选是信令层数据,dae 网络层拦不住。
  # disable_non_proxied_udp 压制一切非代理 UDP 候选 → 只剩 TURN 中继
  # (TURN over TCP 443 照走 dae fallback:proxy),通话保留、host 候选不再泄漏。
  # "由贵单位管理"菜单提示与 extensions.json 相同,属固有副作用
  environment.etc."opt/chrome/policies/managed/webrtc.json".text = builtins.toJSON {
    WebRtcIPHandling = "disable_non_proxied_udp";
  };
}
