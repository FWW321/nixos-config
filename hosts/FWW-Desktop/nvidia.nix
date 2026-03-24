# filepath: ~/nixos-config/hosts/FWW-Desktop/nvidia.nix
# NVIDIA GPU 配置 (RTX 4070 Ti Super / Ada Lovelace)
{ config, ... }:

{
  # 加载 nvidia 驱动
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # 电源管理 - 必须开启以支持休眠/挂起
    powerManagement.enable = true;
    # 开源内核模块 - Turing 及更新架构推荐使用
    # NVIDIA 官方已宣布开源模块逐步取代闭源模块
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # NVIDIA 早期加载 - 确保在 display manager 前加载驱动
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # NVIDIA DRM 和休眠支持内核参数
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
    # 显存保存到磁盘而非 tmpfs，避免休眠失败
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # Wayland 环境变量
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # VRR/G-Sync 支持
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    # 硬件光标可能在某些配置下有问题
    WLR_NO_HARDWARE_CURSORS = "1";
    # NVIDIA VA-API 后端
    NVD_BACKEND = "direct";
  };
}
