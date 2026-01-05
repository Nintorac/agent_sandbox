# Agent Development Container Makefile
# Build with parallel stages: make build

.PHONY: build build-parallel build-nocache run run-build shell clean help test-smoke build-bv

# Configuration
IMAGE_NAME ?= agent-dev
IMAGE_TAG ?= latest
CONTAINER_NAME ?= agent-dev
WORKSPACE_DIR ?= /workspace/agent_workspace
PODMAN_STORAGE_VOLUME ?= agent-podman-storage

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# Build Targets
# =============================================================================

## build: Build the container image with parallel stages (recommended)
build:
	podman build --jobs=0 -t $(IMAGE_NAME):$(IMAGE_TAG) .

## build-sequential: Build the container image without parallel stages
build-sequential:
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) .

## build-nocache: Build the container image from scratch (no cache)
build-nocache:
	podman build --no-cache --jobs=0 -t $(IMAGE_NAME):$(IMAGE_TAG) .

## build-progress: Build with verbose progress output
build-progress:
	podman build --jobs=0 --progress=plain -t $(IMAGE_NAME):$(IMAGE_TAG) .

# =============================================================================
# Run Targets
# =============================================================================

## run: Run the container interactively
run:
	./run.sh

## run-build: Build and run the container
run-build:
	./run.sh --build

## shell: Get a shell in an already-running container
shell:
	podman exec -it $(CONTAINER_NAME) /usr/bin/zsh

# =============================================================================
# Volume Management
# =============================================================================

## volumes: List volumes and directories used by this project
volumes:
	@echo "Workspace directory: $(WORKSPACE_DIR)"
	@ls -ld $(WORKSPACE_DIR) 2>/dev/null || echo "  (not created)"
	@echo ""
	@echo "Podman storage volume:"
	@podman volume inspect $(PODMAN_STORAGE_VOLUME) 2>/dev/null || echo "  (not created)"

# =============================================================================
# Cleanup
# =============================================================================

## clean: Remove dangling images and build cache
clean:
	podman image prune -f
	podman builder prune -f

## clean-all: Remove all unused images (not just dangling)
clean-all:
	podman image prune -a -f
	podman builder prune -a -f

# =============================================================================
# Development
# =============================================================================

## lint-dockerfile: Lint the Dockerfile with hadolint (if installed)
lint-dockerfile:
	@command -v hadolint >/dev/null 2>&1 && hadolint Dockerfile || \
		echo "hadolint not installed. Run: podman run --rm -i hadolint/hadolint < Dockerfile"

## inspect: Show image details
inspect:
	podman inspect $(IMAGE_NAME):$(IMAGE_TAG)

## history: Show image layer history
history:
	podman history $(IMAGE_NAME):$(IMAGE_TAG)

## size: Show image size breakdown
size:
	@echo "Image size:"
	@podman images $(IMAGE_NAME):$(IMAGE_TAG) --format "{{.Size}}"
	@echo ""
	@echo "Layer breakdown:"
	@podman history --format "{{.Size}}\t{{.CreatedBy}}" $(IMAGE_NAME):$(IMAGE_TAG) | head -20

# =============================================================================
# Image Sharing
# =============================================================================

## sync-image: Copy agent-dev image from current user to yolo user
sync-image:
	@echo "Exporting $(IMAGE_NAME):$(IMAGE_TAG) from current user..."
	podman save $(IMAGE_NAME):$(IMAGE_TAG) | sudo -u yolo podman load
	@echo "Image synced to yolo user."

# =============================================================================
# Testing
# =============================================================================

## test-smoke: Run smoke tests to validate all tools are installed correctly
test-smoke:
	@if id "yolo" &>/dev/null; then \
		echo "Running smoke tests as yolo user..."; \
		sudo -u yolo podman run --rm \
			--user root \
			--security-opt label=disable \
			--cap-add=CAP_SETUID \
			--cap-add=CAP_SETGID \
			--cap-add=CAP_SYS_ADMIN \
			--device /dev/fuse \
			-v yolo-agent-storage:/home/agent/.local/share/containers \
			-v $(CURDIR)/tests:/tests:ro,z \
			$(IMAGE_NAME):$(IMAGE_TAG) \
			bash /tests/smoke_test.sh; \
	else \
		echo "Warning: yolo user not found, running as current user"; \
		podman run --rm \
			--user root \
			--security-opt label=disable \
			--cap-add=CAP_SETUID \
			--cap-add=CAP_SETGID \
			--cap-add=CAP_SYS_ADMIN \
			--device /dev/fuse \
			-v agent-podman-storage:/home/agent/.local/share/containers \
			-v $(CURDIR)/tests:/tests:ro,z \
			$(IMAGE_NAME):$(IMAGE_TAG) \
			bash /tests/smoke_test.sh; \
	fi

# =============================================================================
# Standalone Tool Images
# =============================================================================

## build-bv: Build standalone Beads Viewer image
build-bv:
	podman build -f vendor/beads_viewer/Dockerfile.standalone \
		-t bv:latest vendor/beads_viewer

# =============================================================================
# Subtree Management
# =============================================================================

## subtree-status: Show status of all vendored subtrees
subtree-status:
	@echo "Vendored subtrees in vendor/:"
	@for dir in vendor/*/; do \
		name=$$(basename $$dir); \
		echo "  $$name"; \
	done

# =============================================================================
# Help
# =============================================================================

## help: Show this help message
help:
	@echo "Agent Development Container"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(build|Build)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Run targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(run|Run|shell)' | grep -v 'test' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Volume management:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(volume|Volume)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Cleanup:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(clean|Clean)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Development:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(lint|inspect|history|size|subtree)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Standalone tool images:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(build-bv)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Testing:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(test)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Examples:"
	@echo "  make build          # Build with parallel stages"
	@echo "  make run-build      # Build and run"
	@echo "  make clean          # Remove build cache"
