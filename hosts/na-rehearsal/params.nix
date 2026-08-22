# filepath: ~/nixos-config/hosts/na-rehearsal/params.nix
# NA 装机彩排夹具:QEMU 内 /dev/vda 单盘、无独显(gpu=null)、swap 2G
# (夹具不休眠,小 swap 缩短装机时的 mkswap)
{
  cpuProfile = "common-cpu-intel";

  gpu = null;

  nvidia = {
    open = true;
    package = "latest";
  };

  disks = {
    system = "/dev/vda";
    home = null;
    data = null;
  };

  swapGiB = 2;
}
