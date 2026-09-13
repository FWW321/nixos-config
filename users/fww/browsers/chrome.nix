# filepath: ~/nixos-config/users/fww/browsers/chrome.nix
# Google Chrome 配置
#
# 扩展声明式安装见 modules/nixos/chrome.nix:HM 的 chromium 系模块对
# google-chrome 在 Linux 上断言禁用 extensions(私有 Chrome 只认系统级外部
# 扩展目录),故走 /etc/opt/chrome/policies/managed 策略自动安装
_:

{
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [ "--restore-last-session" ];
  };
}
