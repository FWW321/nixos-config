# filepath: ~/nixos-config/modules/nixos/secrets.nix
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
  inherit ((import ../../users/fww/vcs/forges.nix)) forges;
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
      minimax_api_key.owner = "fww";
      siliconflow_api_key.owner = "fww";
      context7_key.owner = "fww";
      # hf_token.owner = "fww";
      # civitai_token.owner = "fww";
      motion_plus_token.owner = "fww";
      exa_api_key.owner = "fww";
      dae_tuic_url = { };
      dae_anytls_url = { };
      # 用户唯一 SSH 身份钥（id_ed25519）：forge 认证 + git/jj 签名 + 所有 ssh 连接（Host * 兜底）
      # 对应公钥非秘密，已提交 users/fww/vcs/id_ed25519.pub；换钥时两处同步更新
      ssh_key = {
        owner = "fww";
        path = "/home/fww/.ssh/id_ed25519";
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
      # Open Design daemon 的媒体调度器凭证（systemd EnvironmentFile 格式）。
      # OD 不经手 LLM key，但内置媒体 provider 需要；MiniMax 订阅 key 与
      # agents 侧 /run/secrets/minimax_api_key 同源，单一 sops 条目双消费。
      open-design-env = {
        owner = "fww";
        content = ''
          OD_MINIMAX_API_KEY=${config.sops.placeholder.minimax_api_key}
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

  # 落在 fww 家目录的 sops 产物,必须在 /home 挂载后物化 —— sops 自身的
  # activation 渲染跑在 stage-2(早于 systemd 挂载 /home),符号链接会建在
  # @root 子卷上、随后被 @home 子卷/独立盘挂载遮蔽:全新机器首装 ssh_key/
  # gh-hosts/access-tokens 三链全丢(VM 装机验证实测;真机此前靠旧世代残留
  # 链接掩盖)。tmpfiles-setup 时序天然正确(After=local-fs、Before=sysinit),
  # 每次开机幂等重建;路径自引用上方 sops 声明,单一真源
  systemd.tmpfiles.rules = [
    "d /home/fww/.config 0755 fww users - -"
    "d /home/fww/.ssh 0700 fww users - -"
    "d /home/fww/.config/gh 0755 fww users - -"
    "d /home/fww/.config/nix 0755 fww users - -"
    "L+ ${config.sops.secrets.ssh_key.path} - - - - /run/secrets/ssh_key"
    "L+ ${config.sops.templates.gh-hosts.path} - - - - /run/secrets/rendered/gh-hosts"
    "L+ ${config.sops.templates.nix-access-tokens.path} - - - - /run/secrets/rendered/nix-access-tokens"
  ];
}
