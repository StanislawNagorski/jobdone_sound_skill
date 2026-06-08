#!/usr/bin/env bash
# install.sh — set up jobs-done so it auto-loads in every Claude Code and
# opencode session. Safe to re-run (idempotent).
#
# What it does:
#   1. Installs the skill files into ~/.claude/skills/jobs-done and
#      ~/.config/opencode/skills/jobs-done (clone or update).
#   2. Installs slash commands /jobs-done-mute and /jobs-done-resume for
#      both Claude Code and opencode.
#   3. Patches ~/.claude/settings.json to add a SessionStart hook that
#      injects SKILL.md into every Claude Code session.
#   4. Patches ~/.config/opencode/opencode.json to add SKILL.md to the
#      `instructions` array (auto-loaded by opencode).
#   5. Appends an "auto-load skills" reminder to ~/.claude/CLAUDE.md and
#      ~/.config/opencode/AGENTS.md as a fallback.
#
# Skips Claude Code or opencode setup automatically if the relevant
# config directory does not exist.
#
# Usage:
#   ./install.sh                 # install from this local directory
#   curl -sSL <url>/install.sh | bash    # install from a remote checkout
#
# Re-run the script after updating the repo (e.g. git pull) to refresh
# the installed skill and slash commands. Hooks and config patches are
# detected and not duplicated.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

REPO_URL="https://github.com/StanislawNagorski/jobdone_sound_skill.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If install.sh is being piped in (no local checkout), clone to a temp dir.
if [[ -f "$SCRIPT_DIR/SKILL.md" && -f "$SCRIPT_DIR/jobs-done.sh" ]]; then
  SOURCE_DIR="$SCRIPT_DIR"
  echo "[1/6] Using local checkout: $SOURCE_DIR"
else
  SOURCE_DIR="$(mktemp -d -t jobs-done-install.XXXXXX)"
  echo "[1/6] No local checkout. Cloning $REPO_URL into $SOURCE_DIR"
  git clone --depth 1 "$REPO_URL" "$SOURCE_DIR"
fi

CLAUDE_HOME="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_HOME/skills/jobs-done"
CLAUDE_COMMANDS_DIR="$CLAUDE_HOME/commands"
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
CLAUDE_AGENTS_MD="$CLAUDE_HOME/CLAUDE.md"

OPENCODE_HOME="$HOME/.config/opencode"
OPENCODE_SKILLS_DIR="$OPENCODE_HOME/skills/jobs-done"
OPENCODE_COMMANDS_DIR="$OPENCODE_HOME/command"
OPENCODE_CONFIG="$OPENCODE_HOME/opencode.json"
OPENCODE_AGENTS_MD="$OPENCODE_HOME/AGENTS.md"

INSTALL_CLAUDE=1
INSTALL_OPENCODE=1

if [[ ! -d "$CLAUDE_HOME" ]]; then
  echo "  - Claude Code not detected ($CLAUDE_HOME missing). Skipping."
  INSTALL_CLAUDE=0
fi
if [[ ! -d "$OPENCODE_HOME" ]]; then
  echo "  - opencode not detected ($OPENCODE_HOME missing). Skipping."
  INSTALL_OPENCODE=0
fi

if [[ "$INSTALL_CLAUDE" -eq 0 && "$INSTALL_OPENCODE" -eq 0 ]]; then
  echo "Neither Claude Code nor opencode is installed. Nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PYTHON_BIN="/usr/bin/python3"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3 || true)"
fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "ERROR: python3 not found. macOS should have /usr/bin/python3 via Xcode CLT." >&2
  exit 1
fi

backup_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  cp "$path" "${path}.jobs-done-backup.${stamp}"
}

install_skill_dir() {
  local target_root="$1"
  local target_dir="$target_root/jobs-done"
  mkdir -p "$target_root"
  if [[ -d "$target_dir" ]]; then
    echo "  - Updating skill at $target_dir"
    rm -rf "$target_dir"
  else
    echo "  - Installing skill into $target_dir"
  fi
  # Copy everything except git internals.
  mkdir -p "$target_dir"
  (cd "$SOURCE_DIR" && \
    find . \
      \( -path './.git' -o -path './.git/*' \) -prune -o \
      -type f -print | while read -r f; do
        rel="${f#./}"
        mkdir -p "$target_dir/$(dirname "$rel")"
        cp "$SOURCE_DIR/$rel" "$target_dir/$rel"
      done)
  chmod +x "$target_dir/jobs-done.sh"
}

