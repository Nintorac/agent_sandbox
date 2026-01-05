#!/bin/bash
# Agent Development Container Runner
# Launches the container with proper flags for podman-in-podman support

set -e

# Configuration
IMAGE_NAME="${AGENT_DEV_IMAGE:-agent-dev:latest}"
CONTAINER_NAME="${AGENT_DEV_NAME:-agent-dev}"
WORKSPACE_DIR="${AGENT_DEV_WORKSPACE:-/workspace/agent_workspace}"

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
    -r, --replace        Replace existing container with same name
    -b, --build          Build the image before running
    -h, --help           Show this help message

Environment Variables:
    AGENT_DEV_IMAGE      Image name (default: agent-dev:latest)
    AGENT_DEV_NAME       Container name (default: agent-dev)
    AGENT_DEV_WORKSPACE  Workspace directory path (default: /workspace/agent_workspace)

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
REPLACE=""
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
        -r|--replace)
            REPLACE="--replace"
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

    # Sync to yolo user if it exists (they have separate podman storage)
    if id "yolo" &>/dev/null; then
        echo -e "${GREEN}Syncing image to yolo user...${NC}"
        podman save "$IMAGE_NAME" | sudo -u yolo podman load
    fi
fi

# Ensure workspace directory exists
mkdir -p "$WORKSPACE_DIR"

# Build volume mount arguments
VOLUME_ARGS=(
    # Rootless podman storage (avoid overlay-on-overlay)
    "-v" "agent-home:/home/agent/.local/share/containers"
    # Persistent workspace (bind mount from host)
    "-v" "${WORKSPACE_DIR}:/workspace:Z"
)

# Add source mounts
if [ ${#SOURCE_MOUNTS[@]} -eq 0 ]; then
    # Default: mount current directory as source
    if [ -d ".git" ] || [ -f "package.json" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ]; then
        PROJECT_NAME=$(basename "$(pwd)")
        VOLUME_ARGS+=("-v" "$(pwd):/source/${PROJECT_NAME}:ro")
        echo -e "${GREEN}Mounting current directory as /source/${PROJECT_NAME}${NC}"
    else
        echo -e "${YELLOW}No project detected in current directory${NC}"
        echo -e "Use -s/--source to mount a specific project"
    fi
else
    for src in "${SOURCE_MOUNTS[@]}"; do
        if [ -d "$src" ]; then
            PROJECT_NAME=$(basename "$src")
            VOLUME_ARGS+=("-v" "$(realpath "$src"):/source/${PROJECT_NAME}:ro")
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

# Check if yolo user exists for isolated execution
if id "yolo" &>/dev/null; then
    # Run as isolated yolo user (recommended for security)
    echo -e "${GREEN}Running as isolated 'yolo' user${NC}"
    exec sudo -u yolo podman run \
        --init \
        --stop-signal SIGHUP \
        ${DETACH} \
        -it \
        --rm \
        ${REPLACE} \
        --name "$CONTAINER_NAME" \
        --user root \
        --security-opt label=disable \
        --cap-add=CAP_SETUID \
        --cap-add=CAP_SETGID \
        --cap-add=CAP_SYS_ADMIN \
        --device /dev/fuse \
        --hostname agent-dev \
        "${VOLUME_ARGS[@]}" \
        "$IMAGE_NAME" \
        "$@"
else
    # Fallback: run as current user (less secure - escape lands as your user)
    echo -e "${YELLOW}Warning: 'yolo' user not found. Running as current user.${NC}"
    echo -e "${YELLOW}For better isolation, create yolo user (see docs/SECURITY.md)${NC}"
    exec podman run \
        --init \
        --stop-signal SIGHUP \
        ${DETACH} \
        -it \
        --rm \
        ${REPLACE} \
        --name "$CONTAINER_NAME" \
        --user root \
        --security-opt label=disable \
        --cap-add=CAP_SETUID \
        --cap-add=CAP_SETGID \
        --cap-add=CAP_SYS_ADMIN \
        --device /dev/fuse \
        --hostname agent-dev \
        "${VOLUME_ARGS[@]}" \
        "$IMAGE_NAME" \
        "$@"
fi
