#!/usr/bin/env bash
#
# miro-docker.sh — MiRo Docker helper script
#
# Purpose:
#   A helper script to manage MiRo Docker containers for development and testing.
#   Supports starting, stopping, attaching, and saving containers.
#
# Usage:
#   ./miro-docker.sh <command>
#
# Commands:
#   start   - Pull/build the Docker image and start a container.
#   stop    - Stop and remove the last started container.
#   term    - Attach an interactive shell.
#   save    - Commit container to new image.
#
# Environment Variables:
#   IMAGE_NAME        - Default image name
#   IMAGE_TAG         - Default image tag
#   CONTAINER_NAME    - Default container name
#   DISPLAY           - X server display (defaults to ":0")
#   STATE_FILE        - Path to persistent state file (default: ~/.miro-docker-state)
#
# Files:
#   compose.*.yaml    - Platform/GPU-specific compose files
#   Dockerfile        - For local build
#
# Examples:
#   ./miro-docker.sh start
#   ./miro-docker.sh term
#   ./miro-docker.sh save
#   ./miro-docker.sh stop

set -euo pipefail

# --- Persistent state handling ---
STATE_FILE="${STATE_FILE:-$HOME/.miro-docker-state}"

# --- Save MiRo container info---
save_state() {
    {
        echo "IMAGE_NAME='$IMAGE_NAME'"
        echo "IMAGE_TAG='$IMAGE_TAG'"
        echo "CONTAINER_NAME='$CONTAINER_NAME'"
    } > "$STATE_FILE"
}

# --- Load MiRo container info---
load_state() {
    [[ -f "$STATE_FILE" ]] || return 0
    while IFS='=' read -r key raw_value; do
        value="${raw_value%\"}" ; value="${value#\"}"
        value="${value%\'}" ; value="${value#\'}"

        case "$key" in
            IMAGE_NAME|IMAGE_TAG|CONTAINER_NAME)
                export "$key=$value"
                ;;
        esac
    done < "$STATE_FILE"
}

# --- Settings ---
DISPLAY="${DISPLAY:-:0}"
BASE_IMAGE_NAME="${IMAGE_NAME:-alexandrlucas/miro-docker}"
BASE_IMAGE_TAG="${IMAGE_TAG:-latest}"
BASE_CONTAINER_NAME="${CONTAINER_NAME:-miro-docker}"

load_state

COMMAND=${1:-}

# --- Show usage ---
show_usage() {
    awk '/^#/{if(NR>1)print substr($0,2)} !/^#/{if(NR>1)exit}' "$0"
}

# --- Docker Compose wrapper ---
dc() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

# --- Utility functions ---
ask_confirm() {
    local prompt="${1:-Are you sure?}"
    echo -n "$prompt [yes/no]: "
    read -r answer
    [[ "$answer" == "yes" ]]
}

# --- Select the right compose ---
get_compose_file() {
    local uname_out env gpu candidates=()
    uname_out="$(uname -s 2>/dev/null || echo Unknown)"
    case "$uname_out" in
        Linux*)
            if [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
                env="wsl"
            else
                env="linux"
            fi ;;
        Darwin*) env="mac" ;;
        MINGW*|MSYS*|CYGWIN*) env="windows" ;;
        *) env="unknown" ;;
    esac

    gpu="none"
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu="nvidia"
    elif command -v lspci >/dev/null 2>&1; then
        if lspci 2>/dev/null | grep -qi nvidia; then
            gpu="nvidia"
        elif lspci 2>/dev/null | grep -qiE 'amd|advanced micro devices'; then
            gpu="amd"
        fi
    fi

    case "$env" in
        mac)
            candidates=("compose.mac.yaml" "compose.yaml") ;;
        windows|wsl|linux)
            case "$gpu" in
                nvidia) candidates=("compose.${env}.nvidia.yaml" "compose.${env}.yaml" "compose.yaml") ;;
                amd)    candidates=("compose.${env}.amd.yaml" "compose.${env}.yaml" "compose.yaml") ;;
                none)   candidates=("compose.${env}.yaml" "compose.yaml") ;;
            esac ;;
        *) candidates=("compose.yaml") ;;
    esac

    for f in "${candidates[@]}"; do
        [[ -f "$f" ]] && { echo "$f"; return; }
    done
    echo "compose.yaml"
}

