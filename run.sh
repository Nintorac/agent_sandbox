#!/bin/bash
# Agent Development Container Runner
# Launches the container with proper flags for podman-in-podman support

set -e

# Configuration
IMAGE_NAME="${AGENT_DEV_IMAGE:-agent-dev:latest}"
CONTAINER_NAME="${AGENT_DEV_NAME:-agent-dev}"
WORKSPACE_VOLUME="${AGENT_DEV_WORKSPACE:-agent-workspace}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [COMMAND]

Run the agent development container with proper podman-in-podman support.

Options:
    -s, --source PATH    Mount additional source directory (can be used multiple times)
    -n, --name NAME      Container name (default: agent-dev)
    -d, --detach         Run in detached mode
    -r, --reset          Reset workspace volume (destroys existing data)
    -b, --build          Build the image before running
    -h, --help           Show this help message

Environment Variables:
    AGENT_DEV_IMAGE      Image name (default: agent-dev:latest)
    AGENT_DEV_NAME       Container name (default: agent-dev)
    AGENT_DEV_WORKSPACE  Workspace volume name (default: agent-workspace)

Examples:
    # Run with current directory as source
    ./run.sh

    # Run with specific project
    ./run.sh -s ~/projects/myapp

    # Run with multiple projects
    ./run.sh -s ~/projects/frontend -s ~/projects/backend

    # Build and run
    ./run.sh --build

    # Run a specific command
    ./run.sh claude

EOF
    exit 0
}

# Parse arguments
SOURCE_MOUNTS=()
DETACH=""
RESET=""
BUILD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_MOUNTS+=("$2")
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH="-d"
            shift
            ;;
        -r|--reset)
            RESET="1"
            shift
            ;;
        -b|--build)
            BUILD="1"
            shift
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Build if requested
if [ -n "$BUILD" ]; then
    echo -e "${GREEN}Building image...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Reset workspace if requested
if [ -n "$RESET" ]; then
    echo -e "${YELLOW}Resetting workspace volume...${NC}"
    podman volume rm -f "$WORKSPACE_VOLUME" 2>/dev/null || true
fi

# Build volume mount arguments
VOLUME_ARGS=(
    # Rootless podman storage (avoid overlay-on-overlay)
    "-v" "agent-home:/home/agent/.local/share/containers"
    # Persistent workspace
    "-v" "${WORKSPACE_VOLUME}:/workspace"
)

# Add source mounts
if [ ${#SOURCE_MOUNTS[@]} -eq 0 ]; then
    # Default: mount current directory as source
    if [ -d ".git" ] || [ -f "package.json" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ]; then
        PROJECT_NAME=$(basename "$(pwd)")
        VOLUME_ARGS+=("-v" "$(pwd):/source/${PROJECT_NAME}:ro,z")
        echo -e "${GREEN}Mounting current directory as /source/${PROJECT_NAME}${NC}"
    else
        echo -e "${YELLOW}No project detected in current directory${NC}"
        echo -e "Use -s/--source to mount a specific project"
    fi
else
    for src in "${SOURCE_MOUNTS[@]}"; do
        if [ -d "$src" ]; then
            PROJECT_NAME=$(basename "$src")
            VOLUME_ARGS+=("-v" "$(realpath "$src"):/source/${PROJECT_NAME}:ro,z")
            echo -e "${GREEN}Mounting $src as /source/${PROJECT_NAME}${NC}"
        else
            echo -e "${RED}Warning: $src does not exist, skipping${NC}" >&2
        fi
    done
fi

# Remove existing container if running
if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Run the container
echo -e "${GREEN}Starting agent development container...${NC}"

exec podman run \
    ${DETACH} \
    -it \
    --rm \
    --name "$CONTAINER_NAME" \
    --security-opt label=disable \
    --userns=keep-id \
    --hostname agent-dev \
    "${VOLUME_ARGS[@]}" \
    "$IMAGE_NAME" \
    "$@"
