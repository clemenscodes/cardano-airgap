self: system: let
  inherit (self.imageParameters) documentsDir secretsDir;
  inherit (builtins) attrValues;
  inherit (self.lib) concatMap concatStringsSep unique;

  pkgs = self.inputs.nixpkgs.legacyPackages.${system};
in {
  flakeClosureRef = flake: let
    flakesClosure = flakes:
      if flakes == []
      then []
      else
        unique (flakes
          ++ flakesClosure (concatMap (flake:
            if flake ? inputs
            then attrValues flake.inputs
            else [])
          flakes));
  in
    pkgs.writeText "flake-closure" (concatStringsSep "\n" (flakesClosure [flake]) + "\n");

  qemu-run-iso = pkgs.writeShellApplication {
    name = "qemu-run-iso";
    runtimeInputs = with pkgs; [fd qemu_kvm];

    text = ''
      if fd --type file --has-results 'nixos-.*\.iso' result/iso 2> /dev/null; then
        echo "Symlinking the existing iso image for qemu:"
        ln -sfv result/iso/nixos-*.iso result-iso
        echo
      else
        echo "No iso file exists to run, please build one first, example:"
        echo "  nix build -L .#nixosConfigurations.airgap-boot.config.system.build.isoImage"
        exit
      fi

      if [ "$#" = 0 ]; then
        echo "Not passing through any host devices; see the README.md if you would like to do that."
      fi

      # Don't allow qemu to network an airgapped machine test with `-nic none`
      qemu-kvm \
        -smp 2 \
        -m 4G \
        -nic none \
        -drive file=result-iso,format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
        -device ahci,id=achi0 \
        -device ide-cd,bus=achi0.0,drive=drive-cd1,id=cd1,bootindex=1 \
        "$@"
    '';
  };

  signing-tool-with-config = pkgs.writeShellApplication {
    name = "signing-tool-with-config";
    runtimeInputs = [
      self.inputs.credential-manager.packages.${system}.signing-tool
    ];

    text = ''
      signing-tool --config-file /etc/signing-tool-config.json "$@"
    '';
  };

  unmount-airgap-data = pkgs.writeShellApplication {
    name = "unmount-airgap-data";
    runtimeInputs = with pkgs; [cryptsetup util-linux];

    text = ''
      echo "Unmounting:"
      sudo umount --verbose ${documentsDir}
      sudo umount --verbose ${secretsDir}
      echo

      echo "Closing crypted luks volumes."
      sudo bash -c 'dmsetup ls --target crypt --exec "cryptsetup close"'

      echo "Syncing."
      sync

      echo
      echo "It is now safe to remove the airgap-data thumbdrive."
    '';
  };
}
