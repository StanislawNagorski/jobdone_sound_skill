# jobs-done

> Two distinct audio "pings" so you always know what your AI agent wants
> from you. One sound when work is finished, a different sound when the
> agent is blocked and needs your decision. macOS, single bash script, no
> dependencies.

When your agent (Claude Code, opencode, Cursor agent, etc.) ends a turn,
it plays one of two sounds:

- `done` means "I finished. Nothing to decide. You can come back whenever."
- `input` means "I stopped because I need your call before I keep going."

No more glancing at the terminal every 30 seconds wondering if it's done,
and no more missing the moments where the agent is actually waiting on you.

Two slash commands let you silence everything for the current session:

- `/jobs-done-mute` mutes both sounds until the next reboot or `/jobs-done-resume`.
- `/jobs-done-resume` re-enables them.

## How it works

The skill ships:

- `SKILL.md`, the instructions that tell the agent when to fire each sound
  (always once per turn, with the mode chosen by whether the agent needs
  your decision).
- `jobs-done.sh`, a small bash wrapper around macOS `afplay`.
- `assets/jobs-done.mp3`, the "work finished, idle" sound.
- `assets/your-command-master.mp3`, the "blocked, needs your input" sound.
  This one is the Warcraft II Footman voice line **"Your orders?"**. See
  [Credits](#credits) for the source.
- `commands/`, the slash command definitions for both Claude Code and
  opencode (mute/resume).
- `install.sh` and `uninstall.sh`, scripts that wire everything up so the
  skill auto-loads in every new session.

## Requirements

- macOS (uses the system `/usr/bin/afplay`)
- Claude Code, opencode, or any agent that supports the Agent Skills
  convention (a `SKILL.md` with frontmatter)
- `git`, `bash`, and `python3` (the system `/usr/bin/python3` from Xcode
  CLT is enough)

## Quick install

One command sets up everything: copies the skill, installs slash commands,
patches your settings so the skill is injected into the context at the
start of every new session.

```bash
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git
cd jobdone_sound_skill
./install.sh
```

Or, without cloning manually:

```bash
curl -sSL https://raw.githubusercontent.com/StanislawNagorski/jobdone_sound_skill/main/install.sh | bash
```

The installer:

1. Drops the skill into `~/.claude/skills/jobs-done` and
   `~/.config/opencode/skills/jobs-done` (whichever clients are present).
2. Installs the `/jobs-done-mute` and `/jobs-done-resume` slash commands.
3. Adds a `SessionStart` hook to `~/.claude/settings.json` that injects
   `SKILL.md` into every Claude Code session.
4. Adds `SKILL.md` to the `instructions` array in
   `~/.config/opencode/opencode.json` (opencode's equivalent of the hook).
5. Appends a short "auto-load skills" reminder to `~/.claude/CLAUDE.md`
   and `~/.config/opencode/AGENTS.md` as a fallback.

The script is idempotent. Re-run it after `git pull` to refresh the skill
files and slash commands without duplicating the config patches.

Restart Claude Code and opencode after install.

## What "auto-load" actually means

By default, an agent only loads a skill when it decides to. `jobs-done` is
no use if the agent forgets to use it.

The installer therefore uses two layers of insurance per client:

| Client       | Hard mechanism (deterministic)                  | Soft fallback (in case the hard one fails)                 |
|--------------|--------------------------------------------------|-------------------------------------------------------------|
| Claude Code  | `SessionStart` hook running `cat SKILL.md`       | "Auto-load skills" section appended to `CLAUDE.md`          |
| opencode     | `SKILL.md` added to `instructions` in `opencode.json` | "Auto-load skills" section appended to `AGENTS.md`     |

Either layer alone would work most of the time. Both layers together make
it very unlikely that a new session starts without the skill present.

## Slash commands

After install, both clients pick up two commands:

| Command              | What it does                                                                       |
|----------------------|-------------------------------------------------------------------------------------|
| `/jobs-done-mute`    | Silences both sounds for the rest of the session by touching `/tmp/jobs-done-mute`. |
| `/jobs-done-resume`  | Removes the lockfile and re-enables the sounds.                                     |

The mute lockfile lives in `/tmp/`, so it auto-clears on system reboot.
You don't need to remember to `resume` between machine restarts.

You can also drive the same actions from a shell:

```bash
~/.claude/skills/jobs-done/jobs-done.sh mute
~/.claude/skills/jobs-done/jobs-done.sh resume
~/.claude/skills/jobs-done/jobs-done.sh status
```

## Manual install

Skip this section if `./install.sh` worked. The manual path is for people
who want to know exactly what changed, or who want partial installs.

### Skill files

```bash
# Claude Code
mkdir -p ~/.claude/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git \
  ~/.claude/skills/jobs-done
chmod +x ~/.claude/skills/jobs-done/jobs-done.sh

# opencode
mkdir -p ~/.config/opencode/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git \
  ~/.config/opencode/skills/jobs-done
chmod +x ~/.config/opencode/skills/jobs-done/jobs-done.sh
```

### Slash commands

Copy the relevant files from `commands/` in this repo:

```bash
# Claude Code
mkdir -p ~/.claude/commands
cp commands/claude/jobs-done-mute.md   ~/.claude/commands/
cp commands/claude/jobs-done-resume.md ~/.claude/commands/

# opencode
mkdir -p ~/.config/opencode/command
cp commands/opencode/jobs-done-mute.md   ~/.config/opencode/command/
cp commands/opencode/jobs-done-resume.md ~/.config/opencode/command/
```

### Auto-load wiring

For Claude Code, add a `SessionStart` hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat \"/Users/YOU/.claude/skills/jobs-done/SKILL.md\""
          }
        ]
      }
    ]
  }
}
```

For opencode, add the skill to the `instructions` array in
`~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "/Users/YOU/.config/opencode/skills/jobs-done/SKILL.md"
  ]
}
```

For fallback in either client, append this to `~/.claude/CLAUDE.md` or
`~/.config/opencode/AGENTS.md`:

```markdown
<!-- jobs-done:auto-load -->
## Auto-load skills (every session)

