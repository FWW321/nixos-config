# filepath: ~/nixos-config/users/fww/desktop/xdg-user-dirs.nix
# XDG 用户目录:声明式生成 ~/.config/user-dirs.dirs + 建目录
#
# 动机:NixOS 不像 Ubuntu 默认跑 xdg-user-dirs-update,缺这个文件时
# dirs::document_dir() 等返回 None —— koharu(Tauri setup hook 直接
# panic "the Documents directory is unavailable",2026-08-21 实测)及
# 所有 XDG user-dirs 消费者(浏览器下载目录/文件选择器等)都会受影响。
#
# 名字全部显式钉英文:留默认时 xdg-user-dirs-update 按 locale 生成
# (zh_CN 会造 文档/下载/桌面 并列于既有英文目录),不做这种惊喜
_:

{
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    publicShare = "$HOME/Public";
    templates = "$HOME/Templates";
    videos = "$HOME/Videos";
  };
}
