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
#   start   - Pull/build the Docker image (if needed) and start a container.
#             Prompts for image name/tag and container name.
#   stop    - Stop and remove the last started container. Prompts for confirmation.
#   term    - Attach an interactive shell to the last running container.
#   save    - Commit the last running container to a new image.
#             Prompts for a snapshot tag (default: timestamped).
#
# Environment Variables (optional):
#   IMAGE_NAME        - Default image name (overrides BASE_IMAGE_NAME)
#   IMAGE_TAG         - Default image tag (overrides BASE_IMAGE_TAG)
#   CONTAINER_NAME    - Default container name (overrides BASE_CONTAINER_NAME)
#   DISPLAY           - X server display for GUI apps (defaults to ":0")
#
# Files:
#   compose.yaml      - Docker Compose file, must exist in script folder
#   Dockerfile        - Used to build local image if not found in registry
#   ~/.designated_container - Stores last container ID for 'term', 'stop', and 'save'
#
# Examples:
#   ./miro-docker.sh start
#   ./miro-docker.sh term
#   ./miro-docker.sh save
#   ./miro-docker.sh stop
#
# Notes:
#   - Requires Docker and Docker Compose installed.
#   - For GUI apps, ensure DISPLAY is set and xhost allows local access.
#   - Designed to be launched via a wrapper/alias (e.g., 'miro-hub')

set -euo pipefail

# --- Default environment variables ---
DISPLAY="${DISPLAY:-:0}"
BASE_IMAGE_NAME="${IMAGE_NAME:-alexandrlucas/miro-docker}"
BASE_IMAGE_TAG="${IMAGE_TAG:-latest}"
BASE_CONTAINER_NAME="${CONTAINER_NAME:-miro-docker}"
CONTAINER_FILE="$HOME/.designated_container"
COMPOSE_FILE="compose.yaml"

COMMAND=${1:-}

# --- Show usage function ---
show_usage() {
    head -n 40 "$0"
}

# Show usage if no command or --help/-h
if [ -z "$COMMAND" ] || [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
    show_usage
    exit 0
fi

# --- Utility functions ---
ask_confirm() {
    local prompt="${1:-Are you sure?}"
    echo -n "$prompt [yes/no]: "
    read -r answer
    if [[ "$answer" != "yes" ]]; then
        echo "❌ Aborted."
        return 1
    fi
    return 0
}

check_running() {
    if [ ! -f "$CONTAINER_FILE" ]; then
        echo "❌ No running container recorded."
        return 1
    fi
    local cid
    cid=$(<"$CONTAINER_FILE")
    if [ -z "$cid" ]; then
        echo "❌ No container ID found in $CONTAINER_FILE."
        return 1
    fi
    # Check if container is actually running
    if ! docker ps -q --no-trunc | grep -q "$cid"; then
        echo "❌ Container $cid is not running."
        return 1
    fi
    echo "$cid"
    return 0
}

# --- Start container ---
start() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ $COMPOSE_FILE not found in current directory."
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

    if docker pull "$IMAGE"; then
        echo "✅ Pulled/updated $IMAGE from registry."
    elif docker image inspect "$IMAGE"; then
        echo "⚠️ Could not pull, but local image $IMAGE exists. Using it."
    else
        echo "⚠️ No registry image found and no local copy. Building from Dockerfile..."
        docker build --progress=plain --no-cache -t "$IMAGE" .
    fi

    read -r -p "Customise container name [leave blank for $BASE_CONTAINER_NAME]: " C_NAME
    CONTAINER_NAME="${C_NAME:-$BASE_CONTAINER_NAME}"
    export CONTAINER_NAME

    if [ -n "${DISPLAY-}" ]; then
        echo "🔓 Allowing Docker to access X server on $DISPLAY..."
        xhost +local:docker >/dev/null || echo "⚠️ Could not modify X server access."
    else
        echo "⚠️ DISPLAY not set. GUI apps may not work."
    fi

    echo "🚀 Starting container $CONTAINER_NAME using image $IMAGE..."
# ------------------------------------------------------------------------------
    docker compose -f "$COMPOSE_FILE" up -d --build
# ------------------------------------------------------------------------------
    CID=$(docker ps -q --filter "name=$CONTAINER_NAME" --no-trunc | head -n1)
    echo "$CID" > "$CONTAINER_FILE"

    echo "✅ Container $CONTAINER_NAME with ID $CID started successfully."
    echo "💡 Tip: Use 'term' to attach a shell, 'save' to snapshot, 'stop' to remove."

    #TODO: multi-container support
}

# --- Stop container ---
stop() {
    CID=$(check_running 2>/dev/null) || { echo "⚠️ No running containers to stop."; return; }

    echo "⚠️ WARNING: This will remove the container. Any unsaved changes will be lost."
    if ! ask_confirm "Do you really want to proceed? Type 'yes' to continue."; then
        return
    fi

    echo "🛑 Stopping container $CID..."
# ------------------------------------------------------------------------------
    docker compose -f "$COMPOSE_FILE" down
# ------------------------------------------------------------------------------
    echo "✅ Containers stopped."
}

# --- Attach shell to last used container ---
term() {
    CID=$(check_running 2>/dev/null) || { echo "⚠️ Cannot attach: no running containers."; return; }

    echo "💡 Reminder: When done, save your work with 'save' or stop the container using 'stop'."
    echo "🔗 Attaching shell to container $CID. Press CTRL+D to exit."

    # Detect if NVIDIA runtime is available
    if docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
        GPU_ENV=(
            -e NVIDIA_VISIBLE_DEVICES=all
            -e NVIDIA_DRIVER_CAPABILITIES=all
        )
    else
        echo "⚙️ NVIDIA runtime not found — continuing without GPU support."
        GPU_ENV=()
    fi
# ------------------------------------------------------------------------------
    docker exec -it --privileged \
        -e DISPLAY="${DISPLAY}" \
        -e XDG_RUNTIME_DIR="/run/user/${USER_UID}" \
        -e PULSE_SERVER="unix:/run/user/${USER_UID}/pulse/native" \
        -e QT_X11_NO_MITSHM=1 \
        -e GDK_BACKEND=x11 \
        -e GDK_DISABLE_XSHM=1 \
        "${GPU_ENV[@]}" \
        "$CID" /bin/bash
# ------------------------------------------------------------------------------
}

# --- Save container state as new image ---
save() {
    CID=$(check_running 2>/dev/null) || { echo "⚠️ Cannot save: no running containers."; return; }

    IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CID" 2>/dev/null | cut -d':' -f1)

    read -r -p "Enter snapshot tag [default: timestamped]: " SNAPSHOT_TAG
    SNAPSHOT_TAG="${SNAPSHOT_TAG:-$(date +%Y%m%d_%H%M%S)}"
    IMAGE="$IMAGE_NAME:snapshot_${SNAPSHOT_TAG}"

    docker commit "$CID" "$IMAGE"
    echo "✅ Container $CID saved as image: $IMAGE"
}

# --- Command dispatcher ---
case $COMMAND in
    start) start ;;
    stop) stop ;;
    term) term ;;
    save) save ;;
    *)
        echo "❌ Invalid input."
        echo
        show_usage
        exit 1
        ;;
esac
