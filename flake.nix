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
    credential-manager,
    disko,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    # For direnv nix version shell evaluation
    inherit (nixpkgs) lib;

    # General image parameters used throughout nix code
    imageParameters = rec {
      # Set to false when ready to generate and distrubte an image
      testImage = true;

      publicVolName = "public";
      encryptedVolName = "encrypted";

      documentsDir = "/run/media/${signingUser}/${publicVolName}";
      secretsDir = "/run/media/${signingUser}/${encryptedVolName}";

      hostId = "ffffffff";
      hostName = "cc-airgap";

      signingUser = "cc-signer";
      signingUserUid = 1234;
      signingUserGid = 100;
      signingUserGroup = "users";
    };

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
                disko.packages.${system}.disko
                credential-manager.packages.${system}.orchestrator-cli
                credential-manager.packages.${system}.signing-tool
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
