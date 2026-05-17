#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-Combat_Sentry2026}"
WORKSPACE="${WORKSPACE:-/root/Combat_Sentry2026/sentry_nav_ws}"
TERMINAL_BIN="${TERMINAL_BIN:-gnome-terminal}"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

COMMANDS=(
  "ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py"
  "ros2 launch pb2025_nav_bringup odin1_ros2.launch.py"
  "ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py"
)

LABELS=(
  "serial"
  "odin1"
  "nav"
)

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

wait_for_docker() {
  local attempt
  for attempt in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "Docker daemon is not ready after waiting." >&2
  return 1
}

start_docker_if_needed() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    echo "Docker is not ready; trying to start docker.service..."
    sudo systemctl start docker || true
  fi

  wait_for_docker
}

build_container_script() {
  local label="$1"
  local prefill_command="$2"

  cat <<EOF
source /opt/ros/humble/setup.bash
cd "$WORKSPACE"
if [ -f install/setup.bash ]; then source install/setup.bash; fi
printf '\\nReady: $CONTAINER @ $WORKSPACE\\n'
printf 'Command is prefilled but not running. Press Enter to start, or edit it first.\\n\\n'
if read -e -i $(shell_quote "$prefill_command") -p "[$label] run> " command_to_run; then
  if [ -n "\$command_to_run" ]; then
    eval "\$command_to_run"
  fi
fi
exec bash -i
EOF
}

open_terminal_with_prefill() {
  local label="$1"
  local prefill_command="$2"
  local container_script

  container_script="$(build_container_script "$label" "$prefill_command")"

  "$TERMINAL_BIN" \
    --title "$label - $CONTAINER" \
    -- docker exec -it "$CONTAINER" bash -lc "$container_script" &
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Platform: Ubuntu/Linux"
  echo "Terminal: $TERMINAL_BIN"
  echo "Container: $CONTAINER"
  echo "Workspace: $WORKSPACE"
  echo
  echo "Commands to prefill without running:"
  for index in "${!COMMANDS[@]}"; do
    echo "- ${LABELS[$index]}: ${COMMANDS[$index]}"
  done
  exit 0
fi

if [ "$(uname -s)" != "Linux" ]; then
  echo "This script is intended for Ubuntu/Linux." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command was not found." >&2
  exit 1
fi

if ! command -v "$TERMINAL_BIN" >/dev/null 2>&1; then
  echo "$TERMINAL_BIN was not found. Install it or set TERMINAL_BIN=<terminal>." >&2
  exit 1
fi

start_docker_if_needed

if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Container not found: $CONTAINER" >&2
  exit 1
fi

docker start "$CONTAINER" >/dev/null

for index in "${!COMMANDS[@]}"; do
  open_terminal_with_prefill "${LABELS[$index]}" "${COMMANDS[$index]}"
done

echo "Opened ${#COMMANDS[@]} terminal windows for $CONTAINER."
echo "Each command is prefilled but not running. Press Enter in each terminal when ready."
