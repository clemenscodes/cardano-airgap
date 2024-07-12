self: {device ? "/dev/disk/AIRGAP_DATA_DEVICE_UPDATE_ME", ...}: let
  inherit
    (self.imageParameters)
    signingUserUid
    signingUserGid
    publicVolName
    encryptedVolName
    ;

  uidGid = "${toString signingUserUid}:${toString signingUserGid}";
in {
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
              extraArgs = ["-L ${publicVolName}" "-E root_owner=${uidGid}"];
            };
          };

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = encryptedVolName;
              settings.allowDiscards = true;
              askPassword = true;
              extraFormatArgs = ["--label ${encryptedVolName}"];
              postMountHook = "dmsetup ls --target crypt --exec 'cryptsetup close' 2> /dev/null";
              content = {
                type = "filesystem";
                format = "ext4";
                extraArgs = ["-L ${encryptedVolName}" "-E root_owner=${uidGid}"];
              };
            };
          };
        };
      };
    };
  };
}