At the start of every session, treat the `jobs-done` skill as already
loaded. If for some reason it isn't, invoke it yourself as the very first
tool call.
<!-- /jobs-done:auto-load -->
```

Restart the agent after any of these edits.

## Verifying

After install, test both sounds directly:

```bash
~/.claude/skills/jobs-done/jobs-done.sh           # done sound (default)
~/.claude/skills/jobs-done/jobs-done.sh done      # done sound (explicit)
~/.claude/skills/jobs-done/jobs-done.sh input     # input-needed sound
~/.claude/skills/jobs-done/jobs-done.sh mute      # silence subsequent calls
~/.claude/skills/jobs-done/jobs-done.sh status    # show mute state
~/.claude/skills/jobs-done/jobs-done.sh resume    # re-enable
~/.claude/skills/jobs-done/jobs-done.sh --wait    # block until done
~/.claude/skills/jobs-done/jobs-done.sh --help    # show help
```

Then ask your agent to do anything trivial ("list files in this dir"). When
it finishes, you should hear the `done` sound. Ask it something ambiguous
that forces it to ask you a question, and you should hear the `input` sound
instead.

If the agent doesn't fire it on its own, ask it explicitly:

> Run the `jobs-done` skill at the end of every turn. Use `done` mode when
> you're finished, `input` mode when you're asking me a question.

If it still doesn't trigger, the skill probably isn't being discovered.
Double-check the install path and restart the agent.

## Configuration

Environment variables, set per-call or in your shell profile:

| Variable                | Default                          | Effect                                |
|-------------------------|----------------------------------|---------------------------------------|
| `JOBS_DONE_VOLUME`      | `1.0`                            | Playback volume, `0.0` to `2.0+`      |
| `JOBS_DONE_AUDIO_DONE`  | `assets/jobs-done.mp3`           | Override "done" sound                 |
| `JOBS_DONE_AUDIO_INPUT` | `assets/your-command-master.mp3` | Override "input" sound                |
| `JOBS_DONE_AUDIO`       | (legacy)                         | Override only "done" sound            |
| `JOBS_DONE_MUTE_FILE`   | `/tmp/jobs-done-mute`            | Override mute lockfile path           |

Example (set permanently for quieter pings):

```bash
echo 'export JOBS_DONE_VOLUME=0.4' >> ~/.zshrc
```

Use your own sounds (any format `afplay` supports, including mp3, m4a, wav,
aiff):

```bash
echo 'export JOBS_DONE_AUDIO_DONE="$HOME/sounds/finished.m4a"' >> ~/.zshrc
echo 'export JOBS_DONE_AUDIO_INPUT="$HOME/sounds/needs-you.m4a"' >> ~/.zshrc
```

## CLI reference

```
jobs-done.sh [done|input|mute|resume|status] [--wait] [-h|--help]
```

| Subcommand | Effect                                                              |
|------------|---------------------------------------------------------------------|
| `done`     | Play the "work finished" sound (default if no subcommand)           |
| `input`    | Play the "blocked, needs your decision" sound                       |
| `mute`     | Create the lockfile. Subsequent `done`/`input` no-op until resume   |
| `resume`   | Remove the lockfile. `done`/`input` play again                      |
| `status`   | Print `jobs-done: active` or `jobs-done: MUTED (...)`               |

| Flag           | Effect                                              |
|----------------|-----------------------------------------------------|
| `--wait`       | Block until playback finishes (default: background) |
| `-h`, `--help` | Print help                                          |

Exit codes:

| Code | Meaning                                                |
|------|--------------------------------------------------------|
| 0    | OK (played, started in background, or skipped by mute) |
| 1    | Audio file not found                                   |
| 2    | `afplay` unavailable (non-macOS)                       |
| 64   | Unknown argument                                       |

## Updating

```bash
cd <wherever you cloned the repo>
git pull
./install.sh
```

`install.sh` is idempotent. Re-running it refreshes the skill files and
slash commands but doesn't duplicate the config patches.

## Uninstall

```bash
cd <wherever you cloned the repo>
./uninstall.sh
```

This removes the skill directories, slash commands, the `SessionStart`
hook entry from `settings.json`, the `instructions` entry from
`opencode.json`, the auto-load sections from `CLAUDE.md` and `AGENTS.md`,
and the mute lockfile. It leaves your existing non-jobs-done config
untouched and keeps timestamped backups (`*.jobs-done-backup.*`) of any
file it edited.

## Troubleshooting

**No sound, exit code 0.** First check if sounds are muted: run
`jobs-done.sh status`. If yes, `jobs-done.sh resume` (or `/jobs-done-resume`
in a session). Otherwise check system volume; macOS Focus and Do Not
Disturb don't block `afplay`.

**`afplay: command not found`.** You're not on macOS. This skill is
mac-only. On Linux you'd swap `afplay` for `paplay` or `aplay` and edit the
script.

**Agent never triggers the skill.** It probably isn't being discovered:

1. Confirm `SKILL.md` lives directly under the skill folder, not nested.
2. Confirm the install path matches a directory your agent scans.
3. Fully quit and relaunch the agent. Skills are loaded at startup.
4. In opencode, check `/skills` (or the equivalent) to see if `jobs-done`
   is listed.
5. Re-run `./install.sh` to make sure the auto-load wiring is in place.

**Agent fires the wrong sound.** It's confusing `done` with `input`.
Tighten your prompt: "Use `input` mode only when you've literally asked me
a question and need my answer to proceed; otherwise use `done`."

**Agent fires the skill mid-work.** Open `SKILL.md` and tighten the
"When NOT to run" section, or just tell the agent in your prompt: "Run
jobs-done only at the very end of the turn, never between steps."

**`install.sh` says "python3 not found".** Install Xcode Command Line
Tools: `xcode-select --install`.

## Credits

### Audio sources

| File                              | Source                                                                                       |
|-----------------------------------|----------------------------------------------------------------------------------------------|
| `assets/jobs-done.mp3`            | Personal sample, included as the default "work finished" notification.                       |
| `assets/your-command-master.mp3`  | Warcraft II Footman voice line "Your orders?" (file `Hwhat2.wav` from *Warcraft II: Tides of Darkness*, 1995, Blizzard Entertainment). Sourced via [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Quotes_of_Warcraft_II#Footman). |

The Warcraft II audio sample is the property of Blizzard Entertainment and
is included here for personal, non-commercial use as a notification chime.
If you redistribute this skill, swap the file for one you have the rights
to, or set `JOBS_DONE_AUDIO_INPUT` to point at your own sound.

### Code

MIT-licensed. The bash script, SKILL.md, install/uninstall scripts, and
surrounding documentation were written from scratch for this project.

## License

MIT. See [LICENSE](./LICENSE). Applies to the code and documentation
only. The Warcraft II audio sample is governed by Blizzard's rights as
described in [Credits](#credits).
