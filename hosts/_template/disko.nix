# filepath: ~/nixos-config/hosts/_template/disko.nix
# 零 token:磁盘角色/swap 经 ./params.nix 类型化注入;home/data 为 null 时
# 落回系统盘子卷(单盘机与多盘机同一模板)
let
  p = import ./params.nix;
  systemDisk = p.disks.system;
  homeDisk = p.disks.home;
  dataDisk = p.disks.data;
  inherit (p) swapGiB;
  btrfsOpts = [
    "compress=zstd"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  disko.devices.disk = {
    system = {
      type = "disk";
      device = systemDisk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            # 4G 依据:本仓库内核链单代体积实测 ≈168M(cachyos LTO bzImage
            # ~14M + NVIDIA initrd 154M),configurationLimit=20 → 3.4G;
            # 另需容纳 fwupd 固件 capsule(部分主板 1-2G)。1G 会撑爆
            size = "4G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "${toString swapGiB}G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = btrfsOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOpts;
                };
              }
              // (
                if homeDisk == null then
                  {
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = btrfsOpts;
                    };
                  }
                else
                  { }
              )
              // (
                if dataDisk == null then
                  {
                    "@data" = {
                      mountpoint = "/data";
                      mountOptions = btrfsOpts;
                    };
                  }
                else
                  { }
              );
            };
          };
        };
      };
    };
  }
  // (
    if homeDisk != null then
      {
        home = {
          type = "disk";
          device = homeDisk;
          content = {
            type = "gpt";
            partitions.home = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes."@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsOpts;
                };
              };
            };
          };
        };
      }
    else
      { }
  )
  // (
    if dataDisk != null then
      {
        data = {
          type = "disk";
          device = dataDisk;
          content = {
            type = "gpt";
            partitions.data = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes."@data" = {
                  mountpoint = "/data";
                  mountOptions = btrfsOpts;
                };
              };
            };
          };
        };
      }
    else
      { }
  );
}
