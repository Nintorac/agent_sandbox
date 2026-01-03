# Agent Development Container
# Fedora-based container with podman-in-podman support for AI agent workflows
# Inspired by agent-flywheel.com

FROM fedora:41

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

# Node.js 22 LTS
RUN dnf module install -y nodejs:22/common \
    && dnf clean all \
    && npm install -g npm@latest

# Python 3.12
RUN dnf install -y \
    python3.12 \
    python3.12-pip \
    python3.12-devel \
    && dnf clean all \
    && alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && alternatives --install /usr/bin/pip pip /usr/bin/pip3.12 1

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
    && chown -R agent:agent /home/agent/.local/share/containers

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

# Install CLI utilities via cargo
RUN . "$HOME/.cargo/env" && \
    cargo install lsd && \
    cargo install zoxide --locked && \
    cargo install atuin && \
    cargo install starship --locked && \
    cargo install bat && \
    cargo install eza

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/agent/.bun/bin:${PATH}"

# =============================================================================
# Stage 5: Install AI Agent CLIs
# =============================================================================

# Install Claude Code, Codex CLI, Gemini CLI
RUN npm install -g @anthropic-ai/claude-code \
    && npm install -g @openai/codex \
    && npm install -g @google/gemini-cli

# =============================================================================
# Stage 6: Shell Configuration
# =============================================================================

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Configure zsh with plugins and starship
RUN cat > ~/.zshrc << 'EOF'
# Path configuration
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"

# Oh-My-Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using starship instead
plugins=(git fzf zoxide)
source $ZSH/oh-my-zsh.sh

# Initialize tools
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"

# Aliases using modern tools
alias ls='lsd'
alias ll='lsd -la'
alias lt='lsd --tree'
alias cat='bat --paging=never'

# Agent environment
export WORKSPACE="/workspace"
export SOURCE="/source"

# Gastown environment
export GT_HOME="$WORKSPACE/gt"

# Container detection
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    export CONTAINER_ENV=1
fi
EOF

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
# Stage 7: Create workspace directories
# =============================================================================

USER root

# Create mount points
RUN mkdir -p /source /workspace \
    && chown agent:agent /source /workspace

# Volumes for container storage (avoid overlay-on-overlay)
VOLUME /var/lib/containers
VOLUME /home/agent/.local/share/containers
VOLUME /workspace

# =============================================================================
# Stage 8: Entrypoint
# =============================================================================

COPY --chown=agent:agent entrypoint.sh /home/agent/entrypoint.sh
RUN chmod +x /home/agent/entrypoint.sh

USER agent
WORKDIR /workspace

ENTRYPOINT ["/home/agent/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
