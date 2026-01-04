# NixOS Reproducible Setup

This document describes how to reproduce the agent sandbox security configuration
on NixOS for a fully declarative, reproducible setup.

## Overview

The setup requires:
1. Dedicated `yolo` user with subuid/subgid ranges
2. Rootless podman configuration
3. Firewall rules blocking RFC1918 for yolo
4. Required kernel features

## NixOS Configuration

### 1. User Configuration

```nix
# /etc/nixos/configuration.nix or flake module

{ config, pkgs, ... }:

{
  # Create yolo user for isolated container execution
  users.users.yolo = {
    isSystemUser = true;
    group = "yolo";
    home = "/var/lib/yolo";
    createHome = true;
    shell = pkgs.shadow;  # nologin equivalent

    # Subuid/subgid ranges for rootless podman
    subUidRanges = [
      { startUid = 200000; count = 65536; }
    ];
    subGidRanges = [
      { startGid = 200000; count = 65536; }
    ];
  };

  users.groups.yolo = {};

  # Enable lingering for yolo (systemd user services without login)
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/yolo 0644 root root -"
  ];
}
```

### 2. Podman Configuration

```nix
{
  # Enable podman
  virtualisation.podman = {
    enable = true;

    # Required for rootless podman
    dockerCompat = false;  # Optional: docker CLI compatibility

    # Default OCI runtime
    defaultNetwork.settings.dns_enabled = true;
  };

  # Enable required kernel features
  boot.kernelModules = [ "fuse" "overlay" ];

  # Allow unprivileged user namespaces (required for rootless containers)
  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
  };
}
```

### 3. Firewall Rules (nftables)

```nix
{
  # Use nftables (modern firewall)
  networking.nftables.enable = true;

  networking.nftables.tables = {
    yolo_restrict = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;

          # Block RFC1918 private subnets for yolo user
          meta skuid yolo ip daddr 10.0.0.0/8 reject
          meta skuid yolo ip daddr 172.16.0.0/12 reject
          meta skuid yolo ip daddr 192.168.0.0/16 reject
          meta skuid yolo ip daddr 169.254.0.0/16 reject
        }
      '';
    };
  };
}
```

### 4. Storage Configuration

```nix
{
  # Ensure /var/lib/yolo has correct permissions for podman storage
  systemd.tmpfiles.rules = [
    "d /var/lib/yolo/.local 0700 yolo yolo -"
    "d /var/lib/yolo/.local/share 0700 yolo yolo -"
    "d /var/lib/yolo/.local/share/containers 0700 yolo yolo -"
  ];
}
```

## Complete Module

Here's a complete NixOS module you can import:

```nix
# agent-sandbox.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agentSandbox;
in {
  options.services.agentSandbox = {
    enable = mkEnableOption "Agent sandbox isolated execution environment";

    user = mkOption {
      type = types.str;
      default = "yolo";
      description = "User for isolated container execution";
    };

    subuidStart = mkOption {
      type = types.int;
      default = 200000;
      description = "Starting UID for subuid range";
    };

    subuidCount = mkOption {
      type = types.int;
      default = 65536;
      description = "Number of subuids to allocate";
    };
  };

  config = mkIf cfg.enable {
    # User setup
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = "/var/lib/${cfg.user}";
      createHome = true;
      shell = pkgs.shadow;
      subUidRanges = [{ startUid = cfg.subuidStart; count = cfg.subuidCount; }];
      subGidRanges = [{ startGid = cfg.subuidStart; count = cfg.subuidCount; }];
    };

    users.groups.${cfg.user} = {};

    # Podman
    virtualisation.podman.enable = true;

    # Kernel features
    boot.kernelModules = [ "fuse" "overlay" ];
    boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;

    # Firewall rules
    networking.nftables.enable = true;
    networking.nftables.tables.agent_sandbox_restrict = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;
          meta skuid ${cfg.user} ip daddr 10.0.0.0/8 reject
          meta skuid ${cfg.user} ip daddr 172.16.0.0/12 reject
          meta skuid ${cfg.user} ip daddr 192.168.0.0/16 reject
          meta skuid ${cfg.user} ip daddr 169.254.0.0/16 reject
        }
      '';
    };

    # Lingering
    systemd.tmpfiles.rules = [
      "f /var/lib/systemd/linger/${cfg.user} 0644 root root -"
      "d /var/lib/${cfg.user}/.local 0700 ${cfg.user} ${cfg.user} -"
      "d /var/lib/${cfg.user}/.local/share 0700 ${cfg.user} ${cfg.user} -"
      "d /var/lib/${cfg.user}/.local/share/containers 0700 ${cfg.user} ${cfg.user} -"
    ];
  };
}
```

### Usage

```nix
# configuration.nix
{ ... }:

{
  imports = [ ./agent-sandbox.nix ];

  services.agentSandbox = {
    enable = true;
    user = "yolo";  # or customize
  };
}
```

## Verification

After applying the configuration:

```bash
# Check user exists with correct subuid/subgid
cat /etc/subuid | grep yolo
cat /etc/subgid | grep yolo

# Check podman works as yolo
sudo -u yolo podman info

# Check firewall rules
sudo nft list table inet agent_sandbox_restrict

# Check lingering enabled
ls -la /var/lib/systemd/linger/
```

## Flake Example

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.agentSandbox = import ./agent-sandbox.nix;

    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.agentSandbox
        ({ ... }: {
          services.agentSandbox.enable = true;
        })
      ];
    };
  };
}
```

## Differences from Fedora Setup

| Aspect | Fedora | NixOS |
|--------|--------|-------|
| User creation | `useradd` | Declarative in configuration.nix |
| Subuid/subgid | `/etc/subuid`, `/etc/subgid` | `users.users.<name>.subUidRanges` |
| Firewall | iptables/nftables manual | Declarative nftables tables |
| Lingering | `loginctl enable-linger` | systemd.tmpfiles.rules |
| Persistence | Manual persistence | Automatic with NixOS |

## Troubleshooting

### Podman fails with permission errors
Ensure kernel.unprivileged_userns_clone = 1 is set.

### Firewall rules not applying
Check `sudo nft list ruleset` and ensure the table is loaded.

### Subuid/subgid not working
After changing user configuration, may need `nixos-rebuild switch` and
potentially a reboot for podman to pick up new ranges.
