# filepath: ~/nixos-config/modules/system/network.nix
# 网络配置：NetworkManager、蓝牙、dae 代理
{ config, pkgs, lib, inputs, ... }:

{
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd"; # iwd 比 wpa_supplicant 更现代、更快
  };

  # ── IPv6 公网地址说明 ──────────────────────────────────────────────
  # 路由器（中兴问天 BE7000 Pro+）LAN 口设为 passthrough（穿透）模式。
  # 原因：ISP 只分配了一个 /64 前缀，路由器 WAN 口已占用。IPv6 要求每个
  #   接口用不同子网，无法把同一个 /64 同时分配给 WAN 和 LAN 做路由。passthrough
  #   改为桥接，让 LAN 设备直接从 ISP 的 /64 获取公网地址，所有设备共享这个 /64
  #   （/64 有 2^64 个地址，足够所有设备）。替代方案 NAT6 只给 ULA 翻译地址，非真公网。
  #
  # 问题：dae（lan_interface: podman0/virbr0）的 auto_config_kernel_parameter 设了
  #   net.ipv6.conf.all.forwarding=1；NM 接管 enp7s0 时硬编码 accept_ra=0 +
  #   addr_gen_mode=NONE（NM 想用 NDISC/libndp 在用户态处理 RA，但 NDISC 在此环境
  #   不工作——实测无 AF_PACKET socket）。dae 只在 accept_ra==1 时升到 2，但 NM 先
  #   设了 0 → dae 检查不匹配 → 跳过。结果内核无法处理 RA（accept_ra=0），NM 的
  #   NDISC 也不工作 → IPv6 SLAAC 全断。
  #
  # 当前为何能用：开机时（NM/dae 启动前）内核用默认 accept_ra=1 处理了一次 RA，
  #   缓存了公网前缀，生成的公网地址在前缀生命周期内（约 3 天）持续有效，临时地址
  #   也会基于缓存前缀自动轮换。但前缀过期后内核无法续期（accept_ra=0），公网地址消失。
  #
  # 如果将来公网 IPv6 断了，用以下方案修复（任选其一）：
  #
  # 方案 A（推荐）：NM dispatcher 在连接激活后覆盖 sysctl，让内核持续处理 RA
  #   accept_ra=2 含义：即使 forwarding=1 也处理 RA（0=从不, 1=仅 forwarding=0 时）
  #   addr_gen_mode=0 含义：用 EUI64 从 RA 前缀生成 SLAAC 地址（1=不生成, NM 设的值）
  #   networking.networkmanager.dispatcherScripts = [{
  #     type = "basic";
  #     source = pkgs.writeShellScript "ipv6-accept-ra" ''
  #       case "$1:$2" in
  #         enp7s0:up|enp7s0:reapply)
  #           ${lib.getExe' pkgs.procps "sysctl"} -w net.ipv6.conf."$1".accept_ra=2
  #           ${lib.getExe' pkgs.procps "sysctl"} -w net.ipv6.conf."$1".addr_gen_mode=0
  #           ;;
  #       esac
  #     '';
  #   }];
  #
  # 方案 B：手动临时修复（重启后失效）
  #   sysctl -w net.ipv6.conf.enp7s0.accept_ra=2
  #   sysctl -w net.ipv6.conf.enp7s0.addr_gen_mode=0

  # DNS 解析 (dae 会接管 DNS 路由)
  services.resolved.enable = true;

  # 蓝牙
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true; # 电量显示等实验功能
      FastConnectable = true; # 更快的连接
    };
  };

  sops.secrets.lxy_url = { };

  sops.templates."dae/config.dae" = {
    path = "/etc/dae/config.dae";
    mode = "0400";
    owner = "root";
    restartUnits = [ "dae.service" ];
    content = ''
      
            global {
              wan_interface: auto
              lan_interface: podman0, virbr0
              dial_mode: domain
              log_level: info
              allow_insecure: false
              auto_config_kernel_parameter: true
              tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'
              tcp_check_http_method: HEAD
              udp_check_dns: 'dns.google:53,8.8.8.8,2001:4860:4860::8888'
              check_interval: 10m
              check_tolerance: 50ms
            }
      
            dns {
              upstream {
                alidns: 'udp://dns.alidns.com:53'
                googledns: 'tcp+udp://dns.google:53'
              }
              routing {
                request {
                  qname(geosite:category-ads-all) -> reject
                  qname(geosite:cn) -> alidns
                  fallback: googledns
                }
                response {
                  upstream(googledns) -> accept
                  !qname(geosite:cn) && ip(geoip:private) -> googledns
                  fallback: accept
                }
              }
            }
      
            subscription {
              lxy: 'https-file://${config.sops.placeholder.lxy_url}'
            }
      
            group {
              proxy {
                filter: subtag(lxy)
                policy: min_moving_avg
              }
              hk {
                filter: subtag(lxy) && name(keyword: '香港', keyword: 'HK')
                policy: min_moving_avg
              }
              tw {
                filter: subtag(lxy) && name(keyword: '台湾', keyword: 'TW')
                policy: min_moving_avg
              }
              sg {
                filter: subtag(lxy) && name(keyword: '新加坡', keyword: 'SG')
                policy: min_moving_avg
              }
              jp {
                filter: subtag(lxy) && name(keyword: '日本', keyword: 'JP')
                policy: min_moving_avg
              }
              kr {
                filter: subtag(lxy) && name(keyword: '韩国', keyword: 'KR')
                policy: min_moving_avg
              }
              vn {
                filter: subtag(lxy) && name(keyword: '越南', keyword: 'VN')
                policy: min_moving_avg
              }
              my {
                filter: subtag(lxy) && name(keyword: '马来西亚', keyword: 'MY')
                policy: min_moving_avg
              }
              th {
                filter: subtag(lxy) && name(keyword: '泰国', keyword: 'TH')
                policy: min_moving_avg
              }
              in {
                filter: subtag(lxy) && name(keyword: '印度', keyword: 'IN')
                policy: min_moving_avg
              }
              au {
                filter: subtag(lxy) && name(keyword: '澳大利亚', keyword: 'AU')
                policy: min_moving_avg
              }
              ca {
                filter: subtag(lxy) && name(keyword: '加拿大', keyword: 'CA')
                policy: min_moving_avg
              }
              us {
                filter: subtag(lxy) && name(keyword: '美国', keyword: 'US')
                policy: min_moving_avg
              }
              de {
                filter: subtag(lxy) && name(keyword: '德国', keyword: 'DE')
                policy: min_moving_avg
              }
              fr {
                filter: subtag(lxy) && name(keyword: '法国', keyword: 'FR')
                policy: min_moving_avg
              }
              uk {
                filter: subtag(lxy) && name(keyword: '英国', keyword: 'UK')
                policy: min_moving_avg
              }
            }
      
            routing {
              dport(22) -> direct
              pname(NetworkManager, systemd-resolved) -> must_direct
              dip(224.0.0.0/3, 'ff00::/8') -> direct
              dip(geoip:private) -> direct

              domain(geosite:category-ads-all) -> block
      
              dscp(0x4) -> direct
      
              pname(steam, Counter-Strike) -> direct
              # qBittorrent 必须直连：BT 是 P2P，走代理会因 uTP/DHT UDP 丢包、
              # 代理限连接数/限速导致速度崩溃。代价是真实 IP 暴露给 peer/tracker
              # （BT 本质，无解；要匿名只能切 BT 友好的 VPN 并绑 wg0 接口）
              pname(qbittorrent-nox) -> direct
              domain(geosite:category-games@cn) -> direct
              # Steam 创意工坊/社区走代理（steamcommunity.com 国内被墙），其余走直连
              domain(suffix: steamcommunity.com) -> proxy
              domain(geosite:steam) -> direct
      
              domain(geosite:apple@cn) -> direct
              domain(geosite:tencent) -> direct
              domain(geosite:category-ai-cn) -> direct
              domain(geosite:category-bank-cn, geosite:category-finance) -> direct
      
              domain(geosite:cn) -> direct
              dip(geoip:cn) -> direct

              domain(geosite:anthropic, suffix: claude.ai) -> us
              domain(geosite:openai) -> us
      
              domain(geosite:netflix) -> jp
              domain(geosite:spotify) -> jp
              domain(geosite:twitch) -> us
      
              domain(geosite:youtube) -> us
              domain(geosite:reddit) -> us
              domain(geosite:twitter) -> us
              domain(geosite:facebook) -> us
              domain(geosite:instagram) -> us
              domain(geosite:telegram) -> us
              domain(suffix: discord.com, discord.gg) -> us
              domain(suffix: t.me, telegram.org) -> us
      
              domain(geosite:google) -> jp
              domain(suffix: esjzone.one, esjzone.cc) -> tw
      
              fallback: proxy
            }
    '';
  };

  # ── dae 代理 ──────────────────────────────────────────────
  # ⚠️ 已知坑：nixpkgs 的 services/networking/dae.nix 用 systemd LoadCredential 把配置注入
  #    只读 tmpfs（${CREDENTIALS_DIRECTORY}/config.dae）。但 dae 拉订阅需要在 config 同目录
  #    创建 persist.d 缓存 → 只读导致 mkdir 失败 → 订阅全部解析失败 → "no dialer in this
  #    group"，proxy 组无节点，网络全断。
  # 解决：用 daeuniverse/flake.nix 的 module（它 disabledModules 主动禁用 nixpkgs 版本，
  #    改用可写 /etc/dae/config.dae，无此坑）+ unstable 包跟进最新 main 提交。
  # 若将来切回 nixpkgs：必须 override ExecStart/ExecStartPre，用 list ["" "新命令"]
  #    （第一个 "" 是 systemd 清空指令，避免 "more than one ExecStart" 冲突），把 -c 指回
  #    可写的 /etc/dae/config.dae。定期 nix flake update dae 可拉新 unstable。
  services.dae = {
    enable = true;
    configFile = config.sops.templates."dae/config.dae".path;
    package = inputs.dae.packages.${pkgs.stdenv.hostPlatform.system}.dae-unstable;
  };
}
