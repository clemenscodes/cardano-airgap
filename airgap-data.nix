{device ? "/dev/disk/AIRGAP_DATA_DEVICE_UPDATE_ME", ...}: {
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
              # Will label the public partion and cause gnome to auto-mount
              # at the path of: /run/media/public with cc-signer uid:gid
              extraArgs = ["-L public" "-E root_owner=1234:100"];
            };
          };

          # Alternative if we have difficulty with ZFS
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings.allowDiscards = true;
              askPassword = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/encrypted";
                # This will label the encrypted partion and cause gnome to auto-mount
                # at the path of: /run/media/encrypted with cc-signer uid:gid
                extraArgs = ["-L encrypted" "-E root_owner=1234:100"];
              };
            };
          };
        };
      };
    };
  };
}
