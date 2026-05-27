{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Bootloader - GRUB for dual boot with small EFI partition
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  networking.hostName = "desktop";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # AMD GPU support
  hardware.graphics.enable = true;

  # Enable niri
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  services.displayManager.sessionPackages = [ pkgs.niri-unstable ];

  # GDM 50 in nixos-unstable crashes its Wayland greeter on this AMD setup; use greetd instead.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };
  
  # Portal for screen sharing, file dialogs
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = [ "gnome" ];
  };
  services.dbus.packages = [ pkgs.nautilus ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Flatpak (used for Spotify so spicetify can patch a writable install)
  services.flatpak.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account.
  users.users.kamdyns = {
    isNormalUser = true;
    description = "Kamdyn Shaeffer";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Zsh
  programs.zsh.enable = true;
  users.users.kamdyns.shell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "24.11";
}
