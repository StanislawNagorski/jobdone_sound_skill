#!/usr/bin/env bash
# jobs-done.sh — plays a short notification sound to signal a state change
# in an AI coding agent's turn, AND coordinates with Claude Code hooks so
# subagents never trigger sound and the main agent fires exactly once per
# turn (either auto via Stop hook, or manually as `input`).
#
# User-facing modes:
#   done    (default) — agent finished, going idle → assets/jobs-done.mp3
#   input             — agent blocked, waiting on user → assets/your-command-master.mp3
#   skip              — request that the autofire Stop hook stay silent this turn
#                       (background-acknowledge style; no sound now or later in turn)
#   mute              — silence ALL sounds for this session (lockfile in /tmp)
#   resume            — re-enable sounds (removes lockfile)
#   status            — print whether sounds are currently muted
#
# Hook-facing modes (called from settings.json hooks, not by the model):
#   autofire        — Stop hook: plays `done` unless the model already played
#                     a sound this turn OR requested `skip`. Subagent-aware.
#   subagent-start  — SubagentStart hook: reads JSON on stdin, marks agent_id
#                     as "active" so any jobs-done call from inside that
#                     subagent silently no-ops.
#   subagent-stop   — SubagentStop hook: removes the agent_id marker.
#   session-reset   — SessionStart hook: clears per-turn / per-session state.
#
# Subagent isolation:
#   When called from a subagent (via Task tool) the script is OS-level
#   indistinguishable from a main-agent call — same PID tree, same env vars,
#   same CLAUDE_CODE_SESSION_ID. Detection works by way of marker files
#   written by SubagentStart and removed by SubagentStop hooks. If any
#   subagent marker exists, the calling context IS a subagent, so the call
#   is silently dropped.
#
# State directory:
#   ${TMPDIR:-/tmp}/jobs-done-state/${CLAUDE_CODE_SESSION_ID:-default}/
#     ├── played-this-turn         touched by done/input/skip; checked by autofire
#     ├── skip-this-turn           created by `skip`; tells autofire to no-op
#     └── subagent-${agent_id}     one per running subagent
#
# Usage:
#   ./jobs-done.sh                  # done mode (default)
#   ./jobs-done.sh done             # explicit done
#   ./jobs-done.sh input            # input-needed
#   ./jobs-done.sh skip             # silence this turn (no autofire)
#   ./jobs-done.sh mute             # silence rest of session
#   ./jobs-done.sh resume           # re-enable
#   ./jobs-done.sh status           # show mute status
#   ./jobs-done.sh done --wait      # block until playback finishes
#   ./jobs-done.sh --help           # show help
#
# Env vars:
#   JOBS_DONE_VOLUME       0.0–2.0+, default 1.0
#   JOBS_DONE_AUDIO_DONE   override path for the "done" sound
#   JOBS_DONE_AUDIO_INPUT  override path for the "input" sound
#   JOBS_DONE_AUDIO        legacy alias for JOBS_DONE_AUDIO_DONE
#   JOBS_DONE_MUTE_FILE    override mute lockfile path (default /tmp/jobs-done-mute)
#   JOBS_DONE_STATE_DIR    override per-session state dir
#   JOBS_DONE_STALE_SECS   max age of "played" marker treated as same-turn
#                          (default 120)
#   CLAUDE_CODE_SESSION_ID inherited from Claude Code; scopes state
#
# Exit codes:
#   0  — sound played, started, or skipped (mute / subagent / autofire dedupe)
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

SESSION_KEY="${CLAUDE_CODE_SESSION_ID:-default}"
STATE_ROOT="${JOBS_DONE_STATE_DIR:-${TMPDIR:-/tmp}/jobs-done-state}"
STATE_DIR="$STATE_ROOT/$SESSION_KEY"
PLAYED_MARKER="$STATE_DIR/played-this-turn"
SKIP_MARKER="$STATE_DIR/skip-this-turn"
STALE_SECS="${JOBS_DONE_STALE_SECS:-120}"

VOLUME="${JOBS_DONE_VOLUME:-1.0}"
MODE="done"
WAIT=0

print_help() {
  sed -n '2,55p' "$0" | sed 's/^# \{0,1\}//'
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
}

# Mark "the model played a sound this turn" so the Stop-hook autofire skips.
mark_played() {
  ensure_state_dir
  : > "$PLAYED_MARKER" 2>/dev/null || true
}

# True (0) if any subagent marker is present — meaning we're being called
# from inside a subagent's bash tool and must stay silent.
in_subagent_context() {
  [[ -d "$STATE_DIR" ]] || return 1
  # Glob expands to literal pattern when nothing matches; use compgen guard.
  compgen -G "$STATE_DIR/subagent-*" >/dev/null 2>&1
}

# True (0) if `$1` exists AND was modified within STALE_SECS.
# Uses macOS `stat -f %m` for second-level mtime; this script is macOS-only
# anyway (depends on /usr/bin/afplay).
marker_fresh() {
  local marker="$1"
  [[ -f "$marker" ]] || return 1
  local mtime now age
  mtime="$(stat -f %m "$marker" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  age=$(( now - mtime ))
  (( age >= 0 && age <= STALE_SECS ))
}

