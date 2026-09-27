# nixos-gnome

A minimal-but-real NixOS desktop flake for GNOME: GDM login, a trimmed default app
set, PipeWire audio, and a home-manager config that applies clean dconf settings
and two Shell extensions (AppIndicator, Dash to Dock) declaratively.

## Requirements

- A UEFI machine (or VM) with NixOS installed — the
  [minimal ISO](https://nixos.org/download/) is enough
- Flakes enabled during install: `nix --experimental-features 'nix-command flakes' ...`
  (the config itself enables them permanently)

## Install

```sh
git clone <this template> /etc/nixos-gnome && cd /etc/nixos-gnome

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
  configuration.nix                boot, network, GDM + GNOME, excluded apps, audio, user
  hardware-configuration.nix       STUB — replace via nixos-generate-config
home/user.nix                      dconf settings + declarative Shell extensions
```

## Notes

- Extensions: the package (`gnomeExtensions.<name>`) makes an extension available,
  the `enabled-extensions` dconf key turns it on. Both live in `home/user.nix`;
  find more at [search.nixos.org](https://search.nixos.org/packages?query=gnomeExtensions).
- Discover dconf keys for more settings with `dconf watch /` while changing
  things in the GNOME Settings app.
- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.

## CI

The shipped workflow (`.github/workflows/ci.yml`) evaluates the flake with
`nix flake check --no-build` on every push.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series.
Siblings: `nixos-{hyprland,gnome,plasma}`.
