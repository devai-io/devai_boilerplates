# nixos-hyprland

A minimal-but-real NixOS 26.05 desktop flake for [Hyprland](https://hypr.land): greetd +
tuigreet login, PipeWire audio, portals/polkit/keyring wired for Wayland, and a
home-manager config with sensible keybinds, waybar, kitty, wofi and mako.

## Run

On a UEFI machine (or VM) running NixOS — the [minimal ISO](https://nixos.org/download/)
install is enough:

    sudo nix-shell -p git --run 'git clone https://git.devai.io/templates/nixos-hyprland.git /etc/nixos-hyprland'
    cd /etc/nixos-hyprland
    # 1. Replace the stub hardware config with the one for THIS machine
    sudo nixos-generate-config --show-hardware-config | sudo tee hosts/desktop/hardware-configuration.nix >/dev/null
    # 2. Rename the user and host (below), then build and switch
    sudo nixos-rebuild switch --flake .#desktop

Reboot and log in via tuigreet as `user` with the initial password `changeme` — run
`passwd` right away. tuigreet launches Hyprland via `start-hyprland`; first things to try:
`Super+Return` (terminal), `Super+Space` (launcher), `Super+1..9` (workspaces),
`Super+Q` (close), `Print` (region screenshot to clipboard).
`nixos-rebuild` turns flakes on for its own run; the config enables them permanently.

## How it works

`hosts/desktop/hardware-configuration.nix` is a **stub**: it only exists so the flake
evaluates out of the box and will not boot real hardware. Step 1 above replaces it
with the file generated for your disks and CPU — the one file that is yours, not the
template's.

The placeholders are `user` and `desktop`. Rename them in three places:

- `flake.nix` — `home-manager.users.user` and (if you like) the
  `nixosConfigurations.desktop` attribute name
- `hosts/desktop/configuration.nix` — `users.users.user` and `networking.hostName`
- `home/user.nix` — `home.username`, `home.homeDirectory`, git identity

Notes:

- Hyprland comes from nixpkgs (binary-cached), not the upstream flake — updates
  arrive with `nix flake update`. `programs.hyprland` installs it system-wide;
  home-manager only writes its config.
- `flake.lock` pins nixpkgs and home-manager; `nix flake update` moves both to the
  latest 26.05 commits. For the next release, change `nixos-26.05` and
  `release-26.05` in `flake.nix` together.
- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.

## Layout

    flake.nix                              nixpkgs nixos-26.05 + home-manager release-26.05
    flake.lock                             the exact commits of both
    hosts/desktop/configuration.nix        boot, network, audio, greetd, Hyprland, fonts, user
    hosts/desktop/hardware-configuration.nix   STUB — replace via nixos-generate-config
    home/user.nix                          Hyprland keybinds, waybar, kitty, wofi, mako, git

## Deploy

`sudo nixos-rebuild switch --flake .#desktop` is the deploy: run it after every
change. Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) evaluates the whole system on every push and pull
request — `nix flake check` plus the system derivation, nothing is built — inside
the official `nixos/nix` image.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series:
[`nixos-hyprland`](https://git.devai.io/templates/nixos-hyprland),
[`nixos-gnome`](https://git.devai.io/templates/nixos-gnome),
[`nixos-plasma`](https://git.devai.io/templates/nixos-plasma).
