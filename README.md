# nixconf

Personal NixOS flake configuration.

## Structure

```
├── flake.nix              # Flake entry point, auto-imports all .nix files
├── parts.nix              # flake-parts config
├── theme.nix              # Color theme (Gruvbox-inspired)
├── nixos/
│   ├── base/              # Base modules (user, locale, keyboard, persistance)
│   ├── extra/             # Third-party integrations (hjem, impermanence)
│   ├── features/          # Feature modules (desktop, gaming, flatpak, etc.)
│   └── hosts/             # Host-specific configs (main, mini)
└── wrappedPrograms/       # Wrapped programs (git, niri, neovim, etc.)
```

## Hosts

- **main** — Primary desktop (AMD, Nvidia VR, dual monitor)

## Features

Includes: niri WM, noctalia shell, neovim, git/jj, SearXNG, Obsidian, Steam, Discord, Telegram, GIMP, Zen browser, gaming/VR, podman/libvirt, and more.

## Usage

```bash
nh os switch ~/nixconf/
```

## Fresh Install

> Run these steps from a **NixOS live USB** (or any other booted disk), not from the system being replaced.

```bash
# 1. Partition & format disks
sudo nix run github:nix-community/disko -- --mode disko ./nixos/hosts/main/disko.nix

# 2. Mount and install
sudo nixos-install --flake .#main --root /mnt

# 3. Reboot, then apply updates
nh os switch ~/nixconf/
```

> If reinstalling over an existing setup, run `sudo nixos-rebuild switch --flake .#main --root /mnt` instead of `nixos-install` to keep existing home data on persist partitions.
