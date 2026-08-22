# filepath: ~/nixos-config/users/fww/desktop/blender.nix
# Blender(CUDA)+ blender-mcp 部署:归属 desktop(AI 是叠加的控制接口,非本体域)
#
# N 卡门控同 koharu.nix:宿主声明 nvidia 驱动才部署(CUDA 渲染依赖它);
# 求值期纯判断,HM standalone 视为无 N 卡。额外排除 vmtest:其 params.gpu="nvidia"
# 是 initrd 模块测试的夹具产物(hosts/vmtest/default.nix 126-129),QEMU 内无真实
# GPU——不排除的话装机彩排循环会拖进小时级 CUDA blender 编译。
# MCP 接线在 ai/common/mcp-project.nix 的 "blender-mcp" 条目(项目级 opt-in,
# 按名引用 bin/blender-mcp,不走 store path 插值——避免非 N 卡主机也被牵进
# 闭包)。使用序:启 Blender → N 面板 BlenderMCP → Start MCP Server(TCP 9876)
# → 项目 manifest 声明 blender-mcp。
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # 同 koharu:宿主声明了 nvidia 驱动才部署;HM standalone 时视为无 N 卡
  videoDrivers = osConfig.services.xserver.videoDrivers or [ ];
  hasNvidia = builtins.elem "nvidia" videoDrivers;
  # vmtest 夹具排除(见头注释)。不探测 virtualisation.vmVariant:raw 类型
  # option,判断即强迫嵌套 VM 配置求值(HM 侧引爆);夹具点名最直白
  isRehearsalVm = osConfig.networking.hostName == "vmtest";
in
{
  home.packages = lib.mkIf (hasNvidia && !isRehearsalVm) [ pkgs.blender-cuda ];
}
