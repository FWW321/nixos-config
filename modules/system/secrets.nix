# filepath: ~/nixos-config/modules/system/secrets.nix
# 系统级 sops 单实例：全部 secret 集中在此声明，root 于激活期用 host ssh key 解密到
# /run/secrets（tmpfs，不落盘）。HM 不再跑独立 sops（无双实例、host key 无需对用户可读）。
#
# 消费契约：
#   - NixOS/HM 模块内引用 config.sops.secrets.<name>.path（HM 侧经 osConfig.sops...）
#   - 无法解引用 config 的场景（nvim lua / emacs elisp / CLI 凭证脚本）用固定路径 /run/secrets/<name>
#   - 含 secret 的配置文件用 sops.templates 渲染（placeholder 激活期替换），token 不经手 shell
{ config, lib, ... }:

let
  # gh hosts.yml 模板需要 GitHub 用户名，与 forge.nix 同源（forges.nix 是唯一数据源）
  forges = (import ../../users/fww/vcs/forges.nix).forges;
  ghUser = (lib.findFirst (f: f.host == "github.com") { } forges).username or "";
in
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      user_password.neededForUsers = true;
      github_token.owner = "fww";
      # codeberg_token.owner = "fww";  # 备用,暂未接消费者
      crates_token.owner = "fww";
      zhipu_api_key.owner = "fww";
      siliconflow_api_key.owner = "fww";
      context7_key.owner = "fww";
      # hf_token.owner = "fww";
      # civitai_token.owner = "fww";
      motion_plus_token.owner = "fww";
      exa_api_key.owner = "fww";
      lxy_url = { };
      # ssh 私钥：symlink 到 ~/.ssh/vcs_key，git/jj 认证与签名同源
      # 对应公钥非秘密，已提交 users/fww/vcs/vcs_key.pub；换钥时两处同步更新
      vcs_ssh_key = {
        owner = "fww";
        path = "/home/fww/.ssh/vcs_key";
      };
    };

    templates = {
      # gh CLI 认证：渲染 hosts.yml（替代原 HM ghAuth activation，token 不落盘明文脚本）
      # 副作用与 cargo 同理：gh auth login/refresh/logout 不可用（symlink 指向只读 /run，凭证由 sops 管）
      gh-hosts = {
        path = "/home/fww/.config/gh/hosts.yml";
        owner = "fww";
        content = ''
          github.com:
              oauth_token: ${config.sops.placeholder.github_token}
              user: ${ghUser}
              git_protocol: ssh
        '';
      };
      # nix 二进制缓存的 GitHub access token（nix.conf include 此文件；替代原 HM activation）
      nix-access-tokens = {
        path = "/home/fww/.config/nix/access-tokens.conf";
        owner = "fww";
        content = ''
          access-tokens = github.com=${config.sops.placeholder.github_token}
        '';
      };
    };
  };
}
