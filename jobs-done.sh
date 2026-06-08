#!/usr/bin/env bash
# jobs-done.sh — plays a short notification sound to signal a state change
# in an AI coding agent's turn.
#
# Modes:
#   done    (default) — agent finished its work and is going idle
#                       → plays assets/jobs-done.mp3
#   input             — agent is blocked and needs your decision/input
#                       → plays assets/your-command-master.mp3
#   mute              — silence all sounds until resume is called
#                       → creates a lockfile in /tmp; no audio plays
#   resume            — re-enable sounds after mute
#                       → removes the lockfile
#   status            — print whether sounds are currently muted
#
# Resolves audio files relative to this script's location, so the skill
# works regardless of where it was installed.
#
# Usage:
#   ./jobs-done.sh                  # done mode (default), play in background
#   ./jobs-done.sh done             # explicit done mode
#   ./jobs-done.sh input            # input-needed mode
#   ./jobs-done.sh mute             # silence sounds until resume
#   ./jobs-done.sh resume           # re-enable sounds
#   ./jobs-done.sh status           # show mute status
#   ./jobs-done.sh done --wait      # block until playback finishes
#   ./jobs-done.sh --help           # show help
#
# Env vars:
#   JOBS_DONE_VOLUME       0.0–2.0+, default 1.0
#   JOBS_DONE_AUDIO_DONE   override path for the "done" sound
#   JOBS_DONE_AUDIO_INPUT  override path for the "input" sound
#   JOBS_DONE_AUDIO        legacy: override "done" sound (still respected)
#   JOBS_DONE_MUTE_FILE    override mute lockfile path (default /tmp/jobs-done-mute)
#
# Exit codes:
#   0  — sound played, started in background, or skipped due to mute
#   1  — audio file missing
#   2  — afplay not available (non-macOS system)
#   64 — unknown argument

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEFAULT_DONE_AUDIO="$SCRIPT_DIR/assets/jobs-done.mp3"
DEFAULT_INPUT_AUDIO="$SCRIPT_DIR/assets/your-command-master.mp3"

DONE_AUDIO="${JOBS_DONE_AUDIO_DONE:-${JOBS_DONE_AUDIO:-$DEFAULT_DONE_AUDIO}}"
INPUT_AUDIO="${JOBS_DONE_AUDIO_INPUT:-$DEFAULT_INPUT_AUDIO}"

MUTE_FILE="${JOBS_DONE_MUTE_FILE:-/tmp/jobs-done-mute}"

VOLUME="${JOBS_DONE_VOLUME:-1.0}"
MODE="done"
WAIT=0

print_help() {
  sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    done|input|mute|resume|status)
      MODE="$1"
      shift
      ;;
    --wait)
      WAIT=1
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "jobs-done: unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

# Handle control modes first.
case "$MODE" in
  mute)
    : > "$MUTE_FILE"
    echo "jobs-done: muted (lockfile: $MUTE_FILE)"
    exit 0
    ;;
  resume)
    if [[ -f "$MUTE_FILE" ]]; then
      rm -f "$MUTE_FILE"
      echo "jobs-done: resumed (lockfile removed)"
    else
      echo "jobs-done: already active (no lockfile to remove)"
    fi
    exit 0
    ;;
  status)
    if [[ -f "$MUTE_FILE" ]]; then
      echo "jobs-done: MUTED (lockfile: $MUTE_FILE)"
    else
      echo "jobs-done: active"
    fi
    exit 0
    ;;
esac

# Playback modes from here on. Check mute first.
if [[ -f "$MUTE_FILE" ]]; then
  # Silent success. Agent should treat this as "sound handled, move on".
  exit 0
fi

case "$MODE" in
  done)  AUDIO_FILE="$DONE_AUDIO" ;;
  input) AUDIO_FILE="$INPUT_AUDIO" ;;
esac

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
