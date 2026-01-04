# Security Architecture

This document describes the security model for running AI agents in isolated containers
with podman-in-podman support.

## Threat Model

The agent container runs as a dedicated, low-privilege host user (`yolo`) with:
- No secrets or SSH access
- No cloud credentials
- No access to developer home directories

**Compromise of the agent may destroy the dev machine, but cannot compromise developer identity, laptops, or infrastructure.**

### What we're protecting:
1. **Developer identity** - SSH keys, GPG keys, API tokens, browser sessions
2. **Infrastructure access** - Cloud credentials, production systems
3. **Internal network** - Other machines, databases, services on RFC1918 subnets
4. **Laptop** - Files outside the designated workspace

### What we accept (risk envelope):
- Agent has full access to `/workspace` (its working directory)
- Agent can read mounted source directories (read-only)
- Agent can create and run nested containers
- Agent can access the public internet
- Agent could destroy/DoS the dev machine
- Kernel 0-day could compromise the `yolo` user (but not developer credentials)

### Risk Summary Table

| Impact | Outcome |
|--------|---------|
| Agent compromise | Dev machine destruction/DoS possible |
| Kernel escape | Only compromises dedicated `yolo` user |
| Developer identity | **Protected** |
| Infrastructure/prod | **Protected** |
| Laptop credentials | **Protected** |
| Internal network | **Protected** (RFC1918 blocked) |

## Architecture

```
Host User (athena)
    │
    └── Invokes run.sh
            │
            └── sudo -u yolo podman run ...
                    │
                    └── Container runs as root (in yolo's user namespace)
                            │
                            ├── /workspace - read/write workspace
                            ├── /source/* - read-only source mounts
                            └── podman - can create nested containers
```

## Security Layers

### 1. User Isolation (yolo user)

The container runs as a dedicated `yolo` user, not as your primary user account.

**Why this matters:**
- If container escapes, attacker lands as `yolo`, not `athena`
- `yolo` has no access to `athena`'s home directory, SSH keys, or credentials
- `yolo` is a service account with minimal privileges

**Setup:**
```bash
sudo useradd -r -m -s /usr/sbin/nologin yolo
sudo usermod --add-subuids 200000-265535 --add-subgids 200000-265535 yolo
sudo loginctl enable-linger yolo
```

### 2. Network Isolation (Firewall Rules)

The `yolo` user is blocked from accessing internal network subnets.

**Why this matters:**
- Prevents agent from accessing internal services (databases, APIs, etc.)
- Blocks access to other machines on your network
- Agent can still access public internet for legitimate tasks

**Blocked subnets (RFC1918 + link-local):**
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`
- `169.254.0.0/16`

**Setup with iptables:**
```bash
YOLO_UID=$(id -u yolo)
sudo iptables -A OUTPUT -m owner --uid-owner $YOLO_UID -d 10.0.0.0/8 -j REJECT
sudo iptables -A OUTPUT -m owner --uid-owner $YOLO_UID -d 172.16.0.0/12 -j REJECT
sudo iptables -A OUTPUT -m owner --uid-owner $YOLO_UID -d 192.168.0.0/16 -j REJECT
sudo iptables -A OUTPUT -m owner --uid-owner $YOLO_UID -d 169.254.0.0/16 -j REJECT
```

**Setup with nftables (modern Fedora):**
```nft
table inet yolo_restrict {
    chain output {
        type filter hook output priority 0; policy accept;
        meta skuid yolo ip daddr 10.0.0.0/8 reject
        meta skuid yolo ip daddr 172.16.0.0/12 reject
        meta skuid yolo ip daddr 192.168.0.0/16 reject
        meta skuid yolo ip daddr 169.254.0.0/16 reject
    }
}
```

### 3. Capability Restriction (No --privileged)

The container runs with minimal Linux capabilities, not `--privileged`.

**Capabilities granted:**
| Capability | Purpose |
|------------|---------|
| `CAP_SETUID` | UID mapping for nested containers |
| `CAP_SETGID` | GID mapping for nested containers |
| `CAP_SYS_ADMIN` | Mount proc/sysfs in nested containers |

**Why not --privileged:**
- `--privileged` grants ALL capabilities and disables security features
- Our approach grants only what's needed for podman-in-podman
- Still restricted by user namespace (rootless podman)

### 4. Device Access

Only `/dev/fuse` is exposed, required for fuse-overlayfs storage in nested containers.

**Why /dev/fuse:**
- Native kernel overlay doesn't work in nested container contexts
- fuse-overlayfs provides userspace overlay filesystem
- Limited attack surface compared to full device access

### 5. Rootless Podman

Even though the container runs as "root" inside, it's actually rootless:

```
Container "root" (UID 0)
    ↓ mapped via user namespace
yolo's subordinate UID range (200000-265535)
    ↓ mapped via rootless podman
Host UID 200000+ (unprivileged)
```

**Key insight:** The container's root is NOT host root. It's an unprivileged UID
in the host's user namespace. This is fundamental Linux user namespace security.

## What Can Go Wrong

### Kernel 0-days
A kernel vulnerability in user namespaces, overlayfs, or fuse could allow escape.
This is the residual risk we accept. Mitigations:
- Keep kernel updated
- The yolo user + firewall rules limit blast radius

### Container Runtime Bugs
Bugs in podman/crun could allow escape. Mitigations:
- Keep podman updated
- User namespace provides defense in depth

### Misconfiguration
Mounting sensitive paths defeats the isolation. Never mount:
- `~/.ssh`
- `~/.aws`
- `~/.config` (contains tokens)
- `/etc` from host

## Future Enhancements

### Out-of-Band Sudo Validation
Currently, requiring `sudo podman` inside the container would be window dressing
since the container runs as root. A future enhancement could add out-of-band
validation (push notification, separate approval channel) before allowing
nested container creation.

### Seccomp Profiles
Custom seccomp profiles could further restrict syscalls available to the container.

### Read-Only Root Filesystem
Making the container's root filesystem read-only with explicit tmpfs for /tmp, /run.

## Quick Reference

### Recommended Setup Checklist

Run the automated setup script:
```bash
sudo ./setup-host.sh
```

Or manually:
- [ ] Create yolo user with subuid/subgid
- [ ] Enable linger for yolo
- [ ] Add firewall rules for yolo
- [ ] Verify podman works as yolo: `sudo -u yolo podman info`

### Container Flags Used
```bash
--user root                    # Run as root in container (maps to yolo's namespace)
--security-opt label=disable   # Disable SELinux (for nested containers)
--cap-add=CAP_SETUID          # UID mapping
--cap-add=CAP_SETGID          # GID mapping
--cap-add=CAP_SYS_ADMIN       # Mount operations
--device /dev/fuse            # fuse-overlayfs for nested storage
```

### Fallback Mode
If yolo user doesn't exist, run.sh falls back to running as current user.
This is less secure (escape lands as your user) but functional for development.
