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

  # KDE Plasma 6 on Wayland via SDDM.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Trim a few default Plasma apps; add back what you miss.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa # music player
    khelpcenter
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

  environment.systemPackages = with pkgs; [ git vim wget ];
}
