# nixos-plasma

A minimal-but-real NixOS desktop flake for KDE Plasma 6: SDDM (Wayland) login,
a lightly trimmed default app set, PipeWire audio, and a deliberately small
home-manager config — Plasma manages its own settings well, so the flake stays
out of its way.

## Requirements

- A UEFI machine (or VM) with NixOS installed — the
  [minimal ISO](https://nixos.org/download/) is enough
- Flakes enabled during install: `nix --experimental-features 'nix-command flakes' ...`
  (the config itself enables them permanently)

## Install

```sh
git clone <this template> /etc/nixos-plasma && cd /etc/nixos-plasma

# 1. Replace the stub hardware config with the one for THIS machine
sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix

# 2. Rename the user and host (see below)

# 3. Build and switch
sudo nixos-rebuild switch --flake .#desktop
```

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
  configuration.nix                boot, network, SDDM + Plasma 6, audio, fonts, user
  hardware-configuration.nix       STUB — replace via nixos-generate-config
home/user.nix                      user packages + git identity
```

## Notes

- Want declarative Plasma settings (panels, shortcuts, theme)? Add
  [plasma-manager](https://github.com/nix-community/plasma-manager) as a flake
  input later — this template intentionally leaves Plasma stock.
- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.

## CI

The shipped workflow (`.github/workflows/ci.yml`) evaluates the flake with
`nix flake check --no-build` on every push.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series.
Siblings: `nixos-{hyprland,gnome,plasma}`.
