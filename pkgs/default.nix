# filepath: ~/nixos-config/pkgs/default.nix
# 自建包 overlay。目录 = nixpkgs pkgs/by-name 同构(<2字母分片>/<包名>/package.nix),
# 将来上游化 PR 几乎零改动;包目录内允许附带辅助文件(launcher.nix/source.json/update.sh)。
# 挂载:overlays/default.nix 组装 → flake.nix nixpkgs.overlays = [ self.overlays.default ]。
#
# 函数签名即依赖声明(nixpkgs by-name 约定):需要特殊参数的包(chatgpt)
# 在下方 callPackage 显式传,其余自动注入。
#
# 新增包:建 by-name/<sh>/<name>/package.nix + 下方一行 callPackage。
{ inputs }:
final: prev:
let
  # OpenDesign 专用 pnpm 钉版(packageManager 锁步,见 pnpm.nix 头注释)
  odPnpm = final.callPackage ./by-name/op/open-design/pnpm.nix { };
in
{
  # CUDA Blender + blender-mcp 组装件(门控部署见 users/fww/desktop/blender.nix)
  blender-cuda = final.callPackage ./by-name/bl/blender-cuda/package.nix { };

  # Blender Lab 官方 MCP server + addon 半边(blender-cuda 组装件收录 addon,
  # server 入口按名进 MCP 条目;Gitea Cloudflare 绕行等见包内注释)
  blender-lab-mcp = final.callPackage ./by-name/bl/blender-lab-mcp/package.nix { };

  # unified ChatGPT/Codex 桌面端(Linux):抄自 PR #551713 待合并,见包内头注释
  # codexPackage 与 home-manager programs.codex 复用 nixpkgs codex 同一二进制
  chatgpt = final.callPackage ./by-name/ch/chatgpt/package.nix { codexPackage = final.codex; };

  # ⏳ 临时 override(2026-09-06):codex 上顶 0.153.4 —— Astra(gpt-6-astra)最低
  # 要求 CLI ≥0.153.0,模型目录按 client_version 下发,0.151 实测目录无 astra;
  # nixos-unstable channel 未含 nixpkgs PR #559991(仅 master,channel 滞后 1-2 天)。
  # hash 直取自该 PR(其 diff 仅 version/src/cargoHash 三行)。
  # ⚠ 不能只 overrideAttrs cargoHash:buildRustPackage 的 cargoDeps 里 hash 取
  # args.cargoHash(原始入参,不随 overrideAttrs 传播;src/version 走 finalAttrs
  # 会跟随)→ 必须显式重建 cargoDeps(fetchCargoVendor 镜像内部 getOptionalAttrs
  # 取的 pname/version/src/sourceRoot;FOD hash 只依赖内容,patches 为空可省)。
  # 删除条件:nix flake update 后 nix eval ...codex.version ≥ 0.153.4 即整段删除,
  # chatgpt(codexPackage=final.codex)与 programs.codex 会自动回落 nixpkgs 版。
  codex = prev.codex.overrideAttrs (
    finalAttrs: _prevAttrs: {
      version = "0.153.4";
      src = final.fetchFromGitHub {
        owner = "openai";
        repo = "codex";
        tag = "rust-v0.153.4";
        hash = "sha256-lHiDj5SodaM3mh8goMm6esfejeAT+Y3JJWrRnyj6sJo=";
      };
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs)
          pname
          version
          src
          sourceRoot
          ;
        hash = "sha256-GG6kOXmCdq+bZLU2ul0DIVL8lDuweayvZvXn6+bcUZw=";
      };
    }
  );

  # h3-models 已移除(2026-08-25):模型下载与部署整体迁 AutoDL 实例(见 users/fww/cloud.nix)

  # EPUB 后端。覆盖 nixpkgs 的 0.4.37(mdbook 0.4 协议,与 0.5 不兼容)为 0.5.4,
  # 选型与遮蔽理由见包内头注释
  mdbook-epub = final.callPackage ./by-name/md/mdbook-epub/package.nix { };

  mdbook-svgbob = final.callPackage ./by-name/md/mdbook-svgbob/package.nix { };

  # mdbook-typst-pdf 已移除(2026-09-03):真实书上与 pandoc+typst 同死于标题
  # 上下标字符(f₂/n²,typst label 语法拒收),PDF 路线定稿 mdbook-pdf(chromium)。
  # 复活路径:git log 找本注释前一版,或 crates.io mdbook-typst-pdf

  # MiniMax Token Plan 官方 CLI(npm 成品 bundle + undici,见包内头注释)
  mmx-cli = final.callPackage ./by-name/mm/mmx-cli/package.nix { };

  # open-design:上游 #7644 退役官方 Nix 分发后本仓自持 —— nix/ 树 vendor 进
  # by-name/op/open-design/(daemon+web+hash 自愈脚本),源钉 sources 登记表;
  # 私有补丁 opencode2-support.patch 适配 opencode v2(上游 PR #7226 停滞且
  # 不完整,此处补全;不上游)。web = Next.js 静态导出(caddy 前置)。
  # ⚠ 裸 daemon 在 node 24 运行时会崩(better-sqlite3 12.10),部署走 bsq13
  open-design = final.callPackage ./by-name/op/open-design/package.nix {
    odSrc = inputs.open-design;
    pnpm = odPnpm;
    nodejs = final.nodejs_24;
  };
  open-design-web = final.callPackage ./by-name/op/open-design/web.nix {
    odSrc = inputs.open-design;
    pnpm = odPnpm;
    nodejs = final.nodejs_24;
  };

  # daemon × better-sqlite3 13 graft(nodejs#63642 崩溃根治;拆除条件与
  # 清单见包内头注释)
  open-design-daemon-bsq13 = final.callPackage ./by-name/op/open-design-daemon-bsq13/package.nix {
    daemonPkg = final.open-design;
  };

  # @open-design/dsh-runtime:src 与 services.open-design 同一 sources 登记表 pin
  # (OD daemon↔runtime 协议代际原子耦合,详见包内头注释)
  open-design-dsh-runtime = final.callPackage ./by-name/op/open-design-dsh-runtime/package.nix {
    odDshRuntimeSrc = inputs.open-design;
  };

  opencode2 = final.callPackage ./by-name/op/opencode2/package.nix { };

  pdf-inspector = final.callPackage ./by-name/pd/pdf-inspector/package.nix { };

  # videoforge 系包定义已摘除(2026-09-01 单仓化迁往 ~/code/FWW321/videoforge
  # pkgs/;仓内 devenv shell 为唯一权威执行环境)

  # 已迁独立仓库:dsh/dshPlugins → nixdsh(overlay 见 overlays/default.nix);
  # koharu → koharu-nix、zcode → zcode-nix(包经各自 HM 模块自带)
}
