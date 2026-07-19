{ pkgs, ... }:

{
  home.username = "user"; # rename me
  home.homeDirectory = "/home/user";

  # Release of first install; do not bump when upgrading.
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    firefox
    grim
    slurp # screenshots: grim (capture) + slurp (region select)
    wl-clipboard
    brightnessctl
    playerctl
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    # The system profile (programs.hyprland in configuration.nix) provides
    # Hyprland itself; home-manager only writes the config.
    package = null;
    portalPackage = null;

    # Classic hyprland.conf syntax (home-manager also offers "lua").
    configType = "hyprlang";

    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";

      # Any monitor without an explicit rule gets its preferred mode.
      monitor = ",preferred,auto,1";

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(7aa2f7ee)";
        "col.inactive_border" = "rgba(3b4261aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        dim_inactive = false;
      };

      animations = {
        enabled = true;
        animation = [
          "windows, 1, 3, default"
          "workspaces, 1, 3, default"
          "fade, 1, 3, default"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      bind = [
        # Apps
        "$mod, Return, exec, $terminal"
        "$mod, Space, exec, $menu"
        "$mod, B, exec, firefox"

        # Window management
        "$mod, Q, killactive,"
        "$mod, F, fullscreen,"
        "$mod, V, togglefloating,"
        "$mod, J, layoutmsg, togglesplit"
        "$mod SHIFT, E, exit,"

        # Focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Swap windows
        "$mod SHIFT, left, swapwindow, l"
        "$mod SHIFT, right, swapwindow, r"
        "$mod SHIFT, up, swapwindow, u"
        "$mod SHIFT, down, swapwindow, d"

        # Scratchpad
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Screenshots: region to clipboard / full screen to clipboard
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"
      ]
      # Workspaces: $mod+N switch, $mod+SHIFT+N move window (1..9).
      ++ builtins.concatLists (builtins.genList (i:
        let ws = toString (i + 1);
        in [
          "$mod, ${ws}, workspace, ${ws}"
          "$mod SHIFT, ${ws}, movetoworkspace, ${ws}"
        ]) 9);

      # Drag windows / resize with the mouse.
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Volume and brightness keys (repeat while held, work on lockscreen).
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioPlay, exec, playerctl play-pause"
      ];
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    settings = {
      background_opacity = "0.95";
      confirm_os_window_close = 0;
    };
  };

  programs.wofi = {
    enable = true;
    settings = {
      show = "drun";
      allow_images = true;
      insensitive = true;
      width = 480;
    };
  };

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 8;
      background-color = "#1a1b26";
      text-color = "#c0caf5";
      border-color = "#7aa2f7";
    };
  };

  programs.waybar = {
    enable = true;
    # Started by the hyprland-session.target home-manager sets up.
    systemd = {
      enable = true;
      targets = [ "hyprland-session.target" ];
    };

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [ "pulseaudio" "network" "battery" "clock" "tray" ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
      };
      "hyprland/window".max-length = 60;

      pulseaudio = {
        format = "vol {volume}%";
        format-muted = "muted";
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };
      network = {
        format-wifi = "{essid}";
        format-ethernet = "wired";
        format-disconnected = "offline";
      };
      battery = {
        format = "bat {capacity}%";
        states = {
          warning = 30;
          critical = 15;
        };
      };
      clock.format = "{:%a %d %b  %H:%M}";
      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 12px;
      }
      window#waybar {
        background: rgba(26, 27, 38, 0.9);
        color: #c0caf5;
      }
      #workspaces button {
        padding: 0 8px;
        color: #565f89;
        background: transparent;
        border: none;
        border-radius: 0;
      }
      #workspaces button.active {
        color: #7aa2f7;
      }
      #pulseaudio, #network, #battery, #clock, #tray {
        padding: 0 10px;
      }
      #battery.warning {
        color: #e0af68;
      }
      #battery.critical {
        color: #f7768e;
      }
    '';
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "user";
      email = "user@example.com";
    };
  };
}
