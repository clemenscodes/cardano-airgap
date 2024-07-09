{ pkgs, modulesPath, lib, credential-manager, ... }: {
  imports = [ ];
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "performance";
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.emergencyAccess = true;

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  documentation.info.enable = false;

  boot.initrd.availableKernelModules = [
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

  users.defaultUserShell = pkgs.bash;
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;

  users.users.cc-signer = {
    createHome = true;
    extraGroups = [ "wheel" ];
    group = "users";
    home = "/home/cc-signer";
    uid = 1234;
    isNormalUser = true;
  };

  boot.kernelModules = [ "kvm-intel" ];
  nixpkgs.config.allowUnfree = true;
  services.udev.extraRules = ''
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
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "cc-signer";
  services.xserver.desktopManager.gnome.enable = true;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  security.sudo.wheelNeedsPassword = false;
  networking = {
    wireless.enable = lib.mkForce false;
    hostName = "cc-airgap";
    hostId = "ffffffff";
  };

  environment.systemPackages = with pkgs; [
    credential-manager.packages.x86_64-linux.signing-tool
    credential-manager.packages.x86_64-linux.orchestrator-cli
    glibc
    termite
    encfs
    chromium
    gnupg
    vim
    sqlite-interactive
    jq
  ];

  programs.dconf.enable = true;
  programs.gnupg.agent.enable = true;
  programs.bash = {
    enableCompletion = true;
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
}