install_claude_commands() {
  mkdir -p "$CLAUDE_COMMANDS_DIR"
  cp "$SOURCE_DIR/commands/claude/jobs-done-mute.md" \
     "$CLAUDE_COMMANDS_DIR/jobs-done-mute.md"
  cp "$SOURCE_DIR/commands/claude/jobs-done-resume.md" \
     "$CLAUDE_COMMANDS_DIR/jobs-done-resume.md"
  echo "  - Installed /jobs-done-mute and /jobs-done-resume slash commands"
}

install_opencode_commands() {
  mkdir -p "$OPENCODE_COMMANDS_DIR"
  cp "$SOURCE_DIR/commands/opencode/jobs-done-mute.md" \
     "$OPENCODE_COMMANDS_DIR/jobs-done-mute.md"
  cp "$SOURCE_DIR/commands/opencode/jobs-done-resume.md" \
     "$OPENCODE_COMMANDS_DIR/jobs-done-resume.md"
  echo "  - Installed /jobs-done-mute and /jobs-done-resume slash commands"
}

patch_claude_settings() {
  local skill_path="$CLAUDE_SKILLS_DIR/SKILL.md"
  local script_path="$CLAUDE_SKILLS_DIR/jobs-done.sh"

  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    echo '{"hooks":{}}' > "$CLAUDE_SETTINGS"
  fi

  "$PYTHON_BIN" - "$CLAUDE_SETTINGS" "$skill_path" "$script_path" <<'PY'
import json, sys

settings_path = sys.argv[1]
skill_path = sys.argv[2]
script_path = sys.argv[3]

with open(settings_path, "r") as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})

def cmd_in_event(event_name, needle, prefix=None):
    """Return True if any existing hook command in this event contains `needle`
    (optionally, also starting with `prefix`)."""
    for entry in hooks.get(event_name, []) or []:
        for inner in entry.get("hooks") or []:
            cmd = inner.get("command", "")
            if needle in cmd and (prefix is None or cmd.lstrip().startswith(prefix)):
                return True
    return False

def append_command_hook(event_name, command):
    arr = hooks.setdefault(event_name, [])
    arr.append({"hooks": [{"type": "command", "command": command}]})

changes = []

# SessionStart: inject SKILL.md (skill content) + reset per-turn state.
if not cmd_in_event("SessionStart", skill_path, prefix="cat"):
    append_command_hook("SessionStart", f'cat "{skill_path}"')
    changes.append("SessionStart: inject SKILL.md")

reset_cmd = f'bash "{script_path}" session-reset'
if not cmd_in_event("SessionStart", "jobs-done.sh", prefix="bash"):
    append_command_hook("SessionStart", reset_cmd)
    changes.append("SessionStart: reset per-turn markers")

# Stop: autofire `done` sound at the end of every main-agent turn.
autofire_cmd = f'bash "{script_path}" autofire'
if not cmd_in_event("Stop", "jobs-done.sh"):
    append_command_hook("Stop", autofire_cmd)
    changes.append("Stop: autofire done sound")

# SubagentStart: mark agent_id as active so jobs-done.sh calls from inside
# the subagent silently no-op.
sub_start_cmd = f'bash "{script_path}" subagent-start'
if not cmd_in_event("SubagentStart", "jobs-done.sh"):
    append_command_hook("SubagentStart", sub_start_cmd)
    changes.append("SubagentStart: mark subagent active")

# SubagentStop: clear the agent_id marker.
sub_stop_cmd = f'bash "{script_path}" subagent-stop'
if not cmd_in_event("SubagentStop", "jobs-done.sh"):
    append_command_hook("SubagentStop", sub_stop_cmd)
    changes.append("SubagentStop: clear subagent marker")

if not changes:
    print("  - All Claude Code hooks already present")
else:
    with open(settings_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    for c in changes:
        print(f"  - Added hook: {c}")
PY
}

