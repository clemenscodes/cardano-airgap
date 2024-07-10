{ device ? "/dev/disk/AIRGAP_DATA_DEVICE_UPDATE_ME", ... }: {
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          public = {
            size = "8G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/public";
            };
          };

          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "airgap-encrypted";
            };
          };

          # Alternative if we have difficulty with ZFS
          # luks = {
          #   size = "100%";
          #   content = {
          #     type = "luks";
          #     name = "crypted";
          #     settings.allowDiscards = true;
          #     askPassword = true;
          #     content = {
          #       type = "filesystem";
          #       format = "ext4";
          #       mountpoint = "/";
          #     };
          #   };
          # };
        };
      };
    };

    zpool = {
      airgap-encrypted = {
        name = "airgap-encrypted";
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
          acltype = "posixacl";
          xattr = "sa";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
        };
        mountpoint = "/airgap-encrypted";
      };
    };
  };
}
