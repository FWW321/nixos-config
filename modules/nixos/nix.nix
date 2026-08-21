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
  };

  # nh:nixos-rebuild 前端 + 周期清理(与 nix.gc 二选一:nixpkgs 模块对双开
  # 显式 warning "use one or the other to avoid conflict",两套都删 generations+GC)
  #
  # 清理 = root 定时器跑 `nh clean all`,能力为 nix-collect-garbage 超集:
  #   - generations:--keep 5 计数下限 + --keep-since 14d 时间窗(≈原
  #     --delete-older-than 14d,额外多滚回深度下限)
  #   - 扫描面含 uid 1000-1100 用户的 ~/.local/state/nix/profiles(HM generations)
  #   - gcroots:孤儿/死链删除 + result/direnv root 按 keep-since 老化
  #     (nix-collect-garbage 永不碰 gcroots;裸 nix build 在 gcroots/auto
  #     钉住的路径旧配置下永远回收不了,换机前实测已积累 97 个)
  #   - 收尾 nix store gc --max 100G(≈原 --max-freed)
  # 注:nh 默认 --keep 1 会把滚回点砍到剩一代,参数必须显式钉;
  #     keep 与 configurationLimit 取小者 = 实际可滚回深度(FWW-Desktop
  #     ESP 1G 两处同为 5;新主机 ESP 4G 可放宽);--optimise 不加
  #     (auto-optimise-store 写时优化已开)
  programs.nh = {
    enable = true;
    flake = "/home/fww/nixos-config";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 14d --max 100G";
    };
  };
}
