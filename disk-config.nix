{ lib, ... }:

{

  disko.devices.disk.backup = {
    type = "disk";
    device = "/dev/nvme1n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "550M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = null; # Not mounting this one since we already have the other drive's ESP mounted
            mountOptions = [ "defaults "];
          };
        };
        LUKS = {
          size = "100%";
          content = {
            type = "luks";
            name = "backup-crypt";
            extraOpenArgs = [ "--allow-discards" ];
            passwordFile = "/tmp/password.key";
            content = null; # Not specifying content since the RAID1 will be created using nvme0n1
          };
        };
      };
    };
  };

  disko.devices.disk.primary = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "550M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/efi";
            mountOptions = [ "defaults "];
          };
        };
        LUKS = {
          size = "100%";
          content = {
            type = "luks";
            name = "primary-crypt";
            passwordFile = "/tmp/password.key"; # Interactive
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "--force" "--metadata raid1" "--data raid1" "/dev/mapper/backup-crypt" ];
              subvolumes = {
                "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd:3" "noatime" "discard=async" ];
                  };
                "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd:3" "noatime" "discard=async" ];
                  };
                "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd:3" "noatime" "discard=async" ];
                  };
                "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd:3" "noatime" "discard=async" ];
                  };
                "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd:3" "noatime" "discard=async" ];
                  };
                "@swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "32G";
                  };
              };
            };
          };
        };
      };
    };
  };

}
