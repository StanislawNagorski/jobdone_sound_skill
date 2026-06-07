# jobs-done

> Audio "ping" the moment your AI coding agent finishes work and is waiting
> for your next message. macOS, single bash script, no dependencies.

When your agent (Claude Code, opencode, Cursor agent, etc.) hands control
back to you, a short sound plays. No more glancing at the terminal every 30
seconds wondering if it's done.

## How it works

A skill that ships:

- `SKILL.md` — instructions telling the agent **exactly** when to fire the
  notification (only at the end of a turn, never mid-work).
- `jobs-done.sh` — a tiny bash wrapper around macOS `afplay`.
- `assets/jobs-done.mp3` — the sound itself.

When installed in a location your agent scans for skills, the agent will
discover it automatically and start using it.

## Requirements

- macOS (uses the system `/usr/bin/afplay`)
- One of: Claude Code, opencode, or any agent that supports the Agent
  Skills convention (`SKILL.md` with frontmatter)

## Installation

### Option 1 — Quick install (recommended)

Clone into the Claude skills directory. **Both Claude Code and opencode
auto-scan `~/.claude/skills/`**, so a single install covers both:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git ~/.claude/skills/jobs-done
chmod +x ~/.claude/skills/jobs-done/jobs-done.sh
```

Verify the sound works:

```bash
~/.claude/skills/jobs-done/jobs-done.sh
```

Restart your agent (quit and relaunch Claude Code / opencode) so the skill
is picked up.

### Option 2 — Install for opencode only

opencode also scans `~/.config/opencode/skills/`:

```bash
mkdir -p ~/.config/opencode/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git ~/.config/opencode/skills/jobs-done
chmod +x ~/.config/opencode/skills/jobs-done/jobs-done.sh
```

Restart opencode.

### Option 3 — Per-project install

Put the skill in a single project so only agents working in that repo use
it:

```bash
mkdir -p .opencode/skills        # for opencode
# or
mkdir -p .claude/skills          # for Claude Code

git submodule add https://github.com/StanislawNagorski/jobdone_sound_skill.git \
  .opencode/skills/jobs-done
chmod +x .opencode/skills/jobs-done/jobs-done.sh
```

### Option 4 — Manual install

Download or copy the `jobs-done/` folder anywhere your agent scans for
skills, then `chmod +x jobs-done.sh`. Supported defaults:

| Tool         | Global path                              | Project path              |
|--------------|------------------------------------------|---------------------------|
| Claude Code  | `~/.claude/skills/`                      | `.claude/skills/`         |
| opencode     | `~/.config/opencode/skills/`             | `.opencode/skills/`       |
| opencode (alt) | `~/.claude/skills/`, `~/.agents/skills/` | —                         |

## Verifying

After install, test the script directly:

```bash
~/.claude/skills/jobs-done/jobs-done.sh           # plays sound, returns
~/.claude/skills/jobs-done/jobs-done.sh --wait    # plays sound, blocks
~/.claude/skills/jobs-done/jobs-done.sh --help    # shows help
```

Then ask your agent to do anything trivial ("list files in this dir"). When
it finishes, you should hear the sound.

If the agent doesn't fire it on its own, ask it explicitly:

> Run the `jobs-done` skill when you're finished.

If it still doesn't trigger, the skill probably isn't being discovered —
double-check the install path and restart the agent.

## Configuration

Environment variables, set per-call or in your shell profile:

| Variable           | Default       | Effect                                |
|--------------------|---------------|---------------------------------------|
| `JOBS_DONE_VOLUME` | `1.0`         | Playback volume, `0.0` to `2.0+`      |
| `JOBS_DONE_AUDIO`  | bundled mp3   | Path to a custom audio file           |

Example (set permanently for quieter pings):

```bash
echo 'export JOBS_DONE_VOLUME=0.4' >> ~/.zshrc
```

Use your own sound (any format `afplay` supports — mp3, m4a, wav, aiff):

```bash
echo 'export JOBS_DONE_AUDIO="$HOME/sounds/my-ding.m4a"' >> ~/.zshrc
```

## CLI reference

```
jobs-done.sh [--wait] [-h|--help]
```

| Flag        | Effect                                         |
|-------------|------------------------------------------------|
| `--wait`    | Block until playback finishes (default: background) |
| `-h`, `--help` | Print help                                  |

Exit codes:

| Code | Meaning                                       |
|------|-----------------------------------------------|
| 0    | OK (played, or playback started in background) |
| 1    | Audio file not found                          |
| 2    | `afplay` unavailable (non-macOS)              |
| 64   | Unknown argument                              |

## Updating

```bash
cd ~/.claude/skills/jobs-done
git pull
```

If you installed as a submodule:

```bash
git submodule update --remote .opencode/skills/jobs-done
```

## Uninstall

```bash
rm -rf ~/.claude/skills/jobs-done
# and / or
rm -rf ~/.config/opencode/skills/jobs-done
```

Restart the agent.

## Troubleshooting

**No sound, exit code 0.** Check system volume; make sure macOS isn't fully
muted. Focus / Do Not Disturb does **not** block `afplay`.

**`afplay: command not found`.** You're not on macOS. This skill is
mac-only. On Linux you'd swap `afplay` for `paplay` or `aplay` and edit the
script.

**Agent never triggers the skill.** It probably isn't being discovered:

1. Confirm `SKILL.md` lives directly under the skill folder, not nested.
2. Confirm the install path matches a directory your agent scans.
3. Fully quit and relaunch the agent — skills are loaded at startup.
4. In opencode, check `/skills` (or the equivalent) to see if `jobs-done`
   is listed.

**Agent fires the skill mid-work.** Open `SKILL.md` and tighten the
"When NOT to run" section, or just tell the agent in your prompt: "Run
jobs-done only at the very end of the turn, never between steps."

## License

MIT — see [LICENSE](./LICENSE).
