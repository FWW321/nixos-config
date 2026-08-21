# filepath: ~/nixos-config/users/fww/vcs/default.nix
# 版本控制系统：Git + Jujutsu
# 公共配置(common 变量 + 共享包 + delta + 签名公钥)集中在此
# git.nix/jj.nix 只保留各自特有的 settings,引用 common
{ pkgs, ... }:
let
  # ── 公共身份 + 偏好(所有 VCS 共享)──
  common = {
    name = "fww";
    email = "3223400498@qq.com";
    editor = "nvim";
    # SSH 签名公钥路径(forge 认证 + commit 签名同一把 key)
    # 私钥由系统 sops 解密为 ~/.ssh/id_ed25519,公钥见下方 home.file(非秘密,进仓库)
    signingKey = "~/.ssh/id_ed25519.pub";
  };
in
{
  imports = [
    (import ./git.nix { inherit common; })
    (import ./jj.nix { inherit common; })
    (import ./lazygit.nix { inherit common; })
    ./forge.nix                       # forge 访问层(数据驱动,不经 common)
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

  # ── SSH 签名/认证公钥(声明式) ──
  # 私钥:系统 sops 解密为 ~/.ssh/id_ed25519(symlink→/run/secrets,见 modules/nixos/secrets.nix)
  # 公钥:非秘密,直接进仓库;换钥时更新 secrets.yaml 与 ./id_ed25519.pub 两处
  home.file.".ssh/id_ed25519.pub".source = ./id_ed25519.pub;
}
