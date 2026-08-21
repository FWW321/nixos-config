# filepath: ~/nixos-config/users/fww/vcs/lazygit.nix
# Lazygit - Git TUI
# editor 复用 common;pager 复用 default.nix 的 delta(读 git [delta] 段渲染,样式与 git/jj 同源)
{ common }:
{ ... }:
{
  programs.lazygit = {
    enable = true;
    enableBashIntegration = true; # 注入 `lg` shell wrapper
    settings = {
      gui.nerdFontsVersion = "3"; # 与 eza 图标字体一致
      git.paging = {
        colorArg = "always";
        pager = "delta"; # 复用 delta,与 git/jj 渲染同源
      };
      editor = common.editor; # nvim(与 git/jj 一致)
      promptToReturnFromSubprocess = false; # 子进程命令结束直接回 lazygit,免按回车
    };
  };
}
