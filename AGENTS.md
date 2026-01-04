# AGENTS.md

Instructions for AI coding agents working on this project.

## Project Goal

This project provides a **self-contained development container for AI agent workflows**. The container includes:

- Multiple AI coding agents (Claude Code, Codex CLI, Gemini CLI)
- Multi-agent orchestration tools (Gastown, NTM)
- Agent coordination infrastructure (Agent Mail, CASS, memory systems)
- Podman-in-podman support for nested container workflows

The key design principle is **read-only source, writable workspace**: source code is mounted read-only at `/source`, and agents clone into `/workspace` where they can work independently without corrupting the original.

We vendor the flywheel ecosystem tools as git subtrees so we can:
1. Move fast without waiting for upstream releases
2. Make local modifications when needed
3. Control exactly which versions are deployed
4. Contribute fixes back upstream when appropriate

---

## Commit Instructions

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `build` | Build system or dependencies |
| `ci` | CI configuration |
| `chore` | Other changes (maintenance, tooling) |

### Scopes

| Scope | Description |
|-------|-------------|
| `docker` | Dockerfile, container config |
| `vendor` | Vendored subtree tools |
| `shell` | Shell configuration, zshrc |
| `docs` | Documentation |
| `ntm` | NTM subtree |
| `gt` | Gastown subtree |
| `ubs` | Ultimate Bug Scanner subtree |
| `cass` | CASS/coding_agent_session_search subtree |
| `bv` | Beads Viewer subtree |
| `mail` | MCP Agent Mail subtree |
| `cm` | CASS Memory System subtree |
| `caam` | Coding Agent Account Manager subtree |
| `slb` | Simultaneous Launch Button subtree |

### Examples

```bash
# New feature
git commit -m "feat(docker): add GPU support for local inference"

# Bug fix in vendored tool
git commit -m "fix(ntm): correct tmux pane naming on macOS"

# Documentation update
git commit -m "docs: add troubleshooting section for nested containers"

# Updating a subtree
git commit -m "build(vendor): update ntm to v1.4.0"
```

---

## Subtree Management

### Current Subtrees

| Prefix | Repository | Version |
|--------|------------|---------|
| `vendor/ntm` | Dicklesworthstone/ntm | v1.3.0 |
| `vendor/mcp_agent_mail` | Dicklesworthstone/mcp_agent_mail | v0.1.3 |
| `vendor/ultimate_bug_scanner` | Dicklesworthstone/ultimate_bug_scanner | v5.0.3 |
| `vendor/beads_viewer` | Dicklesworthstone/beads_viewer | v0.11.3 |
| `vendor/coding_agent_session_search` | Dicklesworthstone/coding_agent_session_search | v0.1.49 |
| `vendor/cass_memory_system` | Dicklesworthstone/cass_memory_system | v0.2.1 |
| `vendor/coding_agent_account_manager` | Dicklesworthstone/coding_agent_account_manager | v0.1.0 |
| `vendor/simultaneous_launch_button` | Dicklesworthstone/simultaneous_launch_button | v0.1.0 |
| `vendor/gastown` | steveyegge/gastown | main |

### Updating a Subtree

To pull updates from upstream:

```bash
# Update to a specific release tag
git subtree pull --prefix=vendor/ntm \
    https://github.com/Dicklesworthstone/ntm.git v1.4.0 --squash

# Update to latest main (use sparingly)
git subtree pull --prefix=vendor/gastown \
    https://github.com/steveyegge/gastown.git main --squash
```

After updating, rebuild the container to incorporate changes:

```bash
./run.sh --build
```

### Dockerfile Alignment

When updating subtrees, verify the Dockerfile build stage still aligns with upstream:

1. Check if the vendor tool's Dockerfile or build approach changed
2. Check if `go.mod` / `Cargo.toml` / `pyproject.toml` version requirements changed
3. Check if build flags or dependencies changed (e.g., CGO requirements)

If upstream changed their build approach, update the corresponding builder stage in our Dockerfile. The multi-stage build uses:

| Builder Stage | Base Image | Tools |
|---------------|-----------|-------|
| `go-builder` | golang:1.25-alpine | ntm, bv, gt, caam, slb |
| `rust-builder` | rust:slim + nightly | cass |
| `node-builder` | oven/bun:latest | cm (cass_memory_system) |
| `python-builder` | python:3.14-slim | mcp_agent_mail |

Build with parallel stages: `podman build --jobs=0 -t agent-dev .`

### Making Local Modifications

You can edit files in `vendor/` directly. Commit changes normally:

```bash
# Edit the file
vim vendor/ntm/cmd/spawn.go

# Commit your change
git add vendor/ntm/cmd/spawn.go
git commit -m "fix(ntm): handle edge case in spawn command"
```

### Contributing Upstream

If you make improvements that should go upstream:

1. Fork the upstream repo
2. Create a branch with your changes
3. Open a PR against upstream
4. Once merged, update the subtree to pull the official version

### Adding a New Subtree

```bash
git subtree add --prefix=vendor/<name> \
    https://github.com/<owner>/<repo>.git <tag-or-branch> --squash
```

Then update the Dockerfile to build/install the new tool.

---

## Build Commands

Use the Makefile for common operations:

```bash
# Build with parallel stages (recommended)
make build

# Build and run
make run-build

# Build without cache (full rebuild)
make build-nocache

# Show all available targets
make help
```

Or use the scripts directly:

```bash
# Build the container with parallel stages
podman build --jobs=0 -t agent-dev .

# Build and run
./run.sh --build

# Run with source mounted
./run.sh -s ~/projects/myapp

# Reset workspace (destroys agent work)
./run.sh --reset
```

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build with parallel stages (recommended) |
| `make build-nocache` | Full rebuild without cache |
| `make run` | Run the container |
| `make run-build` | Build and run |
| `make clean` | Remove build cache |
| `make reset` | Remove workspace volume |
| `make help` | Show all targets |

---

## Tool Binaries

After build, these binaries are available in the container:

| Binary | Tool | Purpose |
|--------|------|---------|
| `ntm` | Named Tmux Manager | Spawn/manage agent sessions |
| `gt` | Gastown | Multi-agent orchestration |
| `bv` | Beads Viewer | Task management TUI |
| `cass` | Coding Agent Session Search | Search agent history |
| `cm` | CASS Memory System | Procedural agent memory |
| `caam` | Coding Agent Account Manager | Switch agent auth |
| `slb` | Simultaneous Launch Button | Two-person rule for dangerous commands |
| `ubs` | Ultimate Bug Scanner | Static analysis |
| `claude` | Claude Code | Anthropic's coding agent |
| `codex` | Codex CLI | OpenAI's coding agent |
| `gemini` | Gemini CLI | Google's coding agent |
