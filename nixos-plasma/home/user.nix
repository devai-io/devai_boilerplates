{ pkgs, ... }:

{
  home.username = "user"; # rename me
  home.homeDirectory = "/home/user";

  # Release of first install; do not bump when upgrading.
  home.stateVersion = "26.05";

  # Plasma keeps its own settings in ~/.config (System Settings writes them),
  # so the home side stays minimal: user packages and git identity.
  home.packages = with pkgs; [ firefox ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "user";
      email = "user@example.com";
    };
  };
}
