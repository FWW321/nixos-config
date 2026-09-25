# filepath: ~/nixos-config/modules/nixos/network.nix
# 网络配置：NetworkManager、蓝牙、dae 代理
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # ── dae kill switch(fail-closed,v4:单元内配对,单一写入者)────────────
  # 设计排除记录(两次断网 + 一次险些上线的教训,勿重蹈):
  # v1/inet output 常驻 drop(09-25 夜):本地应用包路径是 路由→OUTPUT→
  #   WAN TC egress,dae 拦截点在 TC egress(源码 dae_lan_wan_egress_l2/l3)
  #   —— OUTPUT 在拦截点上游,无法区分"dae 在位(包即将被拦)"与"不在位
  #   (泄漏)",drop 一刀切 = dae 在位也全断(dae up 4.5 分钟连接数 0)。
  # v3/netdev egress(09-26 评审时否决,未上线):内核 netfilter_netdev.h 明示
  #   egress 方向 "netfilter runs first, then tc" —— netdev egress 钩子同样
  #   在 TC 上游,与 v1 同因不可行。结论:拦截点上游的一切常驻过滤皆死,
  #   下游只有 TC 内部(dae 自管 clsact qdisc,重建时会清掉别人的 filter)。
  # v2/systemd 武装-拆装(09-26 02:44 二次事故):机制正确,败在存在第二
  #   写入者 —— 开机武装单元在 activation 里晚于 sops restartUnits 触发的
  #   dae 重启才启动(新单元引入时必现),before= 跨事务无效 → 已 active 的
  #   dae 面前重复武装且无人拆除。教训:任何第二写入者(boot 单元、
  #   nftables.service 默认装载)都会在某个 activation 顺序下踩到同款竞态。
  # v4(当前):表只由 dae 自身单元的生命周期创建/销毁,单一写入者:
  #   ExecStopPost(崩溃/失败启动/干净停止/重启间隙,一切退出路径)→ 装表;
  #   ExecStartPost(仅成功启动)→ 拆表。装/拆在同一单元内严格配对,
  #   结构上无跨事务可能 → 不需要任何守卫。代价:开机到 dae 启动完成的
  #   窗口无表保护(数秒,fail-open;运行期崩溃/停机窗口全覆盖,fail-closed)。
  # ⚠ 手动 systemctl stop dae 调试期间外网全断(LAN/路由器管理页不受影响),
  #   属预期;紧急解锁:sudo nft delete table inet dae-killswitch
  # 验证:dae 运行时 curl 海外通;stop dae 后 curl 超时、
  #   sudo nft list table inet dae-killswitch 的 drop 规则计数在涨
  daeKillswitchRules = pkgs.writeText "dae-killswitch.nft" ''
    table inet dae-killswitch {
      chain output {
        type filter hook output priority filter; policy accept;

        # 环回 + dae 内部通道(app→dae0 对端),不参与泄漏判定
        oifname { "lo", "dae0" } accept
        # NDP/RA/PMTU:v4/v6 协议栈运转必需,不携带应用数据
        meta l4proto { icmp, icmpv6 } accept
        # DHCP 租约维持(v4 67/68,v6 546/547)
        udp dport { 67, 68, 546, 547 } accept
        # LAN/ULA/链路本地/组播:dae 不在位也保留(路由器管理页、mDNS/Avahi)
        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255 } accept
        ip6 daddr { fc00::/7, fe80::/10, ff00::/8 } accept
        # 其余出站 TCP/UDP = dae 不在位时的直连泄漏,fail-closed
        meta l4proto { tcp, udp } drop
      }
    }
  '';

  # 装表:先删旧表再加载,幂等 —— 失败启动后的 ExecStopPost 会与上一次
  # 装表周期交叠(崩溃→武装→1s 重启循环);加载失败则整体失败(必须可见)
  daeKillswitchArm = pkgs.writeShellScript "dae-killswitch-arm" ''
    ${pkgs.nftables}/bin/nft delete table inet dae-killswitch 2>/dev/null || true
    exec ${pkgs.nftables}/bin/nft -f ${daeKillswitchRules}
  '';

  # 拆表:表不在 = 本就没武装,静默即可
  daeKillswitchDisarm = pkgs.writeShellScript "dae-killswitch-disarm" ''
    ${pkgs.nftables}/bin/nft delete table inet dae-killswitch 2>/dev/null || true
  '';
