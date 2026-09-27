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

  # Audio: PipeWire with ALSA and PulseAudio compatibility.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Hyprland from nixpkgs (always binary-cached, no extra flake input).
  programs.hyprland.enable = true;

  # greetd + tuigreet: minimal TUI greeter straight into Hyprland.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd start-hyprland";
      user = "greeter";
    };
  };

  # Electron/Chromium apps run native Wayland.
  environment.variables.NIXOS_OZONE_WL = "1";

  # Wayland plumbing: polkit for privilege prompts, keyring for secrets,
  # the GTK portal for file choosers (programs.hyprland already wires up
  # xdg-desktop-portal-hyprland for screenshare).
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Wayland-only setup: no X server; libinput handles input devices.
  services.libinput.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  users.users.user = { # rename me (also in flake.nix and home/user.nix)
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    initialPassword = "changeme"; # change with `passwd` after first login
  };

  environment.systemPackages = with pkgs; [ git vim wget ];
}