patch_opencode_config() {
  local skill_path="$OPENCODE_SKILLS_DIR/SKILL.md"

  if [[ ! -f "$OPENCODE_CONFIG" ]]; then
    cat > "$OPENCODE_CONFIG" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json"
}
JSON
  fi

  "$PYTHON_BIN" - "$OPENCODE_CONFIG" "$skill_path" <<'PY'
import json, sys

path = sys.argv[1]
skill_path = sys.argv[2]

with open(path, "r") as f:
    data = json.load(f)

if "$schema" not in data:
    data["$schema"] = "https://opencode.ai/config.json"

instructions = data.setdefault("instructions", [])
if skill_path in instructions:
    print("  - opencode `instructions` already contains SKILL.md")
    sys.exit(0)

instructions.append(skill_path)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("  - Added SKILL.md to opencode.json `instructions`")
PY
}

append_agents_section() {
  local file="$1"
  local label="$2"
  local marker="<!-- jobs-done:auto-load -->"

  if [[ -f "$file" ]] && grep -q "$marker" "$file" 2>/dev/null; then
    echo "  - $label already has jobs-done auto-load section"
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  if [[ ! -f "$file" ]]; then
    printf "# Agent instructions\n\n" > "$file"
  fi

  cat >> "$file" <<'MARKER'

<!-- jobs-done:auto-load -->
## Auto-load skills (every session)

At the start of **every** session, treat the `jobs-done` skill as already
loaded. Its content is injected automatically (via a SessionStart hook in
Claude Code or via the `instructions` array in opencode). In case the
injection ever fails, invoke the `jobs-done` skill yourself as the very
first tool call of the session before doing anything else.

Why: the skill must be active so an audio "ping" plays at the end of every
turn (`done` when the session is truly idle, `input` when you need a
decision from the user). Never end a turn silently unless the skill
explicitly calls for a silent case.
<!-- /jobs-done:auto-load -->
MARKER

  echo "  - Appended jobs-done auto-load section to $label"
}

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------

if [[ "$INSTALL_CLAUDE" -eq 1 ]]; then
  echo
  echo "[2/6] Installing skill files for Claude Code"
  install_skill_dir "$CLAUDE_HOME/skills"

  echo "[3/6] Installing slash commands for Claude Code"
  install_claude_commands

  echo "[4/6] Patching $CLAUDE_SETTINGS"
  backup_file "$CLAUDE_SETTINGS"
  patch_claude_settings

  echo "[5/6] Patching $CLAUDE_AGENTS_MD"
  backup_file "$CLAUDE_AGENTS_MD"
  append_agents_section "$CLAUDE_AGENTS_MD" "CLAUDE.md"
fi

# ---------------------------------------------------------------------------
# opencode
# ---------------------------------------------------------------------------

if [[ "$INSTALL_OPENCODE" -eq 1 ]]; then
  echo
  echo "[2/6] Installing skill files for opencode"
  install_skill_dir "$OPENCODE_HOME/skills"

  echo "[3/6] Installing slash commands for opencode"
  install_opencode_commands

  echo "[4/6] Patching $OPENCODE_CONFIG"
  backup_file "$OPENCODE_CONFIG"
  patch_opencode_config

  echo "[5/6] Patching $OPENCODE_AGENTS_MD"
  backup_file "$OPENCODE_AGENTS_MD"
  append_agents_section "$OPENCODE_AGENTS_MD" "AGENTS.md"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo
echo "[6/6] Smoke test"
if [[ "$INSTALL_CLAUDE" -eq 1 ]]; then
  "$CLAUDE_SKILLS_DIR/jobs-done.sh" status
fi
if [[ "$INSTALL_OPENCODE" -eq 1 ]]; then
  "$OPENCODE_SKILLS_DIR/jobs-done.sh" status
fi

echo
echo "Installed."
echo
echo "Next steps:"
echo "  1. Quit and restart Claude Code and/or opencode."
echo "  2. In any new session, type '/jobs-done-mute' to silence sounds,"
echo "     '/jobs-done-resume' to re-enable them."
echo "  3. To uninstall, run ./uninstall.sh from this repo."
