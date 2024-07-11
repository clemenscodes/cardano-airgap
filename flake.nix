{
  inputs = {
    # Nixpkgs 24.05 required for working devenv pre-commit hook nix functionality
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
                disko.packages.${system}.disko
                (pkgs.writeShellScriptBin "qemu-run-iso" ''
                  qemu-system-x86_64 \
                    -enable-kvm \
                    -cpu host \
                    -smp 2 \
                    -m 4G \
                    -cdrom result/iso/nixos-*.iso \
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
      specialArgs = {inherit inputs;};
    };

    diskoConfigurations.airgap-data = import ./airgap-data.nix;
  };
}
