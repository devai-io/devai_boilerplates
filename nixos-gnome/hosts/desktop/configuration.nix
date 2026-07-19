{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Release of first install; used for stateful data migrations.
  # Do not bump when upgrading nixpkgs.
  system.stateVersion = "26.05";

  # Boot (UEFI).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "desktop"; # rename me
  networking.networkmanager.enable = true;

  time.timeZone = "UTC"; # e.g. "Europe/Berlin"
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  # GNOME on Wayland via GDM.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Trim the default GNOME app set; add back what you miss.
  environment.gnome.excludePackages = with pkgs; [
    epiphany # browser
    geary # email
    gnome-maps
    gnome-music
    gnome-tour
    simple-scan
    totem # video player
  ];

  # Audio: PipeWire with ALSA and PulseAudio compatibility.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  users.users.user = { # rename me (also in flake.nix and home/user.nix)
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme"; # change with `passwd` after first login
  };

  environment.systemPackages = with pkgs; [ git vim wget gnome-tweaks ];
}
