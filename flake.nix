# filepath: ~/nixos-config/flake.nix
{
  description = "2026 现代化 NixOS 高性能工作站架构";

  inputs = {
    # ── 核心 ──
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rust 工具链（rust-overlay nightly 纯 nix 声明式，替代 rustup）
    # 注入为 nixpkgs overlay → pkgs.rust-bin 可用（见下方 nixpkgs.overlays）
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 系统基础设施 ──
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # dae 代理:flake module 用可写 /etc/dae(避开 nixpkgs 只读 credentials bug)
    dae = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 不要 follows nixpkgs!需用 kernel flake 自己的 nixpkgs 才能命中 lantian attic 缓存
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    # Proton-CachyOS:作者专门维护的仓库,哈希更新更及时
    proton-cachyos-nix = {
      url = "github:powerofthe69/proton-cachyos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 桌面环境 ──
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 应用 ──
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ── AI agent 工具 ──
    # dsh 打包 + nixvim 式声明配置(独立仓库)
    nixdsh = {
      url = "github:FWW321/nixdsh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ZCode(智谱 GLM ADE)打包 + programs.zcode HM 模块(独立仓库)
    zcode-nix = {
      url = "github:FWW321/zcode-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Koharu(ML 漫画翻译)打包 + programs.koharu HM 模块(独立仓库)
    koharu-nix = {
      url = "github:FWW321/koharu-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    open-design = {
      url = "github:nexu-io/open-design";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 源码引用登记表:全部 flake=false 源码树移入 sources/flake.nix,
    # 主锁仍完整钉每个源的 rev;更新 nix flake update sources/<name>
    # (主文件内 mapAttrs 去重被求值器拒绝 —— 只吃字面 attrset,
    # 结构外移是唯一消音路径,2026-08-21 lab 实测)──
    sources = { url = "path:./sources"; };
  };

  outputs =
    { self, nixpkgs, home-manager, ... }@inputs:
    let
      # 登记表摊平:sources/flake.nix 里的源码树以原名进入 inputs 命名空间,
      # 消费者零改动(冲突面 = 主输入名,登记表内不与之同名即可)
      inputs' = inputs // inputs.sources.pins;
      # checks 专用轻量 pkgs:不叠 overlay,只需 runCommand
      checkPkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      # 全部 overlay 的唯一出口:rust 工具链/cachyos 内核与 Proton/nixdsh/
      # 本仓 by-name 自建包(组装见 overlays/default.nix)
      overlays.default = import ./overlays { inherit inputs; };

      # dsh 的 checks/updater 已随 pkgs/dsh 迁至独立仓库 nixdsh
      # (nix flake check github:FWW321/nixdsh / nix run …#dsh-plugins-update)

      # 中立 provider 层 schema 守护(动机/断言见 providers-schema-check.nix;
      # 与 nixdsh 的 checks 同一验证入口)
      checks.x86_64-linux.providers-schema =
        import ./users/fww/ai/common/providers-schema-check.nix checkPkgs nixpkgs.lib;

      nixosConfigurations.FWW-Desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inputs = inputs'; };
        modules = [
          # overlay 注册(唯一出口)
          { nixpkgs.overlays = [ self.overlays.default ]; }

          # 外部模块
          inputs.dae.nixosModules.dae
          inputs.disko.nixosModules.disko
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          inputs.noctalia-greeter.nixosModules.default

          # 硬件模块
          inputs.nixos-hardware.nixosModules.common-cpu-intel
          inputs.nixos-hardware.nixosModules.common-pc-ssd
          inputs.nixos-hardware.nixosModules.common-pc

          # 主机配置
          ./hosts/FWW-Desktop
          ./hosts/FWW-Desktop/hardware.nix
          ./hosts/FWW-Desktop/disko.nix
          ./hosts/FWW-Desktop/nvidia.nix

          # 通用系统模块
          ./modules/system/boot.nix
          ./modules/system/nix.nix
          ./modules/system/users.nix
          ./modules/system/audio.nix
          ./modules/system/desktop.nix
          ./modules/system/gaming.nix
          ./modules/system/services.nix
          ./modules/system/network.nix
          ./modules/system/containers.nix
          ./modules/system/torrents.nix
          ./modules/system/secrets.nix
          ./modules/system/theme.nix
          ./modules/system/ssh.nix

          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inputs = inputs'; };
              sharedModules = [
                inputs.open-design.homeManagerModules.default
                inputs.nixdsh.homeManagerModules.dsh
              ];
              users.fww = import ./users/fww/default.nix;
            };
          }
        ];
      };
    };
}
