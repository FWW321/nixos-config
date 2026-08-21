# filepath: ~/nixos-config/modules/nixos/ssh.nix
# SSH 全栈:OpenSSH 服务安全基线 + 系统级信任根(host key 钉死)
# 信任根免首次连接交互(兑现可复现迁移)+ 防中间人:
# forge 的 publicKey 不可从域名推导,注定独立声明;host key 几年一遇变更时手动更新
_: {
  # OpenSSH 安全配置
  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
    ];
  };

  programs.ssh.knownHosts = {
    "github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    "codeberg.org".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
  };
}
