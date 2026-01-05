# Agent Development Container
# Fedora-based container with podman-in-podman support for AI agent workflows
# Inspired by agent-flywheel.com
#
# Build with parallel stages: podman build --jobs=0 -t agent-dev .

# =============================================================================
# Builder Stage 1: Go Tools
# Based on vendor/ntm/Dockerfile approach (golang:1.25-alpine)
# =============================================================================
FROM golang:1.25-alpine AS go-builder

WORKDIR /build

# Install build dependencies (matches ntm Dockerfile)
RUN apk add --no-cache git ca-certificates tzdata gcc musl-dev

# GOTOOLCHAIN=auto downloads exact Go version if go.mod requires it
ENV GOTOOLCHAIN=auto
ENV GOSUMDB=sum.golang.org

# Create output directory
RUN mkdir -p /out

# --- Build ntm (matches vendor/ntm/Dockerfile) ---
COPY vendor/ntm /build/ntm
ARG NTM_VERSION=dev
ARG NTM_COMMIT=unknown
RUN cd /build/ntm \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags="-s -w \
            -X github.com/Dicklesworthstone/ntm/internal/cli.Version=${NTM_VERSION} \
            -X github.com/Dicklesworthstone/ntm/internal/cli.Commit=${NTM_COMMIT} \
            -X github.com/Dicklesworthstone/ntm/internal/cli.BuiltBy=docker" \
        -o /out/ntm ./cmd/ntm

# --- Build beads_viewer (no official Dockerfile, simple build) ---
COPY vendor/beads_viewer /build/beads_viewer
RUN cd /build/beads_viewer \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags="-s -w" \
        -o /out/bv ./cmd/bv

# --- Build gastown (requires CGO per .goreleaser.yml) ---
# Uses static linking to avoid musl/glibc mismatch with Fedora runtime
COPY vendor/gastown /build/gastown
ARG GT_VERSION=dev
ARG GT_COMMIT=unknown
RUN cd /build/gastown \
    && go mod download \
    && CGO_ENABLED=1 go build \
        -ldflags="-s -w -linkmode external -extldflags '-static' \
            -X github.com/steveyegge/gastown/internal/cmd.Version=${GT_VERSION} \
            -X github.com/steveyegge/gastown/internal/cmd.Commit=${GT_COMMIT}" \
        -o /out/gt ./cmd/gt

# --- Build beads (steveyegge/beads task tracker) ---
COPY vendor/beads /build/beads
RUN cd /build/beads \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags="-s -w" \
        -o /out/bd ./cmd/bd

# --- Build caam (no official Dockerfile, simple build) ---
COPY vendor/coding_agent_account_manager /build/caam
RUN cd /build/caam \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags="-s -w" \
        -o /out/caam ./cmd/caam

# --- Build slb (no official Dockerfile, simple build) ---
COPY vendor/simultaneous_launch_button /build/slb
RUN cd /build/slb \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags="-s -w" \
        -o /out/slb ./cmd/slb

# =============================================================================
# Builder Stage 2: Rust Tool (CASS)
# coding_agent_session_search uses edition = "2024" (requires nightly)
# Profile: lto=true, codegen-units=1, strip=true, panic="abort", opt-level="z"
# Dependencies: onig_sys, ring, libsqlite3-sys, zstd-sys, fastembed/onnxruntime
# =============================================================================
FROM rust:slim AS rust-builder

# Install build dependencies including C++ toolchain for native deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates \
    build-essential \
    g++ \
    libstdc++-12-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Install nightly toolchain (required for Rust 2024 edition)
RUN rustup default nightly

WORKDIR /build
COPY vendor/coding_agent_session_search .

# Build with release profile (Cargo.toml already has aggressive optimizations)
RUN mkdir -p /out \
    && cargo build --release \
    && cp target/release/cass /out/cass

# =============================================================================
# Builder Stage 3: Node Tool (cass_memory_system)
# Uses Bun to compile to standalone binary
# =============================================================================
FROM oven/bun:latest AS node-builder

WORKDIR /build
COPY vendor/cass_memory_system .

# Build standalone binary (matches package.json build:current script)
RUN bun install \
    && bun build src/cm.ts --compile --outfile dist/cass-memory \
    && mkdir -p /out \
    && cp dist/cass-memory /out/cm

