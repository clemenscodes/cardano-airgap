## Building the disk image:

```bash
$ nix build .#nixosConfigurations.airgap.config.system.build.isoImage
```

## Testing the image:

```bash
qemu-system-x86_64 -enable-kvm -m 256 -cdrom result/iso/*.iso
```
