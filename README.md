# mujō

Personal NixOS flake configuration.

## Hosts

- **main** — Primary desktop (AMD, Nvidia VR, dual monitor)

## Usage

```bash
nh os switch ~/nixconf/
```

## Fresh Install

> Run from a **NixOS live USB**, not from the system being replaced.

```bash
# 1. Partition & format
sudo nix run github:nix-community/disko -- --mode disko ./nixos/hosts/main/disko.nix

# 2. Install
sudo nixos-install --flake .#main --root /mnt

# 3. Reboot, then apply
nh os switch ~/nixconf/
```

> Reinstall over existing: use `nixos-rebuild switch` (not `nixos-install`) to keep persist data.
