#!/usr/bin/env bash
# uninstall.sh — remove everything install.sh added.
#
# Removes:
#   - skill directories ~/.claude/skills/jobs-done and
#     ~/.config/opencode/skills/jobs-done
#   - slash commands jobs-done-mute, jobs-done-resume from both clients
#   - the SessionStart hook entry from ~/.claude/settings.json
#   - the SKILL.md entry from `instructions` in ~/.config/opencode/opencode.json
#   - the auto-load section (marked with HTML comments) from CLAUDE.md and
#     AGENTS.md
#   - the mute lockfile /tmp/jobs-done-mute, if any
#
# Leaves alone:
#   - your existing settings.json / opencode.json / CLAUDE.md / AGENTS.md
#     content that is not jobs-done related
#   - any backups install.sh created (*.jobs-done-backup.*)
#
# Re-runnable. Safe to call even if nothing is installed.

set -euo pipefail

PYTHON_BIN="/usr/bin/python3"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3 || true)"
fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "ERROR: python3 not found." >&2
  exit 1
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

backup_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  cp "$path" "${path}.jobs-done-backup.${stamp}"
}

remove_skill_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    rm -rf "$dir"
    echo "  - Removed $dir"
  fi
}

remove_slash_commands() {
  local dir="$1"
  for name in jobs-done-mute jobs-done-resume; do
    for ext in md json; do
      if [[ -f "$dir/$name.$ext" ]]; then
        rm -f "$dir/$name.$ext"
        echo "  - Removed $dir/$name.$ext"
      fi
    done
  done
}

unpatch_claude_settings() {
  [[ -f "$CLAUDE_SETTINGS" ]] || return 0
  backup_file "$CLAUDE_SETTINGS"

  "$PYTHON_BIN" - "$CLAUDE_SETTINGS" "$CLAUDE_SKILLS_DIR/SKILL.md" <<'PY'
import json, sys

path = sys.argv[1]
skill_path = sys.argv[2]

with open(path, "r") as f:
    data = json.load(f)

session_start = (data.get("hooks") or {}).get("SessionStart") or []
filtered = []
removed = 0
for entry in session_start:
    inner = entry.get("hooks") or []
    kept_inner = []
    for inner_hook in inner:
        cmd = inner_hook.get("command", "")
        if skill_path in cmd and cmd.lstrip().startswith("cat"):
            removed += 1
            continue
        kept_inner.append(inner_hook)
    if kept_inner:
        entry["hooks"] = kept_inner
        filtered.append(entry)
    elif not inner:
        filtered.append(entry)

if removed:
    if filtered:
        data["hooks"]["SessionStart"] = filtered
    else:
        data["hooks"].pop("SessionStart", None)
        if not data["hooks"]:
            data.pop("hooks", None)

    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"  - Removed {removed} jobs-done SessionStart hook entry/entries")
else:
    print("  - No jobs-done SessionStart hook to remove")
PY
}

unpatch_opencode_config() {
  [[ -f "$OPENCODE_CONFIG" ]] || return 0
  backup_file "$OPENCODE_CONFIG"

  "$PYTHON_BIN" - "$OPENCODE_CONFIG" "$OPENCODE_SKILLS_DIR/SKILL.md" <<'PY'
import json, sys

path = sys.argv[1]
skill_path = sys.argv[2]

with open(path, "r") as f:
    data = json.load(f)

instructions = data.get("instructions") or []
new_instructions = [i for i in instructions if i != skill_path]
removed = len(instructions) - len(new_instructions)

if removed:
    if new_instructions:
        data["instructions"] = new_instructions
    else:
        data.pop("instructions", None)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"  - Removed SKILL.md from opencode `instructions`")
else:
    print("  - No jobs-done entry in opencode `instructions`")
PY
}

strip_agents_section() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || return 0
  if ! grep -q "<!-- jobs-done:auto-load -->" "$file"; then
    echo "  - No jobs-done section in $label"
    return 0
  fi

  backup_file "$file"

  "$PYTHON_BIN" - "$file" <<'PY'
import re, sys
path = sys.argv[1]
with open(path, "r") as f:
    text = f.read()
new_text = re.sub(
    r"\n?<!-- jobs-done:auto-load -->.*?<!-- /jobs-done:auto-load -->\n?",
    "",
    text,
    flags=re.DOTALL,
)
# Strip trailing blank lines.
new_text = new_text.rstrip() + "\n"
with open(path, "w") as f:
    f.write(new_text)
PY
  echo "  - Removed jobs-done section from $label"
}

remove_mute_lockfile() {
  if [[ -f /tmp/jobs-done-mute ]]; then
    rm -f /tmp/jobs-done-mute
    echo "  - Removed /tmp/jobs-done-mute lockfile"
  fi
}

echo "Uninstalling jobs-done."

if [[ -d "$CLAUDE_HOME" ]]; then
  echo
  echo "Claude Code"
  remove_skill_dir "$CLAUDE_SKILLS_DIR"
  remove_slash_commands "$CLAUDE_COMMANDS_DIR"
  unpatch_claude_settings
  strip_agents_section "$CLAUDE_AGENTS_MD" "CLAUDE.md"
fi

if [[ -d "$OPENCODE_HOME" ]]; then
  echo
  echo "opencode"
  remove_skill_dir "$OPENCODE_SKILLS_DIR"
  remove_slash_commands "$OPENCODE_COMMANDS_DIR"
  unpatch_opencode_config
  strip_agents_section "$OPENCODE_AGENTS_MD" "AGENTS.md"
fi

echo
remove_mute_lockfile

echo
echo "Done. Restart Claude Code / opencode to clear cached config."
echo "Backup files left in place: *.jobs-done-backup.*"
