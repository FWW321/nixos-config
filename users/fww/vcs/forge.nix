# filepath: ~/nixos-config/users/fww/vcs/forge.nix
# 代码托管平台访问层(transport + 身份标记),数据驱动
# forges 列表(forges.nix)是唯一数据源:同时生成 ssh host 块 + git insteadOf + forge 用户名标记
# 系统级 gh hosts.yml 模板(modules/nixos/secrets.nix)也从 forges.nix 取 GitHub 用户名
# 加新 forge = 往 forges.nix 加一项,各消费处自动同源不漂移
#
# jj 的 git remote 交互(clone/fetch/push)均 spawn git 子进程(jj 无 insteadOf 配置项):
#   子进程读 ~/.gitconfig 的 insteadOf(https→ssh)→ 调 ssh 读 ~/.ssh/config 的 host 块(认证)
# 故本文件两层(insteadOf + ssh host 块)对 git 和 jj 同时生效,jj 侧零配置
# jj 的 commit 身份(name/email/signingkey)走 common 全局,不经此文件
# known_hosts(publicKey 不可推导)在系统层 modules/nixos/ssh.nix 独立声明
{ lib, osConfig, ... }:
let
  # 私钥由系统 sops 解密为 ~/.ssh/id_ed25519(见 modules/nixos/secrets.nix)；HM 经 osConfig 取路径
  identityFile = osConfig.sops.secrets.ssh_key.path;

  # ── 唯一数据源:加 forge 只动 forges.nix ──
  inherit ((import ./forges.nix)) forges;

  forgeName = f: builtins.head (lib.splitString "." f.host); # github.com → github
in
{
  # ssh host 块(transport + 认证)→ git/jj 共用 ~/.ssh/config
  programs.ssh.settings = builtins.listToAttrs (
    map (f: {
      name = f.host;
      value = {
        hostname = f.host;
        user = "git";
        inherit identityFile;
        identitiesOnly = true;
      };
    }) forges
  );

  programs.git.settings = {
    # https → ssh 重写:git 直读;jj 经 spawn 的 git 子进程间读
    url = builtins.listToAttrs (
      map (f: {
        name = "git@${f.host}:";
        value.insteadOf = "https://${f.host}/";
      }) forges
    );
  }
  # forge 用户名标记(ghub/magit forge 读此解析身份,git 本身忽略)
  // builtins.listToAttrs (
    map (f: {
      name = forgeName f; # github / codeberg → git config section
      value.user = f.username; # [github] user = ...  (ghub/magit forge 读,git 本身忽略)
    }) forges
  );

  # gh CLI:GitHub 官方命令行(与 github MCP server 共用同一 forge 身份)
  # 认证由系统 sops 模板渲染 ~/.config/gh/hosts.yml(见 modules/nixos/secrets.nix),无需 gh auth login
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh"; # 与 forge.nix 的 https→ssh 重写一致
      editor = "nvim";
    };
  };
}
