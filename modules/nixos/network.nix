# filepath: ~/nixos-config/modules/nixos/network.nix
# 网络配置：NetworkManager、蓝牙、dae 代理
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

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
  # ── dae 上游 bug 旁路(勿删,见文末"dae link-local DNS bug"档案)──
  #
  # 故障:dae(unstable-2026-07-31.caa6f5e)劫持发往 v6 link-local 网关
  # (fe80::1)的 53 查询后不产生应答 → 依赖它的客户端全部超时。
  #
  # 证据链(2026-08-22/23 实测,同机同时刻控制变量):
  #   1. n=5 定量:dae 运行中 fe80::1 0/5 全灭;223.5.5.5 与 192.168.5.1
  #      均 5/5 正常(劫持+作答正常)——唯一变量是目的地址 v6 link-local
  #   2. A/B 基线:dae 停机后 fe80::1 立即 5/5 恢复作答 → 路由器无辜,
  #      是 dae 的劫持路径吞包;dae restart 不恢复,非瞬态
  #   3. 源码(control/kern/tproxy.c L1448):劫持判定只看 dport==53,
  #      对目的地址零豁免,link-local 查询同样被送进 dae netns(dae0/
  #      dae0peer 架构),v6 link-local 回程在该 netns 内无法回到本机
  #   4. 时间线:resolved 日志 15:18 起 fe80::1 间歇降级(NM 同时下发
  #      192.168.5.1 可切换,故白天未察觉);某时刻 resolved 当前服务器
  #      漂移到 fe80::1 单点后总爆发 → 与 dae 二进制/本仓改动无关
  #      (当时任何改动均未上机,八代系统同 dae 版本)
  #
  # 旁路(两层,都是正解而非掩盖):
  #   resolved 上游显式公网 v4 —— dae 本就劫持一切出站 53 并按 dns.routing
  #     应答(实测写 223.5.5.5 答的是 alidns),系统解析器指向网关
  #     link-local 本身就是反模式(单点+踩此 bug);
  #   NM ignore-auto-dns —— 压掉 RA/DHCP 把 fe80::1 写进 per-link,
  #     否则 resolved 仍会选中它。
  #
  # ⚠ 残余风险:直查 fe80::1 的客户端(不经系统解析器)仍会挂。上游修复
  # 或换版本后可移除 ignore-auto-dns 层(恢复 RA DNS),但 nameservers
  # 显式化建议保留(消除网关 DNS 单点)。上游 issue 暂缓提交。
  networking.nameservers = [
    "223.5.5.5"
    "119.29.29.29"
  ];

  # 压掉 NM 把 RA/DHCP 的 DNS 写进 per-link(否则 resolved 仍会尝试
  # fe80::1):[connection] 段是所有连接的默认值,运行时生成的有线连接
  # 同样生效;只忽略 DNS 下发,地址获取不受影响(类型化选项,勿手写
  # conf.d 旁路文件)
  networking.networkmanager.connectionConfig = {
    "ipv4.ignore-auto-dns" = true;
    "ipv6.ignore-auto-dns" = true;
  };

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
        # 使用官方默认的 Cloudflare TCP / Google DNS UDP 端到端探测；30 秒可在
        # UDP 被封或链路故障后及时切到 AnyTLS，两个自建节点的探测开销可以忽略
        check_interval: 30s
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
            # MiniMax 国内域名未被 geosite:cn 收录,曾 fallback googledns(走 Linode
            # 出口)拿到面向海外的 CDN 边缘(filecdn.minimax.chat → 128.1.157.x);
            # 指到 alidns 才能解析到国内节点(123.6.x/180.130.x),配合下方直连规则
            # 语法陷阱:key 前缀只作用于紧跟的一个值 —— suffix: a, b, c 里 b/c 是
            # 裸参数。主路由 domain() 裸参数有 AliasOptimizer 兜底改写 suffix,
            # DNS 段 qname() 优化链没有 → 裸参数直达 addQName 即 FATAL(dae
            # validate 只解析语法查不出,run 才炸)。每值显式写 key
            qname(suffix: minimax.chat, suffix: minimaxi.chat, suffix: minimaxi.com, suffix: minimax.com) -> alidns
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

      node {
        linode_tuic: '${config.sops.placeholder.dae_tuic_url}'
        linode_anytls: '${config.sops.placeholder.dae_anytls_url}'
      }

      group {
        proxy {
          filter: name(linode_tuic)
          # 同一静态出口下 TUIC 主用、AnyTLS 备用；偏置只影响选择，不影响健康检查
          filter: name(linode_anytls) [add_latency: 1s]
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
        # MiniMax 国内站(minimax.chat/minimaxi.com)未被 geosite:cn 收录,
        # filecdn.minimax.chat 曾 fallback:proxy 绕 Linode 访问国内 CDN;
        # minimax.com 非 MiniMax 官方域名(解析到 AWS 邮件中继,443 无站),一并直连
        # key 每值显式:domain() 裸参数虽有 alias 兜底(功能上不出错),但与
        # DNS 段 qname 统一写法,免再踩同坑
        domain(suffix: minimax.chat, suffix: minimaxi.chat, suffix: minimaxi.com, suffix: minimax.com) -> direct
        domain(geosite:category-bank-cn, geosite:category-finance) -> direct

        # linux.do 需在 geosite:cn 直连规则之前，避免被收录后命中直连
        domain(suffix: linux.do) -> proxy

        # dae 自身 DoH 上游（8.8.8.8/8.8.4.4）走代理，见 dns.upstream 注释
        dip(8.8.8.8, 8.8.4.4) -> proxy

        # AI 规则必须排在 geosite:cn / geoip:cn 直连之前：DNS 污染会把 openai 域名
        # 解析到垃圾 IP，若某个垃圾 IP 恰好落国内段，会被 dip(geoip:cn) 抢先直连假 IP
        domain(geosite:anthropic, suffix: claude.ai) -> proxy
        domain(geosite:openai) -> proxy

        domain(geosite:cn) -> direct
        dip(geoip:cn) -> direct

        domain(geosite:netflix) -> proxy
        domain(geosite:spotify) -> proxy
        domain(geosite:twitch) -> proxy

        domain(geosite:youtube) -> proxy
        domain(geosite:reddit) -> proxy
        domain(geosite:twitter) -> proxy
        domain(geosite:facebook) -> proxy
        domain(geosite:instagram) -> proxy
        domain(geosite:telegram) -> proxy
        domain(suffix: discord.com, discord.gg) -> proxy
        domain(suffix: t.me, telegram.org) -> proxy

        domain(geosite:google) -> proxy
        domain(suffix: esjzone.one, esjzone.cc) -> proxy

        fallback: proxy
      }
    '';
  };

  # ── dae 代理 ──────────────────────────────────────────────
  services.dae = {
    enable = true;
    configFile = config.sops.templates."dae/config.dae".path;
    package = inputs.dae.packages.${pkgs.stdenv.hostPlatform.system}.dae-unstable;
  };
}
