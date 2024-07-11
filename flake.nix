{
  inputs = {
    # Nixpkgs 24.05 for latest gnome image and devenv hooks
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Required image signing tooling
    credential-manager.url = "github:IntersectMBO/credential-manager/signing-tool";
    systems.url = "github:nix-systems/default";

    # For easy language and hook support
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    # For declarative block device provisioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # For fetch-closure shrunk release packages with minimal eval time and dependency sizes
    capkgs.url = "github:input-output-hk/capkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
    extra-substituters = [
      "https://devenv.cachix.org"
      "https://cache.iog.io"
    ];
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    disko,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    # For direnv nix version shell evaluation
    inherit (nixpkgs) lib;

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              # https://devenv.sh/reference/options/
              packages = [
                pkgs.coreutils
                pkgs.cryptsetup
                disko.packages.${system}.disko

                (pkgs.writeShellScriptBin "qemu-run-iso" ''
                  if [ -s result/iso/nixos-*.iso ]; then
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
                    -cpu host \
                    -smp 2 \
                    -m 4G \
                    -nic none \
                    -drive file=result-iso,format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
                    -device ahci,id=achi0 \
                    -device ide-cd,bus=achi0.0,drive=drive-cd1,id=cd1,bootindex=1 \
                    "$@"
                '')
              ];

              languages.nix.enable = true;

              pre-commit.hooks = {
                alejandra.enable = true;
                deadnix.enable = true;
                statix.enable = true;
              };
            }
          ];
        };
      });

    nixosConfigurations.airgap-boot = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [./airgap-boot.nix];
      specialArgs = {
        inherit self;
        system = "x86_64-linux";
      };
    };

    diskoConfigurations.airgap-data = import ./airgap-data.nix;
  };
}
