#!/bin/bash
# Smoke test for agent-dev container
# Validates all installed tools are accessible and functional

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
FAILED_TOOLS=""

check_tool() {
    local name="$1"
    local cmd="$2"

    printf "  %-20s " "$name"

    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}"
        FAIL=$((FAIL + 1))
        FAILED_TOOLS="$FAILED_TOOLS $name"
    fi
}

echo "=========================================="
echo "Agent Dev Container Smoke Test"
echo "=========================================="
echo ""

echo "Go Binaries:"
check_tool "ntm" "ntm version"
check_tool "bv" "bv --version"
check_tool "gt" "gt --help"
check_tool "caam" "caam --help"
check_tool "slb" "slb --help"
echo ""

echo "Rust Binaries:"
check_tool "cass" "cass --version"
echo ""

echo "Node Binaries:"
check_tool "cm" "cm --version"
echo ""

echo "AI Agent CLIs:"
check_tool "claude" "claude --version"
check_tool "codex" "codex --version"
check_tool "gemini" "gemini --version"
echo ""

echo "Language Runtimes:"
check_tool "node" "node --version"
check_tool "npm" "npm --version"
check_tool "bun" "bun --version"
check_tool "go" "go version"
check_tool "cargo" "cargo --version"
check_tool "rustc" "rustc --version"
check_tool "python" "python --version"
echo ""

echo "Cargo Utilities:"
check_tool "lsd" "lsd --version"
check_tool "zoxide" "zoxide --version"
check_tool "atuin" "atuin --version"
check_tool "starship" "starship --version"
check_tool "bat" "bat --version"
check_tool "eza" "eza --version"
echo ""

echo "Container Tools (path check only - needs privileges to run):"
check_tool "podman" "command -v podman"
check_tool "buildah" "command -v buildah"
check_tool "skopeo" "skopeo --version"
echo ""

echo "System Tools:"
check_tool "git" "git --version"
check_tool "tmux" "tmux -V"
check_tool "zsh" "zsh --version"
check_tool "rg" "rg --version"
check_tool "fd" "fd --version"
check_tool "fzf" "fzf --version"
check_tool "jq" "jq --version"
check_tool "yq" "yq --version"
check_tool "make" "make --version"
check_tool "curl" "curl --version"
echo ""

echo "=========================================="
echo "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "=========================================="

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Failed tools:${FAILED_TOOLS}${NC}"
    exit 1
fi

echo -e "${GREEN}All smoke tests passed!${NC}"
exit 0
