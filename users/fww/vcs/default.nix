# filepath: ~/nixos-config/users/fww/vcs/default.nix
# 版本控制系统：Git + Jujutsu
# 公共配置(common 变量 + 共享包 + delta + 签名公钥生成)集中在此
# git.nix/jj.nix 只保留各自特有的 settings,引用 common
{ pkgs, lib, ... }:
let
  # ── 公共身份 + 偏好(所有 VCS 共享)──
  common = {
    name = "fww";
    email = "3223400498@qq.com";
    editor = "nvim";
    # SSH 签名公钥路径(访问 GitHub 的同一把 key 也用于签 commit)
    # ~/.ssh/github 是 sops 解密的私钥,对应 .pub 由下方 activation 从私钥导出
    signingKey = "~/.ssh/github.pub";
  };
in
{
  imports = [
    (import ./git.nix { inherit common; })
    (import ./jj.nix { inherit common; })
  ];

  # ── 共享包(vcs 域工具集中管理,git.nix/jj.nix 不再各自声明包)──
  # watchman: jj core.fsmonitor 依赖(git 用原生 fsmonitor 不需要,但集中管理避免散落)
  home.packages = [ pkgs.watchman ];

  # ── delta:Git + jj 共享的 diff 渲染器(HM 26.05+ 独立模块)──
  # enableGitIntegration 自动注入 git [interactive].diffFilter + [pager](blame/diff/log/show)
  # jj ui.pager="delta" 复用(delta 启动时读 git config [delta] 段继承样式)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # ── SSH 签名公钥生成 ──
  # sops 只解密私钥(~/.ssh/github),公钥需运行时从私钥导出,供 git/jj 签名验证
  # 幂等:每次部署刷新;ssh-keygen 失败则不留空文件(tmp 清理)
  home.activation.githubSigningPubkey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    GITHUB_KEY="$HOME/.ssh/github"
    if [ -f "$GITHUB_KEY" ]; then
      tmp=$(mktemp)
      if ${pkgs.openssh}/bin/ssh-keygen -y -f "$GITHUB_KEY" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$GITHUB_KEY.pub"
      else
        rm -f "$tmp"
      fi
    fi
  '';
}
