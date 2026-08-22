# filepath: ~/nixos-config/pkgs/by-name/bl/blender-cuda/package.nix
# blender-cuda:CUDA Blender + blender-mcp(addon 与 MCP server)一体化组装件
#
# 两个半边出自同一 derivation(ahujasid/blender-mcp 1.8.3,PyPI sdist):
#   - MCP server:buildPythonPackage → bin/blender-mcp。上游 1.8.3 依赖已收敛为
#     mcp(>=1.9,<2)+ httpx(telemetry 走 httpx 直连 REST,1.5.x 的 supabase/
#     tomli 已移除);consent_prompt 直接 import pydantic,显式声明。sdist 完整
#     自洽(含 config.py;git HEAD 是未发布重构中间态,勿改钉 git)
#   - Blender addon:上游以 package-data 内嵌 bundled/addon.py,从 server 的
#     site-packages 提取 → BLENDER_SYSTEM_SCRIPTS 脚本树(Blender 官方部署机制,
#     deploying_blender:$SYSTEM_SCRIPTS/addons/ 放插件 + startup/ 启动期启用)。
#     addon/server 版本一致性由构造保证;卸载本包 = 环境变量指向的树一起消失,
#     不存在 ~/.config 里的孤儿拷贝(addon 纯 stdlib,无需 withPackages)
#
# Blender 本体 = blender.override { cudaSupport = true; }(Cycles CUDA + OptiX;
# OptiX 使 license 含 unfree,依赖 modules/nixos/nix.nix 的 allowUnfree)。
# cuda 变体不在 cache.nixos.org:首次构建/nixpkgs bump 后本机源码编译(小时级,
# 可先 nix build .#blender-cuda 后台预热)。无三方 cachix 可挂:adithyagenie 缓存
# 钉其自建 nixpkgs-25.05 pin,与本仓 unstable 的 derivation hash 必然不同。
{
  lib,
  blender,
  fetchurl,
  makeWrapper,
  python3Packages,
  runCommand,
}:

let
  server = python3Packages.buildPythonPackage rec {
    pname = "blender-mcp";
    version = "1.8.3";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/77/60/1f98ca777a08d6461d71f1634c87baaa2ecac105acd4bddd3237223d8f63/blender_mcp-${version}.tar.gz";
      hash = "sha256-hj5rqbzsPTCGghuGzgu/y07VtYQkgBenW0WWb3NDQCM=";
    };

    build-system = [ python3Packages.setuptools ];

    dependencies = with python3Packages; [
      httpx
      mcp
      pydantic
    ];

    # server 模块树不 import bpy(trajectory 仅懒加载)——此检查兼作 sdist 自洽性
    # 断言(config.py 在位、无已移除依赖的硬 import)
    pythonImportsCheck = [ "blender_mcp.server" ];

    meta = {
      description = "Blender integration through the Model Context Protocol";
      homepage = "https://github.com/ahujasid/blender-mcp";
      license = lib.licenses.mit;
      mainProgram = "blender-mcp";
    };
  };

  cudaBlender = blender.override {
    cudaSupport = true;
    rocmSupport = false;
  };

  # Blender 官方 SYSTEM 级脚本树:LOCAL/USER 之外的第三棵只读脚本目录
  systemScripts = runCommand "blender-mcp-scripts" { } ''
    mkdir -p $out/scripts/addons $out/scripts/startup
    # addon 从 server 包内提取(bundled/addon.py);路径缺失即构建失败,隐式断言
    cp ${server}/${python3Packages.python.sitePackages}/blender_mcp/bundled/addon.py \
      $out/scripts/addons/blender_mcp.py
    # 会话级启用(不写 userpref):nix 语义 = 每次启动都活跃;GUI 勾选状态留给
    # 用户,addon_utils.enable 幂等,两者互不冲突
    cat > $out/scripts/startup/enable_addons.py <<'EOF'
    import addon_utils
    addon_utils.enable("blender_mcp", default_set=False, persistent=False)
    EOF
  '';
in
runCommand "blender-cuda-${cudaBlender.version}"
  {
    nativeBuildInputs = [ makeWrapper ];

    passthru = {
      inherit server systemScripts;
    };

    meta = (builtins.removeAttrs cudaBlender.meta [ "outputsToInstall" ]) // {
      description = "Blender (CUDA) with blender-mcp addon preloaded via BLENDER_SYSTEM_SCRIPTS";
      mainProgram = "blender";
    };
  }
  ''
    mkdir -p $out/bin $out/share/applications
    # desktop 入口直拷(Exec=blender 与本包 bin 名一致;图标目录符号链接)
    cp ${cudaBlender}/share/applications/blender.desktop $out/share/applications/
    ln -s ${cudaBlender}/share/icons $out/share/icons
    # CLI 与 GUI 同路径:wrapper 注入 SYSTEM_SCRIPTS,点图标和敲命令行为一致
    makeWrapper ${cudaBlender}/bin/blender $out/bin/blender \
      --set BLENDER_SYSTEM_SCRIPTS ${systemScripts}
    # MCP server 半边直通(项目级 MCP 条目按名引用,见 common/mcp-project.nix)
    ln -s ${server}/bin/blender-mcp $out/bin/blender-mcp
  ''
