#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  echo "setup_nav_aliases.sh must be run or sourced by bash." >&2
  return 1 2>/dev/null || exit 1
fi

SENTRY_NAV_ALIASES_SOURCED=0
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  SENTRY_NAV_ALIASES_SOURCED=1
fi

SENTRY_NAV_ALIASES_SHELL_OPTS="$(set +o)"
set -euo pipefail

BASHRC="${1:-$HOME/.bashrc}"
START_MARKER="# >>> combat sentry nav aliases >>>"
END_MARKER="# <<< combat sentry nav aliases <<<"

mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

if [ -s "$BASHRC" ]; then
  backup="${BASHRC}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$BASHRC" "$backup"
  echo "Backup written to: $backup"
fi

tmp_file="$(mktemp)"
awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { skip = 1; next }
  $0 == end { skip = 0; next }
  !skip { print }
' "$BASHRC" > "$tmp_file"

write_alias_block() {
  cat <<'ALIASES'

# >>> combat sentry nav aliases >>>
unalias build serial odin1 odinslam nav navrviz rviz behav saveodinmap odinmapsaver 2>/dev/null || true
unset -f _sentry_ws_src mapsaver odinslam_mapsaver odinslam_savemap 2>/dev/null || true

alias build='colcon build --symlink-install'
alias serial='ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py'
alias odin1='ros2 launch pb2025_nav_bringup odin1_ros2.launch.py'
alias odinslam='ros2 launch pb2025_nav_bringup odin_slam_launch.py'
alias nav='ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py'
alias navrviz='ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py use_rviz:=True'
alias rviz='ros2 launch pb2025_nav_bringup rviz_launch.py'
alias behav='ros2 launch combat_sentry_behavior combat_sentry_behavior_launch.py'
alias saveodinmap='odinslam_savemap'
alias odinmapsaver='odinslam_mapsaver'

_sentry_ws_src() {
  local candidates=()
  local dir

  if [ -n "${SENTRY_WS_SRC:-}" ]; then
    candidates+=("$SENTRY_WS_SRC")
  fi

  candidates+=(
    "$PWD/src"
    "$PWD"
    "$PWD/.."
    "$PWD/../.."
    "$PWD/sentry_nav_ws"
    "/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws"
    "/root/Combat_Sentry2026/sentry_nav_ws/src"
    "/root/Combat_Sentry2026/sentry_nav_ws"
  )

  for dir in "${candidates[@]}"; do
    if [ -d "$dir/combat_sentry_nav/pb2025_nav_bringup/map/reality" ]; then
      printf '%s\n' "$dir"
      return 0
    fi

    if [ -d "$dir/pb2025_nav_bringup/map/reality" ] && [ -d "$dir/odin_ros_driver" ]; then
      (cd "$dir/.." && pwd)
      return 0
    fi
  done

  printf '%s\n' "/root/Combat_Sentry2026/sentry_nav_ws/src"
}

mapsaver() {
  local ws_src
  local map_name
  local map_file
  local namespace_args=()

  ws_src="$(_sentry_ws_src)"
  map_name="${1:-${MAP_WORLD:-rmuc2026}}"
  map_name="${map_name%.yaml}"
  map_name="${map_name%.pgm}"

  if [[ "$map_name" == /* || "$map_name" == */* ]]; then
    map_file="$map_name"
  else
    map_file="$ws_src/combat_sentry_nav/pb2025_nav_bringup/map/reality/$map_name"
  fi

  mkdir -p "$(dirname "$map_file")"

  if [ -n "${MAP_NAMESPACE:-}" ]; then
    namespace_args=(--ros-args -r "__ns:=${MAP_NAMESPACE}")
  fi

  ros2 run nav2_map_server map_saver_cli -f "$map_file" "${namespace_args[@]}"
}

odinslam_mapsaver() {
  mapsaver "$@"
}

odinslam_savemap() {
  local ws_src
  local driver_dir

  ws_src="$(_sentry_ws_src)"
  driver_dir="$ws_src/combat_sentry_nav/odin_ros_driver"

  if [ ! -f "$driver_dir/set_param.sh" ]; then
    echo "Cannot find odin_ros_driver/set_param.sh under: $ws_src" >&2
    return 1
  fi

  (cd "$driver_dir" && bash ./set_param.sh save_map 1)
  echo "Odin SLAM map save requested. Configured output defaults to: $driver_dir/map/odin_relocalization_map.bin"
}
# <<< combat sentry nav aliases <<<
ALIASES
}

write_alias_block >> "$tmp_file"

mv "$tmp_file" "$BASHRC"

echo "Aliases installed into: $BASHRC"
if [ "$SENTRY_NAV_ALIASES_SOURCED" -eq 1 ]; then
  eval "$(write_alias_block)"
  echo "Current shell aliases refreshed."
else
  echo "Run: source $BASHRC"
  echo "For this terminal immediately: source ${BASH_SOURCE[0]}"
fi

sentry_nav_aliases_should_return="$SENTRY_NAV_ALIASES_SOURCED"
eval "$SENTRY_NAV_ALIASES_SHELL_OPTS"
unset SENTRY_NAV_ALIASES_SOURCED SENTRY_NAV_ALIASES_SHELL_OPTS
unset -f write_alias_block

if [ "$sentry_nav_aliases_should_return" -eq 1 ]; then
  unset sentry_nav_aliases_should_return
  return 0
fi
unset sentry_nav_aliases_should_return
