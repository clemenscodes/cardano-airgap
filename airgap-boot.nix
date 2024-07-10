{ config, pkgs, modulesPath, lib, credential-manager, ... }: {
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix") ];

  boot = {
    initrd.availableKernelModules = [
      # support for various usb hubs
      "ohci_pci"
      "ohci_hcd"
      "ehci_pci"
      "ehci_hcd"
      "xhci_pci"
      "xhci_hcd"

      "uas" # may be needed in some situations
      "usb-storage" # needed to mount usb as a storage device
    ];

    kernelModules = [ "kvm-intel" ];

    supportedFilesystems = [ "zfs" ];

    # To address build time warn
    swraid.enable = lib.mkForce false;
  };

  documentation.info.enable = false;

  environment.systemPackages = with pkgs; [
    chromium
    credential-manager.packages.x86_64-linux.orchestrator-cli
    credential-manager.packages.x86_64-linux.signing-tool
    encfs
    glibc
    gnome.adwaita-icon-theme
    gnupg
    jq
    sqlite-interactive
    termite
    vim
  ];

  # To speed up testing -- comment out when ready to distribute for a smaller squashfs
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  nix = {
    extraOptions = "experimental-features = nix-command flakes";
    nixPath = [ "nixpkgs=${pkgs.path}" ];
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    wireless.enable = lib.mkForce false;
    hostName = "cc-airgap";
    hostId = "ffffffff";
  };

  programs = {
    bash.enableCompletion = true;
    dconf.enable = true;
    gnupg.agent.enable = true;
  };

  services = {
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

    xserver.displayManager.autoLogin.user = lib.mkForce "cc-signer";
  };

  systemd.user.services.dconf-defaults = {
    script =
      let
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
      in
      ''
        ${pkgs.dconf}/bin/dconf load / < ${dconfDefaults}
      '';
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };

  users = {
    allowNoPasswordLogin = true;
    defaultUserShell = pkgs.bash;
    mutableUsers = false;

    users.cc-signer = {
      createHome = true;
      extraGroups = [ "wheel" ];
      group = "users";
      home = "/home/cc-signer";
      uid = 1234;
      isNormalUser = true;
    };
  };

  # To address build time warn
  system.stateVersion = lib.versions.majorMinor lib.version;
}
