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
final: _prev:
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

  # h3-models 已移除(2026-08-25):模型下载与部署整体迁 AutoDL 实例(见 users/fww/cloud.nix)

  mdbook-svgbob = final.callPackage ./by-name/md/mdbook-svgbob/package.nix { };

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
