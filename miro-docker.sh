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

# --- Settings ---
DISPLAY="${DISPLAY:-:0}"
BASE_IMAGE_NAME="${IMAGE_NAME:-alexandrlucas/miro-docker}"
BASE_IMAGE_TAG="${IMAGE_TAG:-latest}"
BASE_CONTAINER_NAME="${CONTAINER_NAME:-miro-docker}"

COMMAND=${1:-}

# --- Show usage ---
show_usage() {
    grep '^#/' "$0" | cut -c4-
}

if [ -z "$COMMAND" ] || [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
    show_usage
    exit 0
fi

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

get_compose_file() {
    local uname_out env gpu candidates=()
    uname_out="$(uname -s 2>/dev/null || echo Unknown)"

    case "$uname_out" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                env="wsl"
            else
                env="linux"
            fi ;;
        Darwin*) env="mac" ;;
        MINGW*|MSYS*|CYGWIN*) env="windows" ;;
        *) env="unknown" ;;
    esac

    if command -v nvidia-smi >/dev/null 2>&1 || lspci 2>/dev/null | grep -qi nvidia; then
        gpu="nvidia"
    elif lspci 2>/dev/null | grep -qiE 'amd|advanced micro devices'; then
        gpu="amd"
    else
        gpu="none"
    fi

    case "$env" in
        mac) candidates=("compose.mac.yaml" "compose.yaml") ;;
        windows|wsl|linux)
            candidates+=(
                "compose.${env}.nvidia.yaml"
                "compose.${env}.amd.yaml"
                "compose.${env}.yaml"
                "compose.yaml"
            ) ;;
        *) candidates=("compose.yaml") ;;
    esac

    for f in "${candidates[@]}"; do
        [[ -f "$f" ]] && echo "$f" && return 0
    done
    echo "compose.yaml"
}

# --- FIXED: Use `docker ps --filter` instead of `docker compose ps` ---
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
        exit 1
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
        echo "✅ Pulled $IMAGE."
    elif docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "⚠️ Using local $IMAGE."
    else
        echo "⚠️ Building from Dockerfile..."
        docker build --progress=plain --no-cache -t "$IMAGE" .
    fi

    read -r -p "Customise container name [leave blank for $BASE_CONTAINER_NAME]: " C_NAME
    CONTAINER_NAME="${C_NAME:-$BASE_CONTAINER_NAME}"
    export CONTAINER_NAME

    echo "🚀 Starting $CONTAINER_NAME using $COMPOSE_FILE..."
    dc up -d --build

    CID=$(get_container_id "$CONTAINER_NAME")
    echo "✅ Started $CONTAINER_NAME (ID: $CID)."

    # WSL2: Enable X11
    if grep -qi microsoft /proc/version 2>/dev/null && command -v xhost >/dev/null 2>&1; then
        xhost +local:docker >/dev/null 2>&1 || true
        echo "🔓 X11 access enabled."
    fi

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

    dc down --remove-orphans
    echo "✅ Stopped and removed."
}

# --- Attach shell ---
term() {
    COMPOSE_FILE=$(get_compose_file)
    local name="${CONTAINER_NAME:-$BASE_CONTAINER_NAME}"
    CID=$(get_container_id "$name") || return 1

    echo "🔗 Attaching to $name ($CID). Ctrl+D to exit."
    docker exec -it "$CID" /bin/bash
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
    docker commit "$CID" "$NEW_IMAGE"
    echo "✅ Saved as $NEW_IMAGE"
}

# --- Command dispatcher ---
case "$COMMAND" in
    start) start ;;
    stop)  stop ;;
    term)  term ;;
    save)  save ;;
    *)
        echo "❌ Invalid command: $COMMAND"
        echo
        show_usage
        exit 1
        ;;
esac