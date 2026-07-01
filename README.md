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
└── wrappedPrograms/       # Wrapped programs (git, niri, mangowc, neovim, etc.)
```

## Hosts

- **main** — Primary desktop (AMD, Nvidia VR, dual monitor)

## Features

Includes: niri/mangowc WM, noctalia shell, neovim, git/jj, SearXNG, Obsidian, Steam, Discord, Telegram, GIMP, Zen browser, gaming/VR, podman/libvirt, and more.

## Usage

```bash
nh os switch ~/nixconf/
```
