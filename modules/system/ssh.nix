# filepath: ~/nixos-config/modules/system/ssh.nix
# 系统级 SSH 信任根:host key 钉死
# 免首次连接交互(兑现可复现迁移)+ 防中间人
# forge 的 publicKey 不可从域名推导,注定独立声明;host key 几年一遇变更时手动更新
{ ... }:
{
  programs.ssh.knownHosts = {
    "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    "codeberg.org".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
  };
}
