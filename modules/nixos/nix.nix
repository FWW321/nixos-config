# filepath: ~/nixos-config/modules/nixos/nix.nix
# Nix 设置、registry、substituters、垃圾回收
{ inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  nix = {
    # nixpkgs registry 钉到本 flake 输入:nix run nixpkgs#foo 与系统同源,
    # 不再解析到全局 registry 的漂浮 nixpkgs
    registry.nixpkgs.flake = inputs.nixpkgs;

    # flake 已全权管理来源,channel 命令与状态文件不再需要
    channel.enable = false;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
      max-jobs = "auto";
      connect-timeout = 5;
      warn-dirty = false;
      keep-derivations = true;
      keep-outputs = true;
      substituters = [
        "https://attic.xuyh0120.win/lantian"
        "https://niri.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
      ];
      trusted-public-keys = [
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    # 降低 nix-daemon 优先级，避免影响前台任务
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d --max-freed ${toString (100 * 1024 * 1024 * 1024)}";
    };
  };

  # nh:nixos-rebuild 的现代前端。NH_FLAKE 免每次带路径(nh os switch 直接可用)
  # 清理仍由上方 nix.gc weekly 管,nh clean 不双开
  programs.nh = {
    enable = true;
    flake = "/home/fww/nixos-config";
  };
}
