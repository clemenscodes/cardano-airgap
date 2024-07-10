## Building the airgap-boot disk image:
```bash
$ nix build .#nixosConfigurations.airgap-boot.config.system.build.isoImage
```

## Testing the airgap-boot image:
```bash
qemu-run-iso
```

## Creating the airgap-data thumbdrive:
```bash
# WARNING -- BE ABSOLUTELY SURE YOU HAVE THE CORRECT DEVICE LISTED AS THIS DRIVE WILL BE WIPED!
# WARNING -- Do a dry first if desired and cat the resulting output script
#
# Here, `$YOUR_AIRGAP_DATA_DRIVE` is the path to the airgap data thumbdrive,
# which may be something like: /dev/sdb
disko -m disko --dry-run -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"

# If satisfied, run it -- this drive will be wiped, partitioned, formatted and encrypted!:
sudo disko -m disko -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"

# Export the thumbdrive from the zfs pool
sudo zpool export airgap-encrypted
```
