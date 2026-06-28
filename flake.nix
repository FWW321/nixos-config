# filepath: ~/nixos-config/flake.nix
{
  description = "2026 现代化 NixOS 高性能工作站架构";

  inputs = {
    # 核心
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 磁盘和密钥
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 桌面环境
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 应用
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

    # AI 工具
    open-design = {
      url = "github:nexu-io/open-design";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # opencode skills 与插件（flake=false，仅取源码）
    shadcn-ui = {
      url = "github:shadcn-ui/ui";
      flake = false;
    };
    surreal-skills = {
      url = "github:24601/surreal-skills";
      flake = false;
    };
    git-workflow-skill = {
      url = "github:netresearch/git-workflow-skill";
      flake = false;
    };
    understand-anything = {
      url = "github:Egonex-AI/Understand-Anything";
      flake = false;
    };
    matt-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    agent-browser-skill = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    };
    humanizer-zh = {
      url = "github:op7418/Humanizer-zh";
      flake = false;
    };
    rtk = {
      url = "github:rtk-ai/rtk";
      flake = false;
    };

    # Neovim 插件
    multicursor-nvim = {
      url = "github:jake-stewart/multicursor.nvim";
      flake = false;
    };

    # 网络和性能
    # dae 代理：flake module 用可写 /etc/dae（避开 nixpkgs 只读 credentials bug），unstable 包跟进最新 main 提交
    dae = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      # 不要 follows nixpkgs！pinned overlay 需要用 kernel flake 自己的 nixpkgs
      # 才能命中 lantian attic 的二进制缓存
    };
    # Proton-CachyOS：作者专门维护的仓库，哈希更新更及时
    proton-cachyos-nix = {
      url = "github:powerofthe69/proton-cachyos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rust
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    {
      nixosConfigurations.FWW-Desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
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
          ./modules/system/secrets.nix
          ./modules/system/theme.nix

          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs; };
              sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
                inputs.open-design.homeManagerModules.default
              ];
              users.fww = import ./users/fww/default.nix;
            };
          }
        ];
      };
    };
}
