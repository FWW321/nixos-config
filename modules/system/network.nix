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

  sops.templates."dae/config.dae" = {
    path = "/etc/dae/config.dae";
    mode = "0400";
    owner = "root";
    restartUnits = [ "dae.service" ];
    content = ''
      
            global {
              wan_interface: auto
              # lan_interface: podman0, virbr0  # rootless podman 不创建网桥；将来启用 libvirt 再加回
              dial_mode: domain
              log_level: info
              allow_insecure: false
              auto_config_kernel_parameter: true
              # dae 给自身 UDP 打 mark（默认 0x100）防自劫持回环；显式写 0 消除每次
              # 启动/reload 的 "so_mark_from_dae is unset" WARN，行为不变（官方示例同款）
              so_mark_from_dae: 0
              # 域名形式的 DNS 上游（alidns）需先解析；显式声明 bootstrap，免依赖
              # 内置默认（119.29.29.29→223.5.5.5）。国内域名国内解析，明文无污染风险
              bootstrap_resolver: '223.5.5.5:53'
              # tcp_check_url / tcp_check_http_method / udp_check_dns 用内置默认值，不显式写
              check_interval: 10m
              check_tolerance: 50ms
            }
      
            dns {
              upstream {
                alidns: 'udp://dns.alidns.com:53'
                # 明文 53 出境会被 GFW 注入假答案（曾把 chatgpt.com 解析到 Twitter/Meta
                # 段的垃圾 IP，全靠 dial_mode:domain 兜底才没全断）。改 DoH 且直接写 IP：
                # 免 bootstrap_resolver；配合 routing 里 dip(8.8.8.8, 8.8.4.4) -> proxy
                # 让 DNS 查询走代理隧道，同时避开明文注入和 DoH 直连封锁（已实测连通+证书 OK）
                googledns: 'https://8.8.8.8/dns-query'
              }
              routing {
                request {
                  qname(geosite:category-ads-all) -> reject
                  # 禁 ECH（官方 dns.md 现行示例）：HTTPS RR 携带 ECHConfig 会让浏览器加密
                  # ClientHello → dae 嗅探不到 SNI → dial_mode:domain 退化为按 IP 拨号、
                  # domain 分流全部失效（AI 域名会掉进 fallback:proxy 飘 IP）。拒答后客户端
                  # 回落明文 SNI，嗅探和分流保住
                  qtype(https) -> reject
                  # AI 域名拒 AAAA：dae 对 tcp4/tcp6 分栈选节点，双栈会话 = 同时两个
                  # 出口 IP，触发 OpenAI/Anthropic 风控掐长连接。只留 A → 单栈单出口
                  qtype(28) && qname(geosite:openai, geosite:anthropic, suffix: claude.ai) -> reject
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
              # AI 防封专用组：固定日本节点（policy:min 锁到延迟最低那一个，节点失效才切）
              # 不能复用 jp 组（min_moving_avg 会飘 IP → 触发 OpenAI/Anthropic 风控首信号）
              # check_tolerance 组级覆盖全局 50ms：容差太小导致 24h 内 codex 飘过 5 个
              # 节点（日本高速01-05 都被选中过）。250ms = 当前节点劣化超 250ms 才切换，
              # 健康时锁死单节点，真故障仍会切换
              ai {
                filter: subtag(lxy) && name(keyword: '日本', keyword: 'JP')
                policy: min
                check_tolerance: 250ms
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
              # 只放行 NM 且用普通 direct：must_direct 会连 DNS 一起豁免劫持
              # （dae 文档：direct 仍劫持 DNS 走 dns 段分流，must_direct 不劫持）。
              # systemd-resolved 必须留在劫持范围内，否则本机 DNS 明文直发路由器，
              # dns 段的 DoH/广告 reject/AAAA reject 全部失效（GFW 污染就是这么漏进来的）
              pname(NetworkManager) -> direct
              dip(224.0.0.0/3, 'ff00::/8') -> direct
              dip(geoip:private) -> direct

              # 禁 QUIC/h3（官方示例规则，默认不开）：强制浏览器回落 TCP+明文 SNI，
              # 嗅探/分流更稳、省 CPU/内存；代价是 YouTube 等失去 h3。当前选择保留 h3
              # 速度——SNI 嗅探已有 dns 段 qtype(https) -> reject（禁 ECH）保障；
              # 若日后分流出现嗅探失败（连接走 fallback:proxy 飘 IP），取消下一行注释
              # l4proto(udp) && dport(443) -> block

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

              # linux.do 走美国（需在 geosite:cn 直连规则之前，避免被收录后命中直连）
              domain(suffix: linux.do) -> us

              # dae 自身 DoH 上游（8.8.8.8/8.8.4.4）走代理，见 dns.upstream 注释
              dip(8.8.8.8, 8.8.4.4) -> proxy

              # AI 规则必须排在 geosite:cn / geoip:cn 直连之前：DNS 污染会把 openai 域名
              # 解析到垃圾 IP，若某个垃圾 IP 恰好落国内段，会被 dip(geoip:cn) 抢先直连假 IP
              domain(geosite:anthropic, suffix: claude.ai) -> ai
              domain(geosite:openai) -> ai

              domain(geosite:cn) -> direct
              dip(geoip:cn) -> direct
      
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

  # 每天拉一次订阅：dae reload 会重新 fetch 订阅（写入 persist.d/），不断连、不卸 eBPF
  systemd.services.dae-reload = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.services.dae.package}/bin/dae reload";
    };
  };

  systemd.timers.dae-reload = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "10m"; # 避开整点，防止订阅端限流
      # dae.service 开机启动时本就会拉一次订阅，这里的补跑实为冗余；
      # 留作兜底：开机时网络未就绪导致拉取失败（回退 persist.d 旧缓存）时多一次重试
      Persistent = true;
    };
  };
}
