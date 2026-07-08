# filepath: ~/nixos-config/users/fww/vcs/forge.nix
# 代码托管平台访问层(transport + 身份标记),数据驱动
# forges 列表是唯一数据源:同时生成 ssh host 块 + git insteadOf + forge 用户名标记
# 加新 forge = 往列表加一项,三处自动同源不漂移
#
# jj 的 git remote 交互(clone/fetch/push)均 spawn git 子进程(jj 无 insteadOf 配置项):
#   子进程读 ~/.gitconfig 的 insteadOf(https→ssh)→ 调 ssh 读 ~/.ssh/config 的 host 块(认证)
# 故本文件两层(insteadOf + ssh host 块)对 git 和 jj 同时生效,jj 侧零配置
# jj 的 commit 身份(name/email/signingkey)走 common 全局,不经此文件
# known_hosts(publicKey 不可推导)在系统层 modules/system/ssh.nix 独立声明
{ config, lib, ... }:
let
  identityFile = config.sops.secrets.vcs_ssh_key.path;  # 全局复用同一把 key(认证/签名同源)

  # ── 唯一数据源:加 forge 只动这里 ──
  forges = [
    { host = "github.com";   username = "FWW321"; }
    { host = "codeberg.org"; username = "FWW"; }
  ];

  forgeName = f: builtins.head (lib.splitString "." f.host);  # github.com → github
in
{
  # ssh host 块(transport + 认证)→ git/jj 共用 ~/.ssh/config
  programs.ssh.settings = builtins.listToAttrs (map (f: {
    name = f.host;
    value = {
      hostname = f.host;
      user = "git";
      inherit identityFile;
      identitiesOnly = true;
    };
  }) forges);

  programs.git.settings =
    { # https → ssh 重写:git 直读;jj 经 spawn 的 git 子进程间读
      url = builtins.listToAttrs (map (f: {
        name = "git@${f.host}:";
        value.insteadOf = "https://${f.host}/";
      }) forges);
    }
    # forge 用户名标记(ghub/magit forge 读此解析身份,git 本身忽略)
    // builtins.listToAttrs (map (f: {
      name = forgeName f;          # github / codeberg → git config section
      value.user = f.username;     # [github] user = ...  (ghub/magit forge 读,git 本身忽略)
    }) forges);
}
