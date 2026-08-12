# Home-Manager 级 sops 声明（仅 HM 模块消费的 secret）
# 系统级声明在 modules/system/secrets.nix
{ config, ... }:

{
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../secrets/secrets.yaml;
    secrets = {
      vcs_ssh_key.path = "${config.home.homeDirectory}/.ssh/vcs_key";
      zhipu_api_key = { };
    };
  };
}
