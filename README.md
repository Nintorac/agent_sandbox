# Agent Development Container

A Fedora-based development container for AI agent workflows with podman-in-podman support. Inspired by [agent-flywheel.com](https://agent-flywheel.com).

## Features

- **AI Agent CLIs**: Claude Code, Codex CLI, Gemini CLI pre-installed
- **Multi-runtime**: Node.js 22, Bun, Rust, Python 3.12, Go 1.23
- **Podman-in-Podman**: Full nested container support for builds and tests
- **Agent Orchestration**: Gastown integration for multi-agent workflows
- **Modern Shell**: zsh + oh-my-zsh + Starship prompt + atuin history

## Quick Start

```bash
# Build the container
podman build -t agent-dev .

# Run with your project mounted
cd /path/to/your/project
./run.sh
```

Or use the run script with options:

```bash
# Build and run in one command
./run.sh --build

# Mount a specific project
./run.sh -s ~/projects/myapp

# Mount multiple projects
./run.sh -s ~/projects/frontend -s ~/projects/backend
```

## The Source/Workspace Workflow

This container implements a **read-only source, writable workspace** pattern designed for multi-agent development:

```
HOST                          CONTAINER
─────                         ─────────
~/projects/myapp/  ──mount──► /source/myapp/     (read-only)
                                   │
                                   │ git clone
                                   ▼
                              /workspace/gt/rigs/myapp/  (agent workspace)
```

### Why This Pattern?

1. **Source Protection**: Your local repo at `/source` is mounted read-only. Agents cannot accidentally corrupt your working copy.

2. **Isolated Workspaces**: Each agent/team clones from `/source` into `/workspace`. Multiple agents can work on different branches simultaneously without conflicts.

3. **Persistent State**: The `/workspace` volume persists between container runs. Agent work, Gastown state, and Beads history survive restarts.

4. **Clean Merges**: When work is complete, the Refinery agent handles merging changes. You pull the results back to your host repo.

## Typical Session

```bash
# 1. Start the container from your project directory
cd ~/projects/myapp
./run.sh

# 2. Inside container: Initialize a rig for your project
gt rig add myapp /source/myapp

# 3. Spawn agents to work on issues
gt convoy create "Fix auth bugs" --issues=42,43,44
gt sling myapp --polecats=3

# 4. Agents work in /workspace/gt/rigs/myapp/
#    Each Polecat gets its own worktree

# 5. When done, Refinery merges to a review branch
#    You can then pull/review on your host
```

## Multi-Project Setup

Mount multiple projects under `/source`:

```bash
./run.sh -s ~/projects/frontend -s ~/projects/backend -s ~/projects/shared-lib
```

Or manually:

```bash
podman run -it --rm \
    --privileged \
    -v ~/projects/frontend:/source/frontend:ro,z \
    -v ~/projects/backend:/source/backend:ro,z \
    -v ~/projects/shared-lib:/source/shared-lib:ro,z \
    -v agent-workspace:/workspace \
    agent-dev:latest
```

Then add each as a rig:

```bash
gt rig add frontend /source/frontend
gt rig add backend /source/backend
```

The Mayor can now coordinate work across all projects.

## Nested Containers

This container supports running podman inside podman for:
- Building container images as part of agent workflows
- Running test containers
- Deploying to local k8s/kind clusters

```bash
# Inside the container
podman run --rm alpine echo "nested containers work!"

# Build an image
podman build -t myapp .
```

## Included Tools

### AI Agent CLIs
| Tool | Command | Description |
|------|---------|-------------|
| Claude Code | `claude` | Anthropic's agentic coding CLI |
| Codex CLI | `codex` | OpenAI's coding assistant |
| Gemini CLI | `gemini` | Google's Gemini in terminal |

### CLI Utilities
| Tool | Command | Description |
|------|---------|-------------|
| lsd | `ls`, `ll` | Modern ls with icons |
| bat | `cat` | Syntax-highlighted cat |
| ripgrep | `rg` | Fast recursive search |
| fd | `fd` | Fast file finder |
| fzf | `fzf` | Fuzzy finder |
| zoxide | `z` | Smarter cd |
| atuin | `Ctrl+R` | Searchable shell history |
| starship | (prompt) | Cross-shell prompt |

### Language Runtimes
| Runtime | Version | Command |
|---------|---------|---------|
| Node.js | 22 LTS | `node`, `npm` |
| Bun | latest | `bun` |
| Rust | stable | `cargo`, `rustc` |
| Python | 3.12 | `python`, `pip` |
| Go | 1.23 | `go` |

## Gastown Integration

[Gastown](https://github.com/steveyegge/gastown) is Steve Yegge's multi-agent orchestrator for Claude Code.

### Key Concepts

- **Convoys**: Bundle related tasks for coordinated execution
- **Beads**: Git-backed issue tracking (work survives agent crashes)
- **Molecules**: Executable workflows (formulas → protomolecules → mols)

### Agent Roles

| Role | Scope | Function |
|------|-------|----------|
| Mayor | Town-wide | Cross-project coordination via natural language |
| Deacon | Town-wide | Daemon, lifecycle management |
| Witness | Per-project | Monitor workers, detect stalls |
| Refinery | Per-project | Merge queues, code review |
| Polecat | Per-task | Execute work, report issues |

### Directory Structure

```
/workspace/gt/                    # Gastown town
├── .beads/                       # Formulas, molecules, work state
├── .gtconfig                     # Town configuration
└── rigs/                         # Project workspaces
    ├── frontend/                 # Cloned from /source/frontend
    └── backend/                  # Cloned from /source/backend
```

## Vendored Flywheel Tools

We maintain the [agent-flywheel](https://agent-flywheel.com) ecosystem tools as **git subtrees** in `vendor/`. This approach lets us:

- **Move fast**: No waiting for upstream releases
- **Make changes**: Modify tools to fit our workflow
- **Control versions**: Pin exactly what's deployed
- **Contribute back**: Send improvements upstream when appropriate

### Included Tools

| Tool | Binary | Version | Purpose |
|------|--------|---------|---------|
| [NTM](https://github.com/Dicklesworthstone/ntm) | `ntm` | v1.3.0 | Tmux session manager for spawning/coordinating agents |
| [Gastown](https://github.com/steveyegge/gastown) | `gt` | main | Multi-agent orchestrator with convoys and beads |
| [Beads Viewer](https://github.com/Dicklesworthstone/beads_viewer) | `bv` | v0.11.3 | TUI for viewing/managing task beads |
| [CASS](https://github.com/Dicklesworthstone/coding_agent_session_search) | `cass` | v0.1.49 | Search across agent session history |
| [CASS Memory](https://github.com/Dicklesworthstone/cass_memory_system) | `cm` | v0.2.1 | Procedural memory system for agents |
| [Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail) | (MCP) | v0.1.3 | Agent-to-agent coordination via mailboxes |
| [UBS](https://github.com/Dicklesworthstone/ultimate_bug_scanner) | `ubs` | v5.0.3 | Static analysis across 7 languages |
| [CAAM](https://github.com/Dicklesworthstone/coding_agent_account_manager) | `caam` | v0.1.0 | Switch between agent auth credentials |
| [SLB](https://github.com/Dicklesworthstone/simultaneous_launch_button) | `slb` | v0.1.0 | Two-person rule for dangerous commands |

### Updating a Subtree

```bash
# Pull a new release
git subtree pull --prefix=vendor/ntm \
    https://github.com/Dicklesworthstone/ntm.git v1.4.0 --squash

# Rebuild container
./run.sh --build
```

### Making Local Changes

Edit files in `vendor/` directly and commit:

```bash
vim vendor/ntm/cmd/spawn.go
git add vendor/ntm/cmd/spawn.go
git commit -m "fix(ntm): handle edge case in spawn"
```

See [AGENTS.md](./AGENTS.md) for detailed subtree management instructions.

## Container Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Agent Dev Container                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  /source (read-only mount)                           │   │
│  │  └── myproject/  ← Your local git repo              │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ git clone                        │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  /workspace (persistent volume)                      │   │
│  │  └── gt/                                             │   │
│  │      ├── .beads/      ← Issue tracking              │   │
│  │      └── rigs/                                       │   │
│  │          └── myproject/  ← Agent worktree           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Nested Podman (privileged)                          │   │
│  │  └── Can run builds, tests, local deployments       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_DEV_IMAGE` | `agent-dev:latest` | Container image name |
| `AGENT_DEV_NAME` | `agent-dev` | Container name |
| `AGENT_DEV_WORKSPACE` | `agent-workspace` | Workspace volume name |

### Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `agent-containers` | `/var/lib/containers` | Podman storage (rootful) |
| `agent-home` | `/home/agent/.local/share/containers` | Podman storage (rootless) |
| `agent-workspace` | `/workspace` | Persistent workspace |

### Files

| File | Description |
|------|-------------|
| `Dockerfile` | Container image definition |
| `containers.conf` | Podman configuration |
| `storage.conf` | Container storage configuration |
| `entrypoint.sh` | Container initialization |
| `run.sh` | Helper script for launching |

## Troubleshooting

### Nested containers not working

Ensure the container is running with proper flags:

```bash
podman run --privileged --device=/dev/fuse --security-opt label=disable ...
```

### Permission issues

The container uses `--userns=keep-id` to map your host UID. If you see permission errors:

```bash
# Reset the workspace volume
./run.sh --reset
```

### Storage driver errors

If you see "overlay-on-overlay" errors:

```bash
# Check storage configuration
podman info | grep -A5 storage

# Volumes should be using native storage, not overlay mounts
```

## References

- [Agent Flywheel](https://agent-flywheel.com)
- [Gastown](https://github.com/steveyegge/gastown)
- [Podman Inside Container](https://www.redhat.com/en/blog/podman-inside-container)
- [Claude Code](https://github.com/anthropics/claude-code)
- [Codex CLI](https://github.com/openai/codex)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)
