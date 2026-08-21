# filepath: ~/nixos-config/modules/nixos/containers.nix
# rootless Podman — 无 daemon、systemd 原生、rootless 默认
{ config, lib, pkgs, ... }:

{
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # rootless 必需：subuid/subgid 映射
  users.users.fww = {
    subUidRanges = [{ startUid = 100000; count = 65536; }];
    subGidRanges = [{ startGid = 100000; count = 65536; }];
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    dive
    podman-tui
  ];

  # 让 docker-compose 自动用 rootless podman socket
  environment.extraInit = ''
    if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
      export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    fi
  '';
}
