# nixos-gnome

A minimal-but-real NixOS 26.05 desktop flake for GNOME: GDM login, a trimmed default
app set, PipeWire audio, and a home-manager config that applies clean dconf settings
and two Shell extensions (AppIndicator, Dash to Dock) declaratively.

## Run

On a UEFI machine (or VM) running NixOS — the [minimal ISO](https://nixos.org/download/)
install is enough:

    sudo nix-shell -p git --run 'git clone https://github.com/devai-io/devai_boilerplates.git /etc/devai_boilerplates'
    cd /etc/devai_boilerplates/nixos-gnome
    # 1. Replace the stub hardware config with the one for THIS machine
    sudo nixos-generate-config --show-hardware-config | sudo tee hosts/desktop/hardware-configuration.nix >/dev/null
    # 2. Rename the user and host (below), then build and switch
    sudo nixos-rebuild switch --flake .#desktop

Reboot into GDM and log in as `user` with the initial password `changeme` — run
`passwd` right away. `nixos-rebuild` turns flakes on for its own run; the config
enables them permanently.

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

- Extensions: the package (`gnomeExtensions.<name>`) makes an extension available,
  the `enabled-extensions` dconf key turns it on. Both live in `home/user.nix`;
  find more at [search.nixos.org](https://search.nixos.org/packages?query=gnomeExtensions).
- Discover dconf keys for more settings with `dconf watch /` while changing
  things in the GNOME Settings app.
- `flake.lock` pins nixpkgs and home-manager; `nix flake update` moves both to the
  latest 26.05 commits. For the next release, change `nixos-26.05` and
  `release-26.05` in `flake.nix` together.
- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.

## Layout

    flake.nix                              nixpkgs nixos-26.05 + home-manager release-26.05
    flake.lock                             the exact commits of both
    hosts/desktop/configuration.nix        boot, network, GDM + GNOME, excluded apps, audio, user
    hosts/desktop/hardware-configuration.nix   STUB — replace via nixos-generate-config
    home/user.nix                          dconf settings + declarative Shell extensions

## Deploy

`sudo nixos-rebuild switch --flake .#desktop` is the deploy: run it after every
change. Make this folder the root of your own repo (`cp -r devai_boilerplates/nixos-gnome my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) evaluates the whole system on every push and pull
request — `nix flake check` plus the system derivation, nothing is built — inside
the official `nixos/nix` image.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series:
[`nixos-hyprland`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-hyprland),
[`nixos-gnome`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-gnome),
[`nixos-plasma`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-plasma).
