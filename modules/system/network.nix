# filepath: ~/nixos-config/modules/system/network.nix
{ config, pkgs, ... }:
{
  networking = { networkmanager = { enable = true; wifi.backend = "iwd"; }; };
  services.resolved = { enable = true; };

  hardware.bluetooth = { enable = true; powerOnBoot = true; settings.General.Experimental = true; };
  services.blueman.enable = true;

  sops.secrets.dae_subscription_url = {};
   
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
        byg: '${config.sops.placeholder.dae_subscription_url}'
      }

      group {
        proxy {
          filter: subtag(byg)
          policy: min_moving_avg
        }
        jp {
          filter: subtag(byg) && name(keyword: '日本', keyword: 'JP')
          policy: min_moving_avg
        }
        us {
          filter: subtag(byg) && name(keyword: '美国', keyword: 'US')
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

        domain(geosite:category-games@cn) -> direct
        domain(suffix: steamserver.net, steamcontent.com, cm.steampowered.com) -> direct

        domain(geosite:apple@cn) -> direct
        domain(geosite:tencent) -> direct
        domain(geosite:category-ai-cn) -> direct
        domain(geosite:category-bank-cn, geosite:category-finance) -> direct

        domain(geosite:cn) -> direct
        dip(geoip:cn) -> direct
        domain(geosite:google) -> jp
        fallback: proxy
      }
    '';
  };

  services.dae = {
    enable = true;
    config = "";
  };

  systemd.services.dae.serviceConfig.ExecStart = [
    ""
    "${pkgs.dae}/bin/dae run -c ${config.sops.templates."dae/config.dae".path}"
  ];

  environment.systemPackages = [ pkgs.dae ];

  systemd.services.dae = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
