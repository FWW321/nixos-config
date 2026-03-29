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
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri.url = "github:sodiboo/niri-flake";
    noctalia.url = "github:noctalia-dev/noctalia-shell";
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

    # 网络和性能
    dae = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming-edge = {
      url = "github:powerofthe69/nix-gaming-edge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comfyui-nix.url = "github:utensils/comfyui-nix";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    {
      nixosConfigurations.FWW-Desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # 外部模块
          inputs.disko.nixosModules.disko
          inputs.dae.nixosModules.dae
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          inputs.comfyui-nix.nixosModules.default

          # 硬件模块
          inputs.nixos-hardware.nixosModules.common-cpu-intel
          inputs.nixos-hardware.nixosModules.common-pc-ssd
          inputs.nixos-hardware.nixosModules.common-pc

          # 主机配置
          ./hosts/FWW-Desktop
          ./hosts/FWW-Desktop/hardware.nix
          ./hosts/FWW-Desktop/disko.nix
          ./hosts/FWW-Desktop/nvidia.nix
          ./hosts/FWW-Desktop/comfyui.nix

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
              sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
              users.fww = import ./users/fww/default.nix;
            };
          }
        ];
      };
    };
}
