## Build the airgap-boot disk image:
```bash
$ nix build .#nixosConfigurations.airgap-boot.config.system.build.isoImage
```

## Test the airgap-boot image:
```bash
qemu-run-iso
```

## Test the airgap-boot image with a host passed device:
```bash
# Find the device of interest, in this case a thumbdrive:
❯ lsusb | grep -i sandisk
Bus 001 Device 030: ID 0781:5567 SanDisk Corp. Cruzer Blade

# Pass the device to qemu based on vendor and product id:
sudo qemu-run-iso -device nec-usb-xhci,id=xhci -device usb-host,vendorid=0x0781,productid=0x5567

# Or, pass a bus and address to qemu:
sudo qemu-run-iso -device nec-usb-xhci,id=xhci -device usb-host,hostbus=1,hostaddr=30
```

## Create the airgap-data thumbdrive:
```bash
# WARNING -- BE ABSOLUTELY SURE YOU HAVE THE CORRECT DEVICE LISTED AS THIS DRIVE WILL BE WIPED!
# WARNING -- Do a dry first if desired and cat the resulting output script
#
# Here, `$YOUR_AIRGAP_DATA_DRIVE` is the path to the airgap data thumbdrive,
# which may be something like: /dev/sdb
disko -m disko --dry-run -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"

# If satisfied, run it -- this drive will be wiped, partitioned, formatted and encrypted!:
sudo disko -m disko -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"
```
