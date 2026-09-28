# nixos-plasma

A minimal-but-real NixOS 26.05 desktop flake for KDE Plasma 6: SDDM (Wayland) login,
a lightly trimmed default app set, PipeWire audio, and a deliberately small
home-manager config — Plasma manages its own settings well, so the flake stays
out of its way.

## Run

On a UEFI machine (or VM) running NixOS — the [minimal ISO](https://nixos.org/download/)
install is enough:

    sudo nix-shell -p git --run 'git clone https://github.com/devai-io/devai_boilerplates.git /etc/devai_boilerplates'
    cd /etc/devai_boilerplates/nixos-plasma
    # 1. Replace the stub hardware config with the one for THIS machine
    sudo nixos-generate-config --show-hardware-config | sudo tee hosts/desktop/hardware-configuration.nix >/dev/null
    # 2. Rename the user and host (below), then build and switch
    sudo nixos-rebuild switch --flake .#desktop

Reboot into SDDM and log in as `user` with the initial password `changeme` — run
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

- Want declarative Plasma settings (panels, shortcuts, theme)? Add
  [plasma-manager](https://github.com/nix-community/plasma-manager) as a flake
  input later — this template intentionally leaves Plasma stock.
- `flake.lock` pins nixpkgs and home-manager; `nix flake update` moves both to the
  latest 26.05 commits. For the next release, change `nixos-26.05` and
  `release-26.05` in `flake.nix` together.
- `system.stateVersion` / `home.stateVersion` mark the release you first installed;
  leave them alone when upgrading.

## Layout

    flake.nix                              nixpkgs nixos-26.05 + home-manager release-26.05
    flake.lock                             the exact commits of both
    hosts/desktop/configuration.nix        boot, network, SDDM + Plasma 6, excluded apps, audio, fonts, user
    hosts/desktop/hardware-configuration.nix   STUB — replace via nixos-generate-config
    home/user.nix                          user packages + git identity

## Deploy

`sudo nixos-rebuild switch --flake .#desktop` is the deploy: run it after every
change. Make this folder the root of your own repo (`cp -r devai_boilerplates/nixos-plasma my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) evaluates the whole system on every push and pull
request — `nix flake check` plus the system derivation, nothing is built — inside
the official `nixos/nix` image.

---
Part of [devai.io](https://devai.io) — the NixOS desktop series:
[`nixos-hyprland`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-hyprland),
[`nixos-gnome`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-gnome),
[`nixos-plasma`](https://github.com/devai-io/devai_boilerplates/tree/main/nixos-plasma).
