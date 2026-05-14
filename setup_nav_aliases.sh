#!/usr/bin/env bash
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

cat >> "$tmp_file" <<'ALIASES'

# >>> combat sentry nav aliases >>>
alias build='colcon build --symlink-install'
alias serial='ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py'
alias odin1='ros2 launch pb2025_nav_bringup odin1_ros2.launch.py'
alias nav='ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py'
alias behav='ros2 launch combat_sentry_behavior combat_sentry_behavior_launch.py'
# <<< combat sentry nav aliases <<<
ALIASES

mv "$tmp_file" "$BASHRC"

echo "Aliases installed into: $BASHRC"
echo "Run: source $BASHRC"
