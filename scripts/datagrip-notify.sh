#!/bin/bash
set -euo pipefail

WATCH_DIR="$HOME/Library/Application Support/WorkPet/datagrip-tasks"
mkdir -p "$WATCH_DIR"

TITLE="${1:-DataGrip 任务完成}"
BODY="${2:-任务已执行完毕。}"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="$WATCH_DIR/datagrip-$STAMP.txt"

{
  printf '%s\n' "$TITLE"
  printf '%s\n' "$BODY"
} > "$FILE"

echo "WorkPet notification queued: $FILE"

