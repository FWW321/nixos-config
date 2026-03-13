# filepath: ~/nixos-config/hosts/FWW-Desktop/disko.nix
{
  disko.devices = {
    disk = {
      system_disk = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = { size = "1G"; type = "EF00"; content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; mountOptions = [ "umask=0077" ]; }; };
            swap = { size = "34G"; content = { type = "swap"; resumeDevice = true; }; };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@root" = { mountpoint = "/"; mountOptions = ["compress=zstd" "noatime" "ssd"]; };
                  "@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" "ssd" ]; };
                };
              };
            };
          };
        };
      };
      home_disk = {
        type = "disk";
        device = "/dev/nvme2n1";
        content = {
          type = "gpt";
          partitions = {
            home = {
              size = "100%";
              content = { type = "btrfs"; extraArgs = [ "-f" ]; subvolumes = { "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" "ssd"]; }; }; };
            };
          };
        };
      };
      data_disk = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = { type = "btrfs"; extraArgs = [ "-f" ]; subvolumes = { "@data" = { mountpoint = "/data"; mountOptions = [ "compress=zstd" "noatime" "ssd" ]; }; }; };
            };
          };
        };
      };
    };
  };
}
