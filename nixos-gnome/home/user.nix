{ pkgs, ... }:

{
  home.username = "user"; # rename me
  home.homeDirectory = "/home/user";

  # Release of first install; do not bump when upgrading.
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    firefox

    # GNOME Shell extensions: installing the package makes the extension
    # available; enabling happens in dconf below.
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
  ];

  # Declarative GNOME settings (what gnome-control-center / gnome-tweaks
  # would write). Discover keys with `dconf watch /` while clicking around.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
      clock-show-weekday = true;
      show-battery-percentage = true;
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      natural-scroll = true;
    };

    "org/gnome/mutter" = {
      edge-tiling = true;
      dynamic-workspaces = true;
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "dash-to-dock@micxgx.gmail.com"
      ];
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Settings.desktop"
      ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      dash-max-icon-size = 40;
      show-trash = false;
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "user";
      email = "user@example.com";
    };
  };
}