played_fresh() { marker_fresh "$PLAYED_MARKER"; }
skip_fresh()   { marker_fresh "$SKIP_MARKER"; }

# Extract a JSON string field from stdin without requiring jq.
# Handles simple "key": "value" pairs; escapes inside strings are not parsed
# (Claude agent_ids are alphanumeric/UUID-like, so this is fine).
read_json_field() {
  local field="$1"
  /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get(sys.argv[1], ""))
except Exception:
    pass
' "$field"
}

play_audio() {
  local audio_file="$1"

  if [[ ! -f "$audio_file" ]]; then
    echo "jobs-done: audio file not found at $audio_file" >&2
    exit 1
  fi

  if ! command -v afplay >/dev/null 2>&1; then
    echo "jobs-done: afplay not available (this script requires macOS)" >&2
    exit 2
  fi

  if [[ "$WAIT" -eq 1 ]]; then
    afplay -v "$VOLUME" "$audio_file"
  else
    (afplay -v "$VOLUME" "$audio_file" >/dev/null 2>&1 &) </dev/null
  fi
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    done|input|skip|mute|resume|status|autofire|subagent-start|subagent-stop|session-reset)
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

# ---------------------------------------------------------------------------
# Hook-facing modes (state management; never produce sound directly).
# These ALWAYS exit 0 — hook failures must not block tool execution.
# ---------------------------------------------------------------------------

case "$MODE" in
  subagent-start)
    # stdin: { ..., "agent_id": "...", "session_id": "..." }
    payload="$(cat)"
    agent_id="$(printf '%s' "$payload" | read_json_field agent_id)"
    sid="$(printf '%s' "$payload" | read_json_field session_id)"
    [[ -n "$sid" ]] && STATE_DIR="$STATE_ROOT/$sid"
    if [[ -n "$agent_id" ]]; then
      mkdir -p "$STATE_DIR" 2>/dev/null || true
      : > "$STATE_DIR/subagent-$agent_id" 2>/dev/null || true
    fi
    exit 0
    ;;
  subagent-stop)
    payload="$(cat)"
    agent_id="$(printf '%s' "$payload" | read_json_field agent_id)"
    sid="$(printf '%s' "$payload" | read_json_field session_id)"
    [[ -n "$sid" ]] && STATE_DIR="$STATE_ROOT/$sid"
    if [[ -n "$agent_id" ]]; then
      rm -f "$STATE_DIR/subagent-$agent_id" 2>/dev/null || true
    fi
    exit 0
    ;;
  session-reset)
    # Optional: clear per-turn markers at session start. Keep subagent
    # markers untouched (a fresh session shouldn't have any, and if some
    # are leftover from a crash, the stale-secs check handles it).
    payload="$(cat 2>/dev/null || true)"
    sid="$(printf '%s' "$payload" | read_json_field session_id)"
    [[ -n "$sid" ]] && STATE_DIR="$STATE_ROOT/$sid"
    rm -f "$STATE_DIR/played-this-turn" "$STATE_DIR/skip-this-turn" 2>/dev/null || true
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Control modes (mute / resume / status)
# ---------------------------------------------------------------------------

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
    if in_subagent_context; then
      echo "jobs-done: subagent context detected (session $SESSION_KEY)"
    fi
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Skip mode (model-facing): suppress this turn's autofire.
# ---------------------------------------------------------------------------

if [[ "$MODE" == "skip" ]]; then
  # Subagent calling `skip` is meaningless — subagent calls are already
  # suppressed wholesale. Still no-op so callers don't error.
  if in_subagent_context; then
    exit 0
  fi
  ensure_state_dir
  : > "$SKIP_MARKER" 2>/dev/null || true
  # Mark "played" too so the autofire path has a single check.
  : > "$PLAYED_MARKER" 2>/dev/null || true
  exit 0
fi

# ---------------------------------------------------------------------------
# Mute lockfile applies to all sound-producing paths from here on.
# ---------------------------------------------------------------------------

if [[ -f "$MUTE_FILE" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Subagent isolation: any sound call from inside a subagent is dropped.
# ---------------------------------------------------------------------------

if in_subagent_context; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Autofire (Stop hook): play `done` unless model already handled it.
# ---------------------------------------------------------------------------

if [[ "$MODE" == "autofire" ]]; then
  if skip_fresh; then
    rm -f "$SKIP_MARKER" "$PLAYED_MARKER" 2>/dev/null || true
    exit 0
  fi
  if played_fresh; then
    rm -f "$PLAYED_MARKER" 2>/dev/null || true
    exit 0
  fi
  play_audio "$DONE_AUDIO"
  exit 0
fi

# ---------------------------------------------------------------------------
# Model-facing done / input
# ---------------------------------------------------------------------------

case "$MODE" in
  done)  AUDIO_FILE="$DONE_AUDIO" ;;
  input) AUDIO_FILE="$INPUT_AUDIO" ;;
esac

mark_played
play_audio "$AUDIO_FILE"

exit 0
