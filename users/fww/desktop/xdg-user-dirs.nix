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
#
# 项目根约定(2026-08-23):新项目一律 ~/Projects(含建模/非纯代码),
# extraConfig 的 XDG_PROJECTS_DIR 钉死该约定。存量 ~/code 冻结不迁:
# 里面是活跃 git 仓库,挪目录断点不可枚举(编辑器最近项/direnv 缓存/
# alias/会话路径记忆,只能撞上);待其活跃仓库归零后一次性 mv 收编为
# ~/Projects/code。迁移成本那天不会更高,今天的风险是实打实的
# —— 新标准只管增量,存量留给时间消化
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

    # XDG 扩展位(非常规七项):项目根。此前由历史残留生成,2026-08-23
    # 收进声明式,防配置重建时消失
    extraConfig = {
      XDG_PROJECTS_DIR = "$HOME/Projects";
    };
  };
}
