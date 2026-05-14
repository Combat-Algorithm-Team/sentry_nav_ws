#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-Combat_Sentry2026}"
WORKSPACE="${WORKSPACE:-/root/Combat_Sentry2026/sentry_nav_ws}"
DOCKER_APP="${DOCKER_APP:-Docker}"
TYPE_DELAY_SEC="${TYPE_DELAY_SEC:-2}"

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

open_terminal_with_prefill() {
  local terminal_command="$1"
  local prefill_command="$2"
  local label="$3"

  osascript - "$terminal_command" "$prefill_command" "$label" "$TYPE_DELAY_SEC" <<'APPLESCRIPT'
on run argv
  set terminalCommand to item 1 of argv
  set prefillCommand to item 2 of argv
  set windowLabel to item 3 of argv
  set delaySeconds to item 4 of argv as number

  tell application "Terminal"
    activate
    do script terminalCommand
  end tell

  delay delaySeconds

  tell application "System Events"
    tell process "Terminal"
      keystroke prefillCommand
    end tell
  end tell
end run
APPLESCRIPT
}

container_bootstrap=$(cat <<EOF
source /opt/ros/humble/setup.bash
cd "$WORKSPACE"
if [ -f install/setup.bash ]; then source install/setup.bash; fi
printf '\\nReady: $CONTAINER @ $WORKSPACE\\n'
exec bash -i
EOF
)

terminal_command="docker exec -it $(shell_quote "$CONTAINER") bash -lc $(shell_quote "$container_bootstrap")"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Docker app: $DOCKER_APP"
  echo "Container: $CONTAINER"
  echo "Workspace: $WORKSPACE"
  echo
  echo "Terminal enter command:"
  echo "$terminal_command"
  echo
  echo "Commands to prefill without pressing Enter:"
  for index in "${!COMMANDS[@]}"; do
    echo "- ${LABELS[$index]}: ${COMMANDS[$index]}"
  done
  exit 0
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script uses macOS Terminal.app automation and must run on macOS." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command was not found." >&2
  exit 1
fi

if ! command -v osascript >/dev/null 2>&1; then
  echo "osascript command was not found." >&2
  exit 1
fi

open -ga "$DOCKER_APP"
wait_for_docker

if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Container not found: $CONTAINER" >&2
  exit 1
fi

docker start "$CONTAINER" >/dev/null

for index in "${!COMMANDS[@]}"; do
  open_terminal_with_prefill "$terminal_command" "${COMMANDS[$index]}" "${LABELS[$index]}"
done

echo "Opened ${#COMMANDS[@]} Terminal windows for $CONTAINER."
echo "Commands were typed but not executed. Press Enter in each terminal when ready."
