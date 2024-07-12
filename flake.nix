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
    capkgs,
    credential-manager,
    disko,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    # For direnv nix version shell evaluation
    inherit (nixpkgs) lib;

    # General image parameters used throughout nix code
    inherit (import ./image-parameters.nix) imageParameters;

    packages = forEachSystem (system: import ./packages.nix self system);

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = [
                pkgs.coreutils
                pkgs.cryptsetup
                capkgs.packages.${system}.cardano-address-cardano-foundation-cardano-wallet-v2024-07-07-29e3aef
                capkgs.packages.${system}."\"cardano-cli:exe:cardano-cli\"-input-output-hk-cardano-cli-cardano-cli-9-0-0-1-33059ee"
                credential-manager.packages.${system}.orchestrator-cli
                credential-manager.packages.${system}.signing-tool
                disko.packages.${system}.disko
                self.packages.${system}.qemu-run-iso
              ];

              # https://devenv.sh/reference/options/
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

    diskoConfigurations.airgap-data = import ./airgap-data.nix self;
  };
}
