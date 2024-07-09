{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    credential-manager.url = "github:IntersectMBO/credential-manager?ref=signing-tool";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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

  outputs = { self, nixpkgs, devenv, systems, disko, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # https://devenv.sh/reference/options/
                  packages = [
                    disko.packages.${system}.disko-install
                    (pkgs.writeShellScriptBin "qemu-system-x86_64-uefi" ''
                      qemu-system-x86_64 \
                        -bios ${pkgs.OVMF.fd}/FV/OVMF.fd \
                        "$@"
                    '')
                  ];
                  languages.nix.enable = true;
                  pre-commit.hooks = {
                    nixpkgs-fmt.enable = true;
                  };
                }
              ];
            };
          });

      nixosConfigurations.airgap = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./airgap.nix
          disko.nixosModules.disko
          {
            disko.devices = {
              disk.main = {
                device = "/dev/disk/by-id/some-disk-id";
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = {
                      type = "EF00";
                      size = "500M";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountOptions = [ "umask=0077" ];
                        mountpoint = "/boot";
                      };
                    };
                    public = {
                      size = "2G";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/public";
                      };
                    };
                    luks = {
                      size = "100%";
                      content = {
                        type = "luks";
                        name = "crypted";
                        settings.allowDiscards = true;
                        askPassword = true;
                        content = {
                          type = "filesystem";
                          format = "ext4";
                          mountpoint = "/";
                        };
                      };
                    };
                  };
                };
              };
            };
          }
        ];
        specialArgs = inputs;
      };
    };
}
