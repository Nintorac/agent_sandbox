# Agent Development Container
# Fedora-based container with podman-in-podman support for AI agent workflows
# Inspired by agent-flywheel.com

FROM fedora:41

# Build arguments
ARG OHMYZSH_COMMIT=a79b37b95461ea2be32578957473375954ab31ff

LABEL maintainer="agent-dev"
LABEL description="AI Agent Development Environment with podman-in-podman support"

# =============================================================================
# Stage 1: Base System & Podman Setup
# =============================================================================

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
    && dnf clean all \
    && rm -rf /var/cache/dnf

# =============================================================================
# Stage 2: Language Runtimes
# =============================================================================

# Node.js 22 LTS (via NodeSource)
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs \
    && dnf clean all \
    && npm install -g npm@latest

# Python via uv (installed later as agent user)

# Go 1.23
RUN dnf install -y golang \
    && dnf clean all

# Rust (via rustup for the agent user - installed later)
# Bun (installed later as agent user)

# =============================================================================
# Stage 3: Create Agent User with subuid/subgid for rootless podman
# =============================================================================

RUN useradd -m -s /usr/bin/zsh agent \
    && echo "agent:100000:65536" >> /etc/subuid \
    && echo "agent:100000:65536" >> /etc/subgid \
    && mkdir -p /home/agent/.local/bin \
    && mkdir -p /home/agent/.config \
    && mkdir -p /home/agent/.cache \
    && chown -R agent:agent /home/agent

# Configure podman for nested containers
COPY containers.conf /etc/containers/containers.conf
COPY storage.conf /etc/containers/storage.conf

# Create rootless storage directories
RUN mkdir -p /home/agent/.local/share/containers/storage \
    && chown -R agent:agent /home/agent/.local/share

# =============================================================================
# Stage 4: Install Rust & Cargo Tools (as agent user)
# =============================================================================

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

# Install uv and Python
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/agent/.local/bin:${PATH}"
RUN uv python install 3.12

# =============================================================================
# Stage 5: Install AI Agent CLIs
# =============================================================================

# Configure npm for user-local global installs
RUN mkdir -p /home/agent/.npm-global \
    && npm config set prefix '/home/agent/.npm-global'
ENV PATH="/home/agent/.npm-global/bin:${PATH}"

# Install Claude Code, Codex CLI, Gemini CLI
RUN npm install -g @anthropic-ai/claude-code \
    && npm install -g @openai/codex \
    && npm install -g @google/gemini-cli

# =============================================================================
# Stage 6: Build & Install Flywheel Tools from vendor/
# =============================================================================

# Copy vendor directory
USER root
COPY --chown=agent:agent vendor /opt/vendor
USER agent

# Build Go tools (ntm, beads_viewer, gastown, caam, slb)
# GOTOOLCHAIN=auto downloads required Go version if needed
ENV GOTOOLCHAIN=auto
ENV GOSUMDB=sum.golang.org
RUN cd /opt/vendor/ntm && go build -o /home/agent/.local/bin/ntm ./cmd/ntm \
    && cd /opt/vendor/beads_viewer && go build -o /home/agent/.local/bin/bv ./cmd/bv \
    && cd /opt/vendor/gastown && go build -o /home/agent/.local/bin/gt ./cmd/gt \
    && cd /opt/vendor/coding_agent_account_manager && go build -o /home/agent/.local/bin/caam ./cmd/caam \
    && cd /opt/vendor/simultaneous_launch_button && go build -o /home/agent/.local/bin/slb ./cmd/slb

# Build Rust tool (coding_agent_session_search / cass)
RUN cd /opt/vendor/coding_agent_session_search \
    && . "$HOME/.cargo/env" \
    && cargo build --release \
    && cp target/release/cass /home/agent/.local/bin/cass

# Install UBS (bash script)
RUN cp /opt/vendor/ultimate_bug_scanner/ubs /home/agent/.local/bin/ubs \
    && chmod +x /home/agent/.local/bin/ubs

# Install mcp_agent_mail as MCP server (library, not CLI)
# Requires Python 3.14
RUN uv python install 3.14 \
    && uv venv --python 3.14 /home/agent/.venv-mcp \
    && VIRTUAL_ENV=/home/agent/.venv-mcp uv pip install /opt/vendor/mcp_agent_mail

# Install Node.js tool (cass_memory_system)
RUN cd /opt/vendor/cass_memory_system && npm install && npm link

# Cleanup build artifacts to reduce image size
RUN rm -rf /opt/vendor/*/target \
    && rm -rf /opt/vendor/*/.git \
    && rm -rf /home/agent/.cargo/registry \
    && rm -rf /home/agent/.cargo/git

# =============================================================================
# Stage 7: Shell Configuration
# =============================================================================

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

# =============================================================================
# Stage 8: Create workspace directories
# =============================================================================

USER root

# Create mount points
RUN mkdir -p /source /workspace \
    && chown agent:agent /source /workspace

# Volumes for container storage (avoid overlay-on-overlay)
# Rootless podman storage (we don't use rootful podman)
VOLUME /home/agent/.local/share/containers
VOLUME /workspace

# =============================================================================
# Stage 9: Entrypoint
# =============================================================================

COPY --chown=agent:agent entrypoint.sh /home/agent/entrypoint.sh
RUN chmod +x /home/agent/entrypoint.sh

USER agent
WORKDIR /workspace

ENTRYPOINT ["/home/agent/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