in
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
  #           ${lib.getExe' pkgs.procs "sysctl"} -w net.ipv6.conf."$1".accept_ra=2
  #           ${lib.getExe' pkgs.procs "sysctl"} -w net.ipv6.conf."$1".addr_gen_mode=0
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
        # dae 给自身出站 socket(direct+proxy 一切重发出流量)打 SO_MARK 防
        # eBPF 自劫持回环;不设或设 0 时内部默认同为 0x100(dae 源码
        # common/utils.go 的 EffectiveSoMarkFromDae)。显式钉成 256(=0x100)
        # 与 0 行为完全等价、同样无 WARN。注意(v1 kill switch 事故勘误):
        # 该标记是 eBPF 层防回环用的,不经 host 的 nft OUTPUT 链,nftables
        # 规则不要指望匹配它
        so_mark_from_dae: 256
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
            # Steam 域名踩中与 MiniMax 同款的问题:fallback googledns(走 Linode 出口)
            # 让 Akamai GSLB 返回面向海外边缘的节点(store.steampowered.com →
            # 23.63.226.116),而这些域名流量走直连,国内直连那些边缘 TCP 443 被丢包
            # (2026-09-07 实测:ICMP 通 ~220ms 但 TCP SYN 反复重发无应答,商店页面
            # 卡死)。直连域名必须配国内解析,保持 DNS 出口与流量出口一致。
            # steampowered/steamstatic 已改走代理不受影响,此规则主要救
            # steamcontent.com 下载 CDN 和 steamserver.net(CM)
            qname(geosite:steam) -> alidns
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
        # Steam 商店/API/静态资源/社区走代理:这些域名被 fallback googledns(走
        # Linode 出口)解析到面向海外出口的 Akamai 边缘,国内直连 443 黑洞(详见
        # dns 段 qname(geosite:steam) 注释),必须跟随 DNS 出口一起走代理才通;
        # 网页流量小,不占下载带宽。steamstatic.com 是商店 UI 的 js/css/图片资源
        domain(suffix: steamcommunity.com, suffix: steampowered.com, suffix: steamstatic.com) -> proxy
        # 其余 steam 域名直连:steamcontent.com 下载 CDN、steamserver.net(CM)。
        # dns 段已让 geosite:steam 走 alidns,直连拿到国内可达的下载节点,
        # 游戏下载不占代理带宽
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

  # kill switch 单元接线(v4):装/拆只存在于 dae 自身生命周期 —— 见文件头
  # 注释。drop-in 形式必需:新 dae 模块(2026-09-25 起)的 unit 是包内静态
  # 文件(lib/systemd/system/dae.service 软链),serviceConfig 直改会被旁路
  # (v1 时代 RestartSec=1s 从未生效,实发包内默认 5s)
  systemd.services.dae = {
    overrideStrategy = "asDropinIfExists";
    serviceConfig = {
      RestartSec = lib.mkForce "1s";
      ExecStopPost = [ "+${daeKillswitchArm}" ];
      ExecStartPost = [ "+${daeKillswitchDisarm}" ];
    };
  };

  # firewall 切 nft 后端(services.nix 开放端口规则自动翻译,行为等价);
  # kill switch 表不在此处 —— 沙箱构建期 nft -c 无法验证设备相关规则,
  # 且它本就是运行期生命周期表,由上方 dae 单元 hooks 装载/拆除
  networking.nftables.enable = true;
}
