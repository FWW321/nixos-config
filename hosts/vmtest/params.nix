# vmtest:vmWithDisko 端到端验证夹具(零污染:/dev/vda 仅存在于镜像文本)
{
  cpuProfile = "common-cpu-intel";
  gpu = "nvidia";
  nvidia = {
    open = true;
    package = "latest";
  };
  disks = {
    system = "/dev/vda";
    home = null;
    data = null;
  };
  swapGiB = 2; # VM 不休眠,缩到 2G 让镜像可控
}
