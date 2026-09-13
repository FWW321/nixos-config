# Blender 基金会官方 MCP server(Blender Lab,projects.blender.org/lab/blender_mcp)
# 与 ahujasid/blender-mcp 互补:官方版捆绑 Blender Python API + 手册 rst 文档
# 可检索,主打场景分析与文档查询;"deliberately small" 是它的自述。
#
# 一次源码拉取,两个半边:
#   - MCP server(mcp/blmcp):buildPythonPackage → bin/blender-lab-mcp。
#     入口原名 blender-mcp,与 ahujasid 包同名,postInstall 改名避让
#   - Blender addon(addon/blender_mcp_addon):转 legacy 格式进 $out/share,
#     由 blender-cuda 组装件的 SYSTEM_SCRIPTS 树收录(见其 package.nix)
#
# 源码:Gitea archive 直链被 Cloudflare 挑战页拦(403);api/v1 archive 端点
# 可过(nix 默认 UA 实测 200),nixpkgs 无此包,fetchurl 直取。
# tag v1.0.3(首个发布版 v1.0.0,要求 Blender 5.1+,本机 5.2 ✓)
{
  lib,
  fetchurl,
  python3Packages,
}:

python3Packages.buildPythonPackage rec {
  pname = "blender-lab-mcp";
  version = "1.0.3";
  pyproject = true;

  src = fetchurl {
    url = "https://projects.blender.org/api/v1/repos/lab/blender_mcp/archive/v${version}.tar.gz";
    hash = "sha256-jcHddDN1WFe9KuNUIPjPT1nNxhhG0adUFmWcNP0XyXI=";
  };
  # server 在 mcp/ 子目录;addon 留在同级 ../addon 供 postInstall 收集
  sourceRoot = "blender_mcp/mcp";

  build-system = [ python3Packages.setuptools ];

  # pyproject 声明 docutils/mcp[cli]/pyyaml;[cli] extra(typer 系)仅上游
  # 调试 CLI 用,stdio 路径 argparse 直解析,实测不需要
  dependencies = with python3Packages; [
    docutils
    mcp
    pyyaml
  ];

  pythonImportsCheck = [ "blmcp" ];

  # addon 是 extension 格式(blender_manifest.toml,无 bl_info),而 5.2 的
  # bl_ext 系统仓库只认 Blender 自带前缀的 extensions/system——CUSTOM
  # SYSTEM_SCRIPTS 树塞不进(实测)。注入 bl_info 转 legacy addon,走 addons/
  # 旧机制,enable/端口/socket/代码执行 xvfb 全真链路实测通过。
  # 改动仅此一处,上游 bump 时 diff 立现
  postPatch = ''
    # dist 名与 pname 对齐(nixpkgs 元数据一致性检查要求;入口名在 postInstall 再改)
    sed -i 's/^name = "blender-mcp"/name = "blender-lab-mcp"/' pyproject.toml
    python3 - <<'PYEOF'
    path = "../addon/blender_mcp_addon/__init__.py"
    src = open(path).read()
    bl_info = "\n".join([
        "",
        "bl_info = {",
        "    \"name\": \"MCP (Blender Lab)\",",
        "    \"author\": \"Blender Lab\",",
        "    \"version\": (1, 0, 3),",
        "    \"blender\": (5, 1, 0),",
        "    \"location\": \"Preferences > Add-ons\",",
        "    \"description\": \"MCP socket bridge-server add-on (legacy packaging for declarative scripts tree)\",",
        "    \"category\": \"Development\",",
        "}",
        "",
        "",
    ])
    marker = "\"\"\"\n\n"
    assert marker in src, "addon __init__ header changed, rebase bl_info injection"
    open(path, "w").write(src.replace(marker, marker + bl_info, 1))
    PYEOF
  '';

  postInstall = ''
    mkdir -p $out/share/blender-lab-mcp
    cp -r ../addon/blender_mcp_addon $out/share/blender-lab-mcp/addon
    # 与 ahujasid 包的 bin/blender-mcp 同名冲突,改名(见 blender-cuda 组装)
    mv $out/bin/blender-mcp $out/bin/blender-lab-mcp
  '';

  meta = {
    description = "Official Blender Lab MCP server (documentation-aware scene analysis for Blender)";
    homepage = "https://www.blender.org/lab/mcp-server/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-lab-mcp";
  };
}
