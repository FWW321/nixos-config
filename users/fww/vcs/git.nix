# filepath: ~/nixos-config/users/fww/vcs/git.nix
# Git 配置(从 users/fww/default.nix 迁出)
# common(name/email/editor)由 ./default.nix 注入,避免硬编码重复
{ common }:
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = common.name;
        email = common.email;
        signingkey = common.signingKey;  # SSH 签名 key(复用 ssh key)
      };
      github.user = "FWW321";       # GitHub 用户名(forge/ghub/gh CLI 读此解析身份,非 git 内置)
      init.defaultBranch = "main";
      core = {
        editor = common.editor;
        ignorecase = false;
        fsmonitor = true;         # Git 2.37+ 原生 fsmonitor(比 watchman 轻,jj 单独用 watchman)
      };
      gpg.format = "ssh";          # 用 SSH 签名(非 GPG)
      commit.gpgsign = true;       # 自动签名所有 commit(GitHub 上传 Signing Key 后显示 ✅ Verified)
      pull.rebase = true;
      push.autoSetupRemote = true;
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
