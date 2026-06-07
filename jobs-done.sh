#!/usr/bin/env bash
# jobs-done.sh — plays a short notification sound to signal that an agent
# finished its work and is now waiting for user input.
#
# Resolves the audio file relative to this script's location, so the skill
# works regardless of where it was installed (project, global, ~/.claude, etc).
#
# Usage:
#   ./jobs-done.sh            # play in background, return immediately
#   ./jobs-done.sh --wait     # block until playback finishes
#   ./jobs-done.sh --help     # show help
#
# Env vars:
#   JOBS_DONE_VOLUME   0.0–2.0+, default 1.0
#   JOBS_DONE_AUDIO    override path to a custom audio file
#
# Exit codes:
#   0 — sound played (or started in background)
#   1 — audio file missing
#   2 — afplay not available (non-macOS system)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_AUDIO="$SCRIPT_DIR/assets/jobs-done.mp3"
AUDIO_FILE="${JOBS_DONE_AUDIO:-$DEFAULT_AUDIO}"
VOLUME="${JOBS_DONE_VOLUME:-1.0}"
WAIT=0

for arg in "$@"; do
  case "$arg" in
    --wait) WAIT=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "jobs-done: unknown argument: $arg" >&2
      exit 64
      ;;
  esac
done

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "jobs-done: audio file not found at $AUDIO_FILE" >&2
  exit 1
fi

if ! command -v afplay >/dev/null 2>&1; then
  echo "jobs-done: afplay not available (this script requires macOS)" >&2
  exit 2
fi

if [[ "$WAIT" -eq 1 ]]; then
  afplay -v "$VOLUME" "$AUDIO_FILE"
else
  (afplay -v "$VOLUME" "$AUDIO_FILE" >/dev/null 2>&1 &) </dev/null
fi

exit 0
