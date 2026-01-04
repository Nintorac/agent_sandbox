# Agent Development Container Makefile
# Build with parallel stages: make build

.PHONY: build build-parallel build-nocache run run-build shell clean reset help test-smoke

# Configuration
IMAGE_NAME ?= agent-dev
IMAGE_TAG ?= latest
CONTAINER_NAME ?= agent-dev
WORKSPACE_VOLUME ?= agent-workspace
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

## volumes: List all volumes used by this project
volumes:
	@echo "Workspace volume:"
	@podman volume inspect $(WORKSPACE_VOLUME) 2>/dev/null || echo "  (not created)"
	@echo ""
	@echo "Podman storage volume:"
	@podman volume inspect $(PODMAN_STORAGE_VOLUME) 2>/dev/null || echo "  (not created)"

## reset: Remove workspace volume (WARNING: destroys all agent work)
reset:
	@echo "WARNING: This will destroy all agent work in /workspace"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	podman volume rm -f $(WORKSPACE_VOLUME)
	@echo "Workspace volume removed. Will be recreated on next run."

## reset-all: Remove all volumes and images (full reset)
reset-all:
	@echo "WARNING: This will destroy ALL data and the container image"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	podman volume rm -f $(WORKSPACE_VOLUME) $(PODMAN_STORAGE_VOLUME) 2>/dev/null || true
	podman rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@echo "Full reset complete."

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
# Testing
# =============================================================================

## test-smoke: Run smoke tests to validate all tools are installed correctly
test-smoke:
	podman run --rm \
		-v $(CURDIR)/tests:/tests:ro,z \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		bash /tests/smoke_test.sh

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
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(volume|reset|Volume)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Cleanup:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(clean|Clean)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Development:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(lint|inspect|history|size|subtree)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Testing:"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -E '(test)' | sed 's/## /  /' | sed 's/: /\t/'
	@echo ""
	@echo "Examples:"
	@echo "  make build          # Build with parallel stages"
	@echo "  make run-build      # Build and run"
	@echo "  make clean          # Remove build cache"
