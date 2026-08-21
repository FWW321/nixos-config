# filepath: ~/nixos-config/hosts/<host>/params.nix
# 主机参数唯一真源 —— install.sh 向导探测后生成(或手写)。
# default.nix/disko.nix/nvidia.nix 均从这里读值;类型错误/缺字段会在
# nix eval 时当场报错(动盘之前),不存在模板替换漏填的可能
{
  # nixos-hardware 的 CPU profile attr 名(common-cpu-intel / common-cpu-amd)
  cpuProfile = "common-cpu-intel";

  # 独显:"nvidia" | null(核显/AMD 免专项模块)
  gpu = "nvidia";

  # NVIDIA 参数(仅 gpu = "nvidia" 时被读):
  #   open = Turing+ 为 true;Maxwell/Pascal/Volta 为 false(无 GSP,不兼容)
  #   package = "latest"(Turing+)| "legacy_580"(Maxwell/Pascal/Volta 终点分支)
  nvidia = {
    open = true;
    package = "latest";
  };

  # 磁盘角色(整盘路径;多余角色 null = 落回系统盘子卷)
  disks = {
    system = "/dev/nvme0n1";
    home = null;
    data = null;
  };

  # swap(GiB;休眠需 ≥ 内存大小)
  swapGiB = 32;
}