# --- Use state file to identify the correct container ---
get_container_id() {
    local name="${1:-$BASE_CONTAINER_NAME}"
    local cid
    cid=$(docker ps --filter "name=^/${name}$" --format '{{.ID}}' | head -n1)
    if [[ -z "$cid" ]]; then
        echo "❌ No running container named '$name'." >&2
        return 1
    fi
    echo "$cid"
}

# --- Start container ---
start() {
    COMPOSE_FILE=$(get_compose_file)
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ $COMPOSE_FILE not found."
        return 1
    fi

    read -r -p "Enter image NAME [leave blank for $BASE_IMAGE_NAME]: " NAME
    NAME="${NAME:-$BASE_IMAGE_NAME}"
    export IMAGE_NAME="$NAME"

    read -r -p "Enter image TAG [leave blank for $BASE_IMAGE_TAG]: " TAG
    TAG="${TAG:-$BASE_IMAGE_TAG}"
    export IMAGE_TAG="$TAG"

    IMAGE="$NAME:$TAG"
    echo "🔍 Checking $IMAGE..."

    if docker pull "$IMAGE" 2>/dev/null; then
        echo "✅ Pulled image: $IMAGE."
    elif docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "⚠️ Using local image: $IMAGE."
    else
        echo "⚠️ Building from Dockerfile..."
# ------------------------------------------------------------------------------
        docker build --progress=plain --no-cache -t "$IMAGE" .
# ------------------------------------------------------------------------------
    fi

    read -r -p "Customise container name [leave blank for $BASE_CONTAINER_NAME]: " C_NAME
    CONTAINER_NAME="${C_NAME:-$BASE_CONTAINER_NAME}"
    export CONTAINER_NAME

    echo "🚀 Starting $CONTAINER_NAME using $COMPOSE_FILE..."

    # Check X11 access configuration
    if xhost +local:docker >/dev/null 2>&1; then
        echo "🔓 X11 access enabled for Docker."
    else
        echo "🔒 Failed to enable X11 access for Docker."
    fi
# ------------------------------------------------------------------------------
    dc up -d --build
# ------------------------------------------------------------------------------
    CID=$(get_container_id "$CONTAINER_NAME")
    echo "✅ Started $CONTAINER_NAME (ID: $CID)."

    # Persist state for use in new terminal tabs
    save_state

    echo "💡 Use 'term', 'save', 'stop'."
}

# --- Stop container ---
stop() {
    COMPOSE_FILE=$(get_compose_file)
    local name="${CONTAINER_NAME:-$BASE_CONTAINER_NAME}"
    CID=$(get_container_id "$name") || return 1

    echo "⚠️ Stopping and removing $name ($CID)."
    if ! ask_confirm "Proceed?"; then
        echo "❌ Aborted."
        return 0
    fi
# ------------------------------------------------------------------------------
    dc down --remove-orphans
# ------------------------------------------------------------------------------
    # Clear stale state
    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"

    echo "✅ Stopped and removed."
}

# --- Attach shell ---
term() {
    COMPOSE_FILE=$(get_compose_file)
    local name="${CONTAINER_NAME:-$BASE_CONTAINER_NAME}"
    CID=$(get_container_id "$name") || return 1

    echo "🔗 Attaching to $name ($CID). Ctrl+D to exit."
# ------------------------------------------------------------------------------
    docker exec -it "$CID" /bin/bash
# ------------------------------------------------------------------------------
}

# --- Save container ---
save() {
    COMPOSE_FILE=$(get_compose_file)
    local name="${CONTAINER_NAME:-$BASE_CONTAINER_NAME}"
    CID=$(get_container_id "$name") || return 1

    IMAGE_BASE=$(docker inspect --format='{{.Config.Image}}' "$CID" | cut -d: -f1)
    read -r -p "Enter snapshot tag [default: snapshot-YYYYMMDD_HHMMSS]: " SNAPSHOT_TAG
    SNAPSHOT_TAG="${SNAPSHOT_TAG:-snapshot-$(date +%Y%m%d_%H%M%S)}"
    NEW_IMAGE="$IMAGE_BASE:$SNAPSHOT_TAG"

    echo "💾 Committing to $NEW_IMAGE..."
# ------------------------------------------------------------------------------
    docker commit "$CID" "$NEW_IMAGE"
# ------------------------------------------------------------------------------
    echo "✅ Saved as $NEW_IMAGE"
}

# --- Command dispatcher ---
case "$COMMAND" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    term)
        term
        ;;
    save)
        save
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