# =============================================================================
# Builder Stage 4: Python Tool (mcp_agent_mail)
# Based on vendor/mcp_agent_mail/Dockerfile
# =============================================================================
FROM python:3.14-slim AS python-builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_SYSTEM_PYTHON=1 \
    PATH="/root/.local/bin:${PATH}"

# Install dependencies (matches vendor Dockerfile)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /app

# Copy project metadata first for better caching (matches vendor Dockerfile)
COPY vendor/mcp_agent_mail/pyproject.toml vendor/mcp_agent_mail/README.md ./

# Install runtime deps
RUN uv sync --no-dev

# Copy source
COPY vendor/mcp_agent_mail/src ./src

# =============================================================================
# Final Stage: Fedora Runtime
# =============================================================================
FROM fedora:41

# Build arguments
ARG OHMYZSH_COMMIT=a79b37b95461ea2be32578957473375954ab31ff

LABEL maintainer="agent-dev"
LABEL description="AI Agent Development Environment with podman-in-podman support"

# -----------------------------------------------------------------------------
# System Packages & Podman Setup
# -----------------------------------------------------------------------------

# Install system packages including podman and container tools
RUN dnf install -y \
    # Container runtime
    podman \
    fuse-overlayfs \
    slirp4netns \
    crun \
    buildah \
    skopeo \
    # Shell and terminal
    zsh \
    tmux \
    # Core utilities
    git \
    curl \
    wget \
    jq \
    yq \
    unzip \
    tar \
    gzip \
    xz \
    # Search tools
    ripgrep \
    fd-find \
    fzf \
    # Development tools
    make \
    cmake \
    gcc \
    gcc-c++ \
    openssl-devel \
    pkg-config \
    # User management
    shadow-utils \
    util-linux \
    passwd \
    # Misc
    procps-ng \
    less \
    vim-minimal \
    which \
    sudo \
    # Network tools (for smoke tests)
    iproute \
    iputils \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# -----------------------------------------------------------------------------
# Language Runtimes
# -----------------------------------------------------------------------------

# Node.js 22 LTS (via NodeSource)
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs \
    && dnf clean all \
    && npm install -g npm@latest

# Go (for any runtime needs - vendor tools are pre-built)
RUN dnf install -y golang \
    && dnf clean all

# -----------------------------------------------------------------------------
# Create Agent User with subuid/subgid for rootless podman
# -----------------------------------------------------------------------------

RUN useradd -m -s /usr/bin/zsh agent \
    && echo "agent:100000:65536" >> /etc/subuid \
    && echo "agent:100000:65536" >> /etc/subgid \
    && mkdir -p /home/agent/.local/bin \
    && mkdir -p /home/agent/.config \
    && mkdir -p /home/agent/.cache \
    && chown -R agent:agent /home/agent \
    && echo "agent ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/agent \
    && chmod 440 /etc/sudoers.d/agent

# Configure podman for nested containers
COPY containers.conf /etc/containers/containers.conf
COPY storage.conf /etc/containers/storage.conf
RUN chmod 644 /etc/containers/containers.conf /etc/containers/storage.conf \
    && chmod 4755 /usr/bin/newuidmap \
    && chmod 4755 /usr/bin/newgidmap

# Create rootless storage directories
RUN mkdir -p /home/agent/.local/share/containers/storage \
    && chown -R agent:agent /home/agent/.local/share

# -----------------------------------------------------------------------------
# Copy Pre-built Vendor Tools from Builder Stages
# -----------------------------------------------------------------------------

# Go tools (ntm, bv, gt, bd, caam, slb)
COPY --from=go-builder --chown=agent:agent /out/ntm /home/agent/.local/bin/ntm
COPY --from=go-builder --chown=agent:agent /out/bv /home/agent/.local/bin/bv
COPY --from=go-builder --chown=agent:agent /out/gt /home/agent/.local/bin/gt
COPY --from=go-builder --chown=agent:agent /out/bd /home/agent/.local/bin/bd
COPY --from=go-builder --chown=agent:agent /out/caam /home/agent/.local/bin/caam
COPY --from=go-builder --chown=agent:agent /out/slb /home/agent/.local/bin/slb

# Rust tool (cass)
COPY --from=rust-builder --chown=agent:agent /out/cass /home/agent/.local/bin/cass

