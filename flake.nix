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
    # 终端复用器/agent 运行时(2026-08 上游迁官方 org herdrdev,旧 ogulcancelik/
    # 仅为重定向;crates.io 仍指旧名,以 GitHub 为准)
    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 源码引用登记表:全部 flake=false 源码树移入 sources/flake.nix,
    # 主锁仍完整钉每个源的 rev;更新 nix flake update sources/<name>
    # (主文件内 mapAttrs 去重被求值器拒绝 —— 只吃字面 attrset,
    # 结构外移是唯一消音路径,2026-08-21 lab 实测)──
    sources = {
      url = "path:./sources";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      # 登记表摊平:sources/flake.nix 里的源码树以原名进入 inputs 命名空间,
      # 消费者零改动(冲突面 = 主输入名,登记表内不与之同名即可)
      inputs' = inputs // inputs.sources.pins;

      # checks 专用轻量 pkgs:不叠 overlay,只需 runCommand
      checkPkgs = import nixpkgs { system = "x86_64-linux"; };

      # ── 主机注册表 = hosts/ 目录本身 ──
      # 每个子目录一台主机(_ 前缀目录除外,如 _template);新增主机 = 建目录
      # (install.sh 向导自动完成),本文件零改动 —— "目录即配置"原则
      hostNames = builtins.attrNames (
        lib.filterAttrs (n: t: t == "directory" && !lib.hasPrefix "_" n) (builtins.readDir ./hosts)
      );

      # 统一主机装配:所有主机共享同一模块框架,差异全部在各 host 目录内
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          # system 不显式传:nixpkgs.hostPlatform 由各主机 facter 报告推导
          specialArgs = {
            inputs = inputs';
          };
          modules = [
            # overlay 注册(唯一出口)
            { nixpkgs.overlays = [ self.overlays.default ]; }

            # 跨切外部模块
            inputs.dae.nixosModules.dae
            inputs.disko.nixosModules.disko
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            inputs.noctalia-greeter.nixosModules.default

            # 主机(自治:disko/facter/GPU/nixos-hardware 在 host 内 import)
            ./hosts/${name}

            # 共享系统模块(聚合入口)
            ./modules/nixos

            # Home Manager(当前全部主机共用 fww 用户;多用户机器时在
            # host 目录内追加 home-manager.users 即可)
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inputs = inputs';
                };
                sharedModules = [
                  inputs.open-design.homeManagerModules.default
                  inputs.nixdsh.homeManagerModules.dsh
                ];
                users.fww = import ./users/fww/default.nix;
              };
            }
          ];
        };
    in
    {
      # 全部 overlay 的唯一出口:rust 工具链/cachyos 内核与 Proton/nixdsh/
      # 本仓 by-name 自建包(组装见 overlays/default.nix)
      overlays.default = import ./overlays { inherit inputs; };

      # 自建包同时以 packages 暴露(nix build .#opencode2 / nix run 直取),
      # 与 overlay 双出口 —— nixpkgs flake 自身同款做法。
      # pkgs 叠全部 overlay(lazy,未引用的 kernel/rust 面不求值)
      packages.x86_64-linux =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ self.overlays.default ];
            # chatgpt(deb 解包)unfree;与 nix.nix 的 nixpkgs.config 同规则
            config.allowUnfree = true;
          };
        in
        {
          inherit (pkgs)
            chatgpt
            mdbook-svgbob
            mmx-cli
            opencode2
            open-design-daemon-bsq13
            open-design-dsh-runtime
            pdf-inspector
            ;
        };

      # 格式化三件套:nixfmt(RFC 166)+ deadnix(死代码)+ statix(惯用法)。
      # nixfmt-tree 的 treefmt 封装做整树 nixfmt;deadnix/statix 在其前跑 --edit/fix
      # (--no-lambda-pattern-names:模块函数参数是给消费方的接口,勿被"未使用"误删)
      formatter.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.writeShellApplication {
          name = "nix-config-fmt";
          runtimeInputs = with pkgs; [
            deadnix
            nixfmt
            statix
          ];
          text = ''
            if [ "$#" -eq 0 ]; then
              deadnix --no-lambda-pattern-names --edit .
              statix fix .
              # treefmt 会遍历整树跑 nixfmt;此处 nixfmt 直接对全树亦可
              find . -name '*.nix' -not -path './.git/*' -print0 | xargs -0 nixfmt
              exit 0
            fi
            deadnix --no-lambda-pattern-names --edit "$@"
            for target in "$@"; do
              statix fix "$target"
            done
            exec nixfmt "$@"
          '';
        };

      # dsh 的 checks/updater 已随 pkgs/dsh 迁至独立仓库 nixdsh
      # (nix flake check github:FWW321/nixdsh / nix run …#dsh-plugins-update)

      # 中立 provider 层 schema 守护(动机/断言见 providers-schema-check.nix;
      # 与 nixdsh 的 checks 同一验证入口)
      checks.x86_64-linux.providers-schema =
        import ./users/fww/ai/common/providers-schema-check.nix checkPkgs
          nixpkgs.lib;

      # 主机自动发现(hosts/<dir> 即 nixosConfigurations.<dir>,见上方 hostNames)
      nixosConfigurations = lib.genAttrs hostNames mkHost;
    };
}
