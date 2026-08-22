# filepath: ~/nixos-config/modules/nixos/ssh.nix
# SSH 全栈:OpenSSH 服务安全基线 + 系统级信任根(host key 钉死) + askpass 助手
# 信任根免首次连接交互(兑现可复现迁移)+ 防中间人:
# forge 的 publicKey 不可从域名推导,注定独立声明;host key 几年一遇变更时手动更新
{ pkgs, ... }:
{
  # askpass:无 TTY 进程(GUI/agent/cron)要凭证时的弹窗助手。
  # 选 openssh-askpass(GTK,openssh 官方 contrib):随 openssh 主线维护;
  # GTK 弹窗经 Stylix 自动跟随全局主题;niri/Wayland 原生可用。
  # 替掉 NixOS 默认 x11_ssh_askpass(Xt,观感陈旧且无 Wayland 原生)。
  # 触发链:SSH_ASKPASS 由 enableAskPassword 全局导出 → ssh/GIT_ASKPASS
  # (git 缺省回落 SSH_ASKPASS)自动复用;SUDO_ASKPASS 显式同源(sudo -A)
  # 只在交互场景被唤醒,与密钥认证/NOPASSWD 白名单零冲突(分层让位)
  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass";
  };
  environment.sessionVariables.SUDO_ASKPASS = "${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass";

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
