{
  lib,
  modulesPath,
  pkgs,
  self,
  system,
  ...
}: let
  inputPkg = input: pkg: self.inputs.${input}.packages.${system}.${pkg};
in {
  imports = [(modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")];

  boot = {
    initrd.availableKernelModules = [
      # Support for various usb hubs
      "ohci_pci"
      "ohci_hcd"
      "ehci_pci"
      "ehci_hcd"
      "xhci_pci"
      "xhci_hcd"

      # May be needed in some situations
      "uas"

      # Needed to mount usb as a storage device
      "usb-storage"
    ];

    kernelModules = ["kvm-intel"];

    supportedFilesystems = ["zfs"];

    # To address build time warn
    swraid.enable = lib.mkForce false;
  };

  documentation.info.enable = false;

  environment = {
    # Embed this flake source in the iso to re-use the disko or other configuration
    etc.flake.source = self.outPath;

    systemPackages = with pkgs; [
      (inputPkg "capkgs" "cardano-address-cardano-foundation-cardano-wallet-v2024-07-07-29e3aef")
      (inputPkg "capkgs" "cardano-cli-input-output-hk-cardano-node-9-0-0-2820a63")
      (inputPkg "credential-manager" "orchestrator-cli")
      (inputPkg "credential-manager" "signing-tool")
      (inputPkg "disko" "disko")

      glibc
      gnome.adwaita-icon-theme
      gnupg
      jq
      neovim
      sqlite-interactive
      usbutils
    ];
  };

  # Disable squashfs for testing only
  # Comment this out when ready to distribute
  isoImage.squashfsCompression = (lib.warn "Generating a testing only ISO with compression disabled") null;

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      accept-flake-config = true
    '';

    nixPath = ["nixpkgs=${pkgs.path}"];
    settings.trusted-users = ["cc-signer"];
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    enableIPv6 = false;
    interfaces = lib.mkForce {};
    hostId = "ffffffff";
    hostName = "cc-airgap";
    useDHCP = false;
    wireless.enable = lib.mkForce false;
  };

  programs = {
    bash.enableCompletion = true;
    dconf.enable = true;
    gnupg.agent.enable = true;
  };

  services = {
    displayManager.autoLogin.user = lib.mkForce "cc-signer";

    udev.extraRules = ''
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="2b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="3b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="4b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1807", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1808", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0000", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2c97"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2581"
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';
  };

  systemd.user.services.dconf-defaults = {
    script = let
      dconfDefaults = pkgs.writeText "dconf.defaults" ''
        [org/gnome/desktop/background]
        color-shading-type='solid'
        picture-options='zoom'
        picture-uri='${./cardano.png}'
        primary-color='#000000000000'
        secondary-color='#000000000000'

        [org/gnome/desktop/lockdown]
        disable-lock-screen=true
        disable-log-out=true
        disable-user-switching=true

        [org/gnome/desktop/notifications]
        show-in-lock-screen=false

        [org/gnome/desktop/screensaver]
        color-shading-type='solid'
        lock-delay=uint32 0
        lock-enabled=false
        picture-options='zoom'
        picture-uri='${./cardano.png}'
        primary-color='#000000000000'
        secondary-color='#000000000000'

        [org/gnome/settings-daemon/plugins/media-keys]
        custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']

        [org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
        binding='<Primary><Alt>t'
        command='gnome-terminal'
        name='terminal'

        [org/gnome/settings-daemon/plugins/power]
        idle-dim=false
        power-button-action='interactive'
        sleep-inactive-ac-type='nothing'

        [org/gnome/shell]
        welcome-dialog-last-shown-version='41.2'

        [org/gnome/terminal/legacy]
        theme-variant='dark'
      '';
    in ''
      ${pkgs.dconf}/bin/dconf load / < ${dconfDefaults}
    '';
    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
  };

  users = {
    allowNoPasswordLogin = true;
    defaultUserShell = pkgs.bash;
    mutableUsers = false;

    users.cc-signer = {
      createHome = true;
      extraGroups = ["wheel"];
      group = "users";
      home = "/home/cc-signer";
      uid = 1234;
      isNormalUser = true;
    };
  };

  # To address build time warn
  system.stateVersion = lib.versions.majorMinor lib.version;
}
