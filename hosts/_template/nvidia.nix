# filepath: ~/nixos-config/hosts/<host>/nvidia.nix(由 _template 物化,向导按架构填参)
#
# 适用边界(照抄会导致错误安装的场景,均已在向导自动判定,手动复用时注意):
#   - open 模块:仅 Turing+(GTX 16xx/RTX 20xx,2018+,依赖 GSP);Maxwell/Pascal/
#     Volta(GTX 9xx/10xx,TITAN V)必须闭源,且 580 是终点分支(nvidia 官方
#     support timeframes)→ package 需 legacy_580。Blackwell+ 反向只支持 open。
#   - 混合显卡笔记本(Intel/AMD 核显 + N 卡):本文件缺 PRIME 段,见下方 TODO
#   - 单卡桌面 Turing+:本文件即完整配置
{
  config,
  pkgs,
  ...
}:

{
  # 加载 nvidia 驱动
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # 电源管理 - 必须开启以支持休眠/挂起
    powerManagement.enable = true;
    # 开源内核模块:{{NVIDIA_OPEN}}(Turing+ 为 true;Maxwell/Pascal/Volta 为 false,不兼容)
    open = {{NVIDIA_OPEN}};
    nvidiaSettings = true;
    # {{NVIDIA_PACKAGE}}:latest(Turing+)| legacy_580(Maxwell/Pascal/Volta 终点分支)
    package = config.boot.kernelPackages.nvidiaPackages.{{NVIDIA_PACKAGE}};

    # TODO 混合显卡笔记本(核显+N卡)解开并填 bus id(`lspci | grep -E 'VGA|3D'` 十六进制转十进制):
    # prime = {
    #   intelBusId  = "PCI:0:2:0";   # 例:00:02.0
    #   nvidiaBusId = "PCI:1:0:0";   # 例:01:00.0
    #   offload = {
    #     enable = true;             # 按需渲染(省电);reverse_sync 让外接屏走 N 卡输出
    #     enableOffloadCmd = true;   # 提供 nvidia-offload 命令
    #   };
    # };
  };

  # NVIDIA Container Toolkit — 让 podman 容器能用 GPU(无 GPU 容器需求可删)
  hardware.nvidia-container-toolkit.enable = true;

  # NVIDIA 早期加载 - 确保在 display manager 前加载驱动
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # NVIDIA DRM 和休眠支持内核参数
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    # fbdev 需 545+ 驱动(legacy 分支无此特性;混合显卡场景若屏显异常先删此行)
    "nvidia_drm.fbdev=1"
    # 显存保存到磁盘而非 tmpfs，避免休眠失败
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # Wayland 环境变量
  # 已删 GBM_BACKEND(驱动 560+ GBM loader 自动选 nvidia-drm 后端,单卡无需硬钉,
  # Hyprland wiki 现行版也已移除)与 WLR_NO_HARDWARE_CURSORS(Hyprland 官方废弃,
  # niri 非 wlroots 不读)
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # VRR/G-Sync 支持
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    # NVIDIA VA-API 后端
    NVD_BACKEND = "direct";
    # DLSS / NVAPI:Proton 下启用 N 卡专属功能（DLSS 升档、Reflex、帧生成）
    # 需配合带 NVAPI 的 Proton（如 proton-cachyos，自带 DXVK-NVAPI）
    # 内核模块开/闭源不影响——DLSS 走 userspace NVAPI，两边都支持
    # (GTX 无光追卡无 DLSS,但 NVAPI 其余功能仍有效,保留无害)
    PROTON_ENABLE_NVAPI = "1"; # 暴露 NVAPI 接口给游戏
    DXVK_NVAPIHACK = "0"; # 关闭 GPU 伪装，让真 NVAPI/DLSS 路径生效
  };

  # NVIDIA 专用监控工具，仅在此主机装
  home-manager.users.fww.home.packages = [ pkgs.nvtopPackages.nvidia ];
}
