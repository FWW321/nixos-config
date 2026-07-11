# filepath: ~/nixos-config/modules/system/network.nix
# 网络配置：NetworkManager、蓝牙、dae 代理
{ config, pkgs, lib, inputs, ... }:

{
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd"; # iwd 比 wpa_supplicant 更现代、更快
  };

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
              check_interval: 30s
              check_tolerance: 50ms
              # 抗审查：uTLS 伪装 Chrome 指纹 + TLS 分片规避 SNI/指纹检测（仅对 TCP 生效，配合下方 block QUIC）
              tls_implementation: utls
              utls_imitate: chrome_auto
              tls_fragment: true
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

              # 阻止 QUIC/HTTP3，强制回退 TCP（TLS 分片仅对 TCP 生效；官方 example 推荐）
              l4proto(udp) && dport(443) -> block

              domain(geosite:category-ads-all) -> block
      
              dscp(0x4) -> direct
      
              pname(steam, Counter-Strike) -> direct
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
