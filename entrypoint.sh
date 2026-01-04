#!/bin/bash
# Agent Development Container Entrypoint
# Initializes Gastown and workspace on first run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# =============================================================================
# Git Configuration
# =============================================================================

setup_git() {
    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        log_info "Setting up git configuration..."
        git config --global user.name "Agent"
        git config --global user.email "agent@localhost"
        git config --global init.defaultBranch main
        git config --global pull.rebase false
        git config --global core.autocrlf input
        log_success "Git configured"
    fi
}

# =============================================================================
# Gastown Initialization
# =============================================================================

init_gastown() {
    local GT_HOME="${WORKSPACE:-/workspace}/gt"

    if [ ! -d "$GT_HOME" ]; then
        log_info "Initializing Gastown workspace at $GT_HOME..."
        mkdir -p "$GT_HOME"
        mkdir -p "$GT_HOME/.beads"
        mkdir -p "$GT_HOME/rigs"

        # Create initial config
        cat > "$GT_HOME/.gtconfig" << 'EOF'
# Gastown Configuration
# See: https://github.com/steveyegge/gastown

[town]
name = "agent-town"
home = "/workspace/gt"

[source]
path = "/source"
readonly = true

[rigs]
path = "/workspace/gt/rigs"
EOF
        log_success "Gastown initialized at $GT_HOME"
    else
        log_info "Gastown already initialized at $GT_HOME"
    fi
}

# =============================================================================
# Source Repository Detection
# =============================================================================

detect_source_repos() {
    local SOURCE_DIR="${SOURCE:-/source}"

    if [ -d "$SOURCE_DIR" ] && [ "$(ls -A $SOURCE_DIR 2>/dev/null)" ]; then
        log_info "Detected source repositories in $SOURCE_DIR:"
        for repo in "$SOURCE_DIR"/*; do
            if [ -d "$repo/.git" ]; then
                local repo_name=$(basename "$repo")
                echo "  - $repo_name (git repo)"
            elif [ -d "$repo" ]; then
                local repo_name=$(basename "$repo")
                echo "  - $repo_name (directory)"
            fi
        done
        echo ""
        log_info "To add a rig: gt rig add <name> /source/<repo>"
    else
        log_warn "No source repositories mounted at $SOURCE_DIR"
        log_info "Mount your project with: -v /path/to/project:/source/project:ro,z"
    fi
}

# =============================================================================
# Podman Health Check
# =============================================================================

check_podman() {
    if podman info &>/dev/null; then
        log_success "Podman is available (nested containers supported)"
    else
        log_warn "Podman not fully available - nested containers may not work"
        log_info "Host kernel 5.13+ required for native overlay. Try: podman system reset"
    fi
}

# =============================================================================
# Print Welcome Banner
# =============================================================================

print_banner() {
    cat << 'EOF'

    _                    _     ____
   / \   __ _  ___ _ __ | |_  |  _ \  _____   __
  / _ \ / _` |/ _ \ '_ \| __| | | | |/ _ \ \ / /
 / ___ \ (_| |  __/ | | | |_  | |_| |  __/\ V /
/_/   \_\__, |\___|_| |_|\__| |____/ \___| \_/
        |___/

EOF
    echo "Agent Development Environment"
    echo "============================================"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_banner

    setup_git
    init_gastown
    check_podman
    detect_source_repos

    echo ""
    log_success "Environment ready!"
    echo ""
    echo "Quick commands:"
    echo "  claude        - Start Claude Code"
    echo "  codex         - Start Codex CLI"
    echo "  gemini        - Start Gemini CLI"
    echo "  gt            - Gastown orchestration"
    echo "  ntm           - Named Tmux Manager"
    echo ""

    # Switch to agent user if running as root
    # setpriv: no PAM, preserves env, preserves groups with --init-groups
    if [ "$(id -u)" = "0" ]; then
        cd /workspace
        export HOME=/home/agent
        exec setpriv --reuid=agent --regid=agent --init-groups -- "$@"
    fi
    exec "$@"
}

main "$@"
