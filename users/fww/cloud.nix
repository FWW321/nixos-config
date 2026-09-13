# filepath: ~/nixos-config/users/fww/cloud.nix
# 云服务域：租赁实例(AutoDL)的 SSH 接入 + 常驻隧道
#
# ── 归属依据 ──
# 租赁 GPU 实例既非开发工具链(development/)也非桌面应用(desktop/)，
# 其"主机档案+隧道服务"是独立的生命周期单元(随租随换)，故独立成域。
#
# ── 设计 ──
# 数据与逻辑分离：
#   cloud.hosts   → 实例档案(hostname/port/转发端口/用途)——换机/续租只改这里
#   其余全部由档案驱动生成(matchBlock + autossh 服务)，单一数据源
# 实例侧配套：公钥(users/fww/vcs/id_ed25519.pub)已写入 authorized_keys；
#   ComfyUI/JupyterLab/TensorBoard 由实例上 /root/autodl-tmp/*.sh 管理。
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # ── 实例档案(数据区) ──
  # port: AutoDL 中转端口,实例重建会变,换机时只改此文件
  # forwards: 本地端口转发(autossh -L),端口=实例服务端口
  clouds = {
    h3 = {
      hostname = "connect.bjb1.seetacloud.com";
      port = 44377;
      user = "root";
      # MiniMax H3 / ComfyUI(RTX PRO 6000 96GB, 2026-08 租用)
      forwards = [
        {
          local = 8188;
          remote = 8188; # ComfyUI WebUI
          # 钉死 IPv4 回环:不指定时 ssh 重连后可能只绑 [::1](curl 会回退,python/脚本连 127.0.0.1 直接拒绝)
          bind.address = "127.0.0.1";
        }
      ];
    };
  };
in
{
  # ── SSH 主机块(逻辑区,由档案驱动) ──
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # 全局兜底:所有 ssh 连接统一用 id_ed25519 一把身份钥(forge 认证/jj 签名/手动连机同源)
    # 不再为任何用途单独造钥;known_hosts 钉死见 modules/nixos/ssh.nix
    # settings = 新版 HM API(attr 名即 Host 模式,块内为 ssh_config 原生指令);
    # matchBlocks 已弃用(26.05 eval warning),转发用原生 LocalForward 字符串:
    # 显式 bind 127.0.0.1 —— 不指定时 ssh 重连后可能只绑 [::1]
    # (curl 会回退 IPv6,python/脚本连 127.0.0.1 直接拒绝)
    settings = {
      "*" = {
        IdentityFile = osConfig.sops.secrets.ssh_key.path;
        IdentitiesOnly = "yes";
      };
    }
    // lib.mapAttrs' (
      name: c:
      lib.nameValuePair name {
        HostName = c.hostname;
        Port = c.port;
        User = c.user;
        LocalForward = map (f: "127.0.0.1:${toString f.local} localhost:${toString f.remote}") c.forwards;
        ServerAliveInterval = 15;
        ServerAliveCountMax = 4;
      }
    ) clouds;
  };

  # ── 常驻隧道(逻辑区) ──
  # systemd 直管 ssh -N <host>(复用上面 matchBlock: 端口/隧道/保活单一数据源),
  # 登录后本地端口永远指向实例服务,无需手动 ssh;
  # 实例关机时本服务静默重连(ssh 秒败 → 10s 后重启),开机即恢复.
  # 2026-08-26 弃 autossh: 双层监督下 autossh 会僵死为"活着但零子进程"
  # (实例关机断链后实测),systemd 看 MainPID 存活便永不 Restart——
  # 单层 systemd 直管 ssh,退出即重启,监督者自身永不僵.
  systemd.user.services = lib.mapAttrs' (
    name: c:
    lib.nameValuePair "${name}-tunnel" {
      Unit = {
        Description = "云实例 ${name}(${c.hostname})SSH 隧道: ${
          lib.concatStringsSep ", " (
            map (f: "${toString f.local}→${c.hostname}:${toString f.remote}") c.forwards
          )
        }";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        # ExitOnForwardFailure: 端口没绑上就退出(让 systemd 重开,不假装活着)
        # ConnectTimeout: 实例关机时快速失败,不挂 TCP 等待
        ExecStart = "${pkgs.openssh}/bin/ssh -N -o ExitOnForwardFailure=yes -o ConnectTimeout=15 ${name}";
        Restart = "always";
        RestartSec = "10s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    }
  ) clouds;
}
