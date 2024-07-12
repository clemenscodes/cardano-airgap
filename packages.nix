self: system: let
  inherit (self.imageParameters) documentsDir etcFlakePath secretsDir;
  inherit (builtins) attrValues;
  inherit (self.lib) concatMap concatStringsSep unique;

  pkgs = self.inputs.nixpkgs.legacyPackages.${system};
in {
  format-airgap-data = pkgs.writeShellApplication {
    name = "format-airgap-data";
    runtimeInputs = with pkgs; [
      self.inputs.disko.packages.${system}.disko
      usbutils
      util-linux
    ];

    text = ''
      ARGS=("$@")

      PRINT_HELP() {
        echo "Command usage:"
        echo "  format-airgap-data [--dry-run] --argstr device \"\$YOUR_AIRGAP_DATA_DRIVE\" [extra-options]"
        echo
        echo "Where:"
        echo "\$YOUR_AIRGAP_DATA_DRIVE is the path to the airgap data"
        echo "drive, which may be something like: /dev/sda"
        echo
        echo "The device being formatted should be at least 16 GB in size or the format may fail."
        echo
        echo "[extra-options] may be additional options as accepted by disko"
        echo "These can be viewed with the command: disko --help"
        echo
        echo "Commands which can help you identify the proper drive to format are:"
        echo
        echo "lsblk -o +label:"
        lsblk -o +label
        echo
        echo "lsusb:"
        lsusb
        echo
        exit
      }

      DRY_RUN="false"
      if [ "$#" = "0" ]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]-h[[:space:]] ]]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]--help[[:space:]] ]]; then
        PRINT_HELP
      elif [[ ! " ''${ARGS[*]} " =~ [[:space:]]--argstr[[:space:]]device[[:space:]] ]]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]--dry-run[[:space:]] ]]; then
        DRY_RUN="true"
      fi

      for i in "''${!ARGS[@]}"; do
       if [ "''${ARGS[$i]}" = "device" ]; then
         if [ "$#" -lt "$((i + 2))" ]; then
           PRINT_HELP
         fi
         DEVICE=''${ARGS[$i + 1]};
       fi
      done

      if [ "$DRY_RUN" = "false" ]; then
        echo "WARNING: Device $DEVICE is about to be completely wiped and formatted!"
        read -p "Do you wish to proceed [yY]? " -n 1 -r
        echo
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "Aborting."
          exit
        fi
      else
        echo "Dry run request detected -- no actual formatting actions will be carried out."
        echo "The script path printed below can be reviewed prior to running for real."
        echo
      fi

      sudo disko \
      -m disko \
      /etc/${etcFlakePath}/airgap-disko.nix \
      --arg substitute false \
      "$@"
    '';
  };

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
      sudo umount --verbose ${documentsDir} || true
      sudo umount --verbose ${secretsDir} || true
      echo

      echo "Closing crypted luks volumes."
      sudo bash -c 'dmsetup ls --target crypt --exec "cryptsetup close"' || true

      echo "Syncing."
      sync || true

      echo
      echo "If no unexpected errors are seen above, it is now safe to remove the airgap-data device."
    '';
  };
}
