# filepath: ~/nixos-config/modules/system/network.nix
{ config, pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
  };
  services.resolved = {
    enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.blueman.enable = true;

  sops.secrets.byg_url = { };

  sops.templates."dae/config.dae" = {
    path = "/etc/dae/config.dae";
    mode = "0400";
    owner = "root";
    content = ''
      
            global {
              wan_interface: auto
              lan_interface: podman0, virbr0
              dial_mode: domain
              log_level: info
              allow_insecure: false
              auto_config_kernel_parameter: true
              tcp_check_url: 'http://cp.cloudflare.com'
              tcp_check_http_method: HEAD
              udp_check_dns: 'dns.google:53'
              check_interval: 30s
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
              byg: 'https-file://${config.sops.placeholder.byg_url}'
            }
      
            group {
              proxy {
                filter: subtag(byg)
                policy: min_moving_avg
              }
              hk {
                filter: subtag(byg) && name(keyword: '香港', keyword: 'HK')
                policy: min_moving_avg
              }
              tw {
                filter: subtag(byg) && name(keyword: '台湾', keyword: 'TW')
                policy: min_moving_avg
              }
              sg {
                filter: subtag(byg) && name(keyword: '新加坡', keyword: 'SG')
                policy: min_moving_avg
              }
              jp {
                filter: subtag(byg) && name(keyword: '日本', keyword: 'JP') && !name(keyword: '06')
                policy: min_moving_avg
              }
              kr {
                filter: subtag(byg) && name(keyword: '韩国', keyword: 'KR')
                policy: min_moving_avg
              }
              vn {
                filter: subtag(byg) && name(keyword: '越南', keyword: 'VN')
                policy: min_moving_avg
              }
              my {
                filter: subtag(byg) && name(keyword: '马来西亚', keyword: 'MY')
                policy: min_moving_avg
              }
              th {
                filter: subtag(byg) && name(keyword: '泰国', keyword: 'TH')
                policy: min_moving_avg
              }
              in {
                filter: subtag(byg) && name(keyword: '印度', keyword: 'IN')
                policy: min_moving_avg
              }
              au {
                filter: subtag(byg) && name(keyword: '澳大利亚', keyword: 'AU')
                policy: min_moving_avg
              }
              ca {
                filter: subtag(byg) && name(keyword: '加拿大', keyword: 'CA')
                policy: min_moving_avg
              }
              us {
                filter: subtag(byg) && name(keyword: '美国', keyword: 'US')
                policy: min_moving_avg
              }
              de {
                filter: subtag(byg) && name(keyword: '德国', keyword: 'DE')
                policy: min_moving_avg
              }
              fr {
                filter: subtag(byg) && name(keyword: '法国', keyword: 'FR')
                policy: min_moving_avg
              }
              uk {
                filter: subtag(byg) && name(keyword: '英国', keyword: 'UK')
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
              domain(geosite:category-games@cn) -> direct
              domain(suffix: steamserver.net, steamcontent.com, cm.steampowered.com) -> direct
      
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

  services.dae = {
    enable = true;
    configFile = config.sops.templates."dae/config.dae".path;
  };

  systemd.services.dae.restartTriggers = [ config.sops.templates."dae/config.dae".path ];

  environment.systemPackages = [ pkgs.dae ];
}
