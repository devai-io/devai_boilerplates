# nixos-hyprland

A minimal-but-real NixOS desktop flake for [Hyprland](https://hypr.land): greetd +
tuigreet login, PipeWire audio, portals/polkit/keyring wired for Wayland, and a
home-manager config with sensible keybinds, waybar, kitty, wofi and mako.

## Requirements

- A UEFI machine (or VM) with NixOS installed — the
  [minimal ISO](https://nixos.org/download/) is enough
- Flakes enabled during install: `nix --experimental-features 'nix-command flakes' ...`
  (the config itself enables them permanently)

## Install

```sh
git clone <this template> /etc/nixos-hyprland && cd /etc/nixos-hyprland

# 1. Replace the stub hardware config with the one for THIS machine
sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix

# 2. Rename the user and host (see below)

# 3. Build and switch
sudo nixos-rebuild switch --flake .#desktop
```

Log in via tuigreet; it starts Hyprland directly. First things to try:
`Super+Return` (terminal), `Super+Space` (launcher), `Super+1..9` (workspaces),
`Super+Q` (close), `Print` (region screenshot to clipboard).

## Renaming user and host

The placeholders are `user` and `desktop`. Change them in three places:

- `flake.nix` — `home-manager.users.user` and (if you like) the
  `nixosConfigurations.desktop` attribute name
- `hosts/desktop/configuration.nix` — `users.users.user` and `networking.hostName`
- `home/user.nix` — `home.username`, `home.homeDirectory`, git identity

The initial password is `changeme` — run `passwd` after first login.

## Layout

```
flake.nix                          nixpkgs (unstable) + home-manager
hosts/desktop/
  configuration.nix                boot, network, audio, greetd, Hyprland, fonts, user
  hardware-configuration.nix       STUB — replace via nixos-generate-config
home/user.nix                      Hyprland keybinds, waybar, kitty, wofi, mako, git
```

## Notes

- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.
- Hyprland comes from nixpkgs (binary-cached), not the upstream flake — updates
  arrive with `nix flake update`.

## CI

The shipped workflow (`.github/workflows/ci.yml`) evaluates the flake with
`nix flake check --no-build` on every push.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series.
Siblings: `nixos-{hyprland,gnome,plasma}`.