# Node tool (cm - cass_memory_system compiled binary)
COPY --from=node-builder --chown=agent:agent /out/cm /home/agent/.local/bin/cm

# Python tool (mcp_agent_mail) - copy entire app with venv
COPY --from=python-builder --chown=agent:agent /app /opt/mcp_agent_mail

# UBS - bash script, just copy directly (matches vendor/ultimate_bug_scanner/Dockerfile approach)
COPY --chown=agent:agent vendor/ultimate_bug_scanner/ubs /home/agent/.local/bin/ubs
RUN chmod +x /home/agent/.local/bin/ubs

# -----------------------------------------------------------------------------
# Install Rust & Cargo CLI Tools (as agent user)
# -----------------------------------------------------------------------------

USER agent
WORKDIR /home/agent

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env"

# Add cargo to PATH for subsequent commands
ENV PATH="/home/agent/.cargo/bin:${PATH}"

# Install CLI utilities via cargo (pinned versions)
ARG LSD_VERSION=1.1.5
ARG ZOXIDE_VERSION=0.9.6
ARG ATUIN_VERSION=18.4.0
ARG STARSHIP_VERSION=1.21.1
ARG BAT_VERSION=0.24.0
ARG EZA_VERSION=0.20.14
RUN . "$HOME/.cargo/env" && \
    cargo install lsd --version ${LSD_VERSION} --locked && \
    cargo install zoxide --version ${ZOXIDE_VERSION} --locked && \
    cargo install atuin --version ${ATUIN_VERSION} --locked && \
    cargo install starship --version ${STARSHIP_VERSION} --locked && \
    cargo install bat --version ${BAT_VERSION} --locked && \
    cargo install eza --version ${EZA_VERSION} --locked

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/agent/.bun/bin:${PATH}"

# Install uv and Python (3.12 for general use, 3.14 available via mcp_agent_mail venv)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/agent/.local/bin:${PATH}"
RUN uv python install 3.12

# -----------------------------------------------------------------------------
# Install AI Agent CLIs
# -----------------------------------------------------------------------------

# Configure npm for user-local global installs
RUN mkdir -p /home/agent/.npm-global \
    && npm config set prefix '/home/agent/.npm-global'
ENV PATH="/home/agent/.npm-global/bin:${PATH}"

# Install Claude Code, Codex CLI, Gemini CLI
RUN npm install -g @anthropic-ai/claude-code \
    && npm install -g @openai/codex \
    && npm install -g @google/gemini-cli

# -----------------------------------------------------------------------------
# Shell Configuration
# -----------------------------------------------------------------------------

# Install oh-my-zsh at pinned commit
ARG OHMYZSH_COMMIT
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/${OHMYZSH_COMMIT}/tools/install.sh)" "" --unattended

# Copy zsh configuration (includes velocity aliases for cc, cod, gmi)
COPY --chown=agent:agent zshrc /home/agent/.zshrc

# Configure starship prompt
RUN mkdir -p ~/.config && cat > ~/.config/starship.toml << 'EOF'
# Minimal prompt optimized for agent work
format = """
$directory$git_branch$git_status$character"""

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
format = "[$branch]($style) "
style = "bold purple"

[git_status]
format = '([$all_status$ahead_behind]($style) )'
style = "bold red"

[character]
success_symbol = "[>](bold green)"
error_symbol = "[>](bold red)"
EOF

# Cleanup cargo build cache to reduce image size
RUN rm -rf /home/agent/.cargo/registry \
    && rm -rf /home/agent/.cargo/git

# -----------------------------------------------------------------------------
# Create Workspace Directories
# -----------------------------------------------------------------------------

USER root

# Create mount points
RUN mkdir -p /source /workspace \
    && chown agent:agent /source /workspace

# Volumes for container storage (avoid overlay-on-overlay)
# Rootless podman storage (we don't use rootful podman)
VOLUME /home/agent/.local/share/containers
VOLUME /workspace

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------

COPY --chown=agent:agent entrypoint.sh /home/agent/entrypoint.sh
RUN chmod +x /home/agent/entrypoint.sh

# NTM projects base - use workspace subdirectory instead of /data/projects
ENV NTM_PROJECTS_BASE=/workspace/agents_home/projects

USER agent
WORKDIR /workspace

ENTRYPOINT ["/home/agent/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
