# filepath: ~/nixos-config/modules/system/torrents.nix
# qBittorrent-nox：headless BT 客户端（WebUI + systemd 常驻）
# nixpkgs 模块默认 package=qbittorrent-nox，自带全套 systemd 沙箱硬化
# （ProtectSystem=full / MemoryDenyWriteExecute / SystemCallFilter=@system-service 等）
{ ... }:

let
  btPort = 51413;                      # BT 监听端口（默认 Port=-1 随机，需固定才能开防火墙）
  downloadDir = "/data/public/torrents";
in
{
  services.qbittorrent = {
    enable = true;
    openFirewall = true;               # 模块自动开 TCP（v4+v6 双栈，NixOS firewall 用 ip46tables）
    webuiPort = 8080;
    torrentingPort = btPort;           # 命令行 --torrenting-port 注入，覆盖配置 Port=-1

    serverConfig = {
      LegalNotice.Accepted = true;     # qBittorrent 4.5+ 必须接受，否则 WebUI 卡欢迎页

      BitTorrent.Session = {
        # 路径（默认是 OS Downloads 目录 + ./temp 子目录，需明确指向共享区）
        DefaultSavePath = "${downloadDir}/";
        TempPath = "${downloadDir}/.incomplete/";
        TempPathEnabled = true;        # 默认 false，启用半成品暂存
        TorrentContentLayout = "Subfolder";  # 默认 Original；Subfolder = 按种子名建子目录
        TorrentExportDirectory = "${downloadDir}/";  # 添加种子时把 .torrent 文件复制到下载目录

        # IPv6：默认监听双栈（InterfaceAddress=""），无需 EnableIPv6（此键不存在）
        # 注：BT 本就是 P2P，v4/v6 都会暴露 IP 给 peer，真正匿名只能走 VPN（与 dae 无关）

        LSDEnabled = false;            # 默认 true；LSD 局域网发现对你无意义且会广播存在
        # 其余默认值已是最佳：DHTEnabled/PeXEnabled/BTProtocol=Both/Encryption=0(优先加密)
        # AnonymousModeEnabled=false/MaxConnections=500/MaxConnectionsPerTorrent=100
      };

      Preferences.WebUI = {
        Address = "127.0.0.1";         # 默认 "*"（全网卡）；收紧到本地，远程走 SSH 隧道
        LocalHostAuth = false;         # 默认 true；关掉 → localhost 免登录（SSH 隧道已认证，再加一层冗余）

        # headless 模式下 Password_PBKDF2 必须设固定值（任意合法字符串即可），
        # 否则每次启动随机生成临时密码打印到 stdout（application.cpp:1006-1042）。
        # LocalHostAuth=false 后此 hash 不会被实际验证，但 webui.cpp:65 要求非空。
        # 如未来开 LAN 访问 / 关 SSH 隧道，用真实 hash 替换：
        #   nix run github:feathecutie/qbittorrent_password -- "YOUR_PASSWORD"
        Password_PBKDF2 = "@ByteArray(AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=)";
      };
    };
  };

  # ── UDP 端口（模块 openFirewall 只开 TCP；BT 还需 UDP 跑 DHT/uTP/tracker）──
  networking.firewall.allowedUDPPorts = [ btPort ];

  # ── 下载目录（沿用 users.nix 的 shared 组 + setgid 2775 规约）────────
  users.users.qbittorrent.extraGroups = [ "shared" ];
  systemd.tmpfiles.rules = [
    "d ${downloadDir} 2775 root shared - -"
    "d ${downloadDir}/.incomplete 2775 root shared - -"
  ];

  # ── 内存上限（防 libtorrent 在大量 torrent 时吃光 RAM）────────────────
  systemd.services.qbittorrent.serviceConfig.MemoryMax = "2G";
}
