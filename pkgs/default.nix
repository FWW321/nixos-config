# filepath: ~/nixos-config/pkgs/default.nix
# 自建包 overlay。目录 = nixpkgs pkgs/by-name 同构(<2字母分片>/<包名>/package.nix),
# 将来上游化 PR 几乎零改动;包目录内允许附带辅助文件(launcher.nix/source.json/update.sh)。
# 挂载:overlays/default.nix 组装 → flake.nix nixpkgs.overlays = [ self.overlays.default ]。
#
# 函数签名即依赖声明(nixpkgs by-name 约定):需要特殊参数的包(open-design 两个、
# chatgpt)在下方 callPackage 显式传,其余自动注入。
#
# 新增包:建 by-name/<sh>/<name>/package.nix + 下方一行 callPackage。
{ inputs }:
final: _prev: {
  # CUDA Blender + blender-mcp 组装件(门控部署见 users/fww/desktop/blender.nix)
  blender-cuda = final.callPackage ./by-name/bl/blender-cuda/package.nix { };

  # unified ChatGPT/Codex 桌面端(Linux):抄自 PR #551713 待合并,见包内头注释
  # codexPackage 与 home-manager programs.codex 复用 nixpkgs codex 同一二进制
  chatgpt = final.callPackage ./by-name/ch/chatgpt/package.nix { codexPackage = final.codex; };

  mdbook-svgbob = final.callPackage ./by-name/md/mdbook-svgbob/package.nix { };

  # MiniMax Token Plan 官方 CLI(npm 成品 bundle + undici,见包内头注释)
  mmx-cli = final.callPackage ./by-name/mm/mmx-cli/package.nix { };

  # @open-design/dsh-runtime:src 与 services.open-design 同一 inputs.open-design pin
  # (OD daemon↔runtime 协议代际原子耦合,详见包内头注释)
  open-design-dsh-runtime = final.callPackage ./by-name/op/open-design-dsh-runtime/package.nix {
    odDshRuntimeSrc = inputs.open-design;
  };

  # daemon × better-sqlite3 13 graft(nodejs#63642 崩溃根治,取代已废弃的
  # nodejs 24.18.1 重绑;见包内头注释)
  open-design-daemon-bsq13 = final.callPackage ./by-name/op/open-design-daemon-bsq13/package.nix {
    daemonPkg = inputs.open-design.packages.${final.system}.daemon;
  };

  opencode2 = final.callPackage ./by-name/op/opencode2/package.nix { };

  pdf-inspector = final.callPackage ./by-name/pd/pdf-inspector/package.nix { };

  # 已迁独立仓库:dsh/dshPlugins → nixdsh(overlay 见 overlays/default.nix);
  # koharu → koharu-nix、zcode → zcode-nix(包经各自 HM 模块自带)
}
