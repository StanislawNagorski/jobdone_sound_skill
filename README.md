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

## How it works

The skill has four files:

- `SKILL.md`, the instructions that tell the agent when to fire each sound
  (always once per turn, with the mode chosen by whether the agent needs
  your decision).
- `jobs-done.sh`, a small bash wrapper around macOS `afplay` with two modes.
- `assets/jobs-done.mp3`, the "work finished, idle" sound.
- `assets/your-command-master.mp3`, the "blocked, needs your input" sound.
  This one is the Warcraft II Footman voice line **"Your orders?"**. See
  [Credits](#credits) for the source.

Drop the folder somewhere your agent scans for skills and the agent picks
it up on its own.

## Requirements

- macOS (uses the system `/usr/bin/afplay`)
- Claude Code, opencode, or any agent that supports the Agent Skills
  convention (a `SKILL.md` with frontmatter)

## Installation

### Option 1: quick install (recommended)

Clone into the Claude skills directory. Both Claude Code and opencode
auto-scan `~/.claude/skills/`, so a single install covers both:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git ~/.claude/skills/jobs-done
chmod +x ~/.claude/skills/jobs-done/jobs-done.sh
```

Verify the sound works:

```bash
~/.claude/skills/jobs-done/jobs-done.sh
```

Restart your agent (quit and relaunch Claude Code or opencode) so the skill
is picked up.

### Option 2: install for opencode only

opencode also scans `~/.config/opencode/skills/`:

```bash
mkdir -p ~/.config/opencode/skills
git clone https://github.com/StanislawNagorski/jobdone_sound_skill.git ~/.config/opencode/skills/jobs-done
chmod +x ~/.config/opencode/skills/jobs-done/jobs-done.sh
```

Restart opencode.

### Option 3: per-project install

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

### Option 4: manual install

Download or copy the `jobs-done/` folder anywhere your agent scans for
skills, then `chmod +x jobs-done.sh`. Supported defaults:

| Tool         | Global path                              | Project path              |
|--------------|------------------------------------------|---------------------------|
| Claude Code  | `~/.claude/skills/`                      | `.claude/skills/`         |
| opencode     | `~/.config/opencode/skills/`             | `.opencode/skills/`       |
| opencode (alt) | `~/.claude/skills/`, `~/.agents/skills/` | none                      |

## Verifying

After install, test both sounds directly:

```bash
~/.claude/skills/jobs-done/jobs-done.sh           # done sound (default)
~/.claude/skills/jobs-done/jobs-done.sh done      # done sound (explicit)
~/.claude/skills/jobs-done/jobs-done.sh input     # input-needed sound
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

| Variable                | Default                          | Effect                          |
|-------------------------|----------------------------------|---------------------------------|
| `JOBS_DONE_VOLUME`      | `1.0`                            | Playback volume, `0.0` to `2.0+` |
| `JOBS_DONE_AUDIO_DONE`  | `assets/jobs-done.mp3`           | Override "done" sound           |
| `JOBS_DONE_AUDIO_INPUT` | `assets/your-command-master.mp3` | Override "input" sound          |
| `JOBS_DONE_AUDIO`       | (legacy)                         | Override only "done" sound      |

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
jobs-done.sh [done|input] [--wait] [-h|--help]
```

| Subcommand | Sound played                       | Use when                              |
|------------|------------------------------------|---------------------------------------|
| `done`     | `assets/jobs-done.mp3` (default)   | Agent finished, no question pending   |
| `input`    | `assets/your-command-master.mp3`   | Agent is asking for your decision     |

| Flag           | Effect                                              |
|----------------|-----------------------------------------------------|
| `--wait`       | Block until playback finishes (default: background) |
| `-h`, `--help` | Print help                                          |

Exit codes:

| Code | Meaning                                          |
|------|--------------------------------------------------|
| 0    | OK (played, or playback started in background)  |
| 1    | Audio file not found                            |
| 2    | `afplay` unavailable (non-macOS)                |
| 64   | Unknown argument                                |

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

**No sound, exit code 0.** Check system volume and make sure macOS isn't
fully muted. Focus and Do Not Disturb do not block `afplay`.

**`afplay: command not found`.** You're not on macOS. This skill is
mac-only. On Linux you'd swap `afplay` for `paplay` or `aplay` and edit the
script.

**Agent never triggers the skill.** It probably isn't being discovered:

1. Confirm `SKILL.md` lives directly under the skill folder, not nested.
2. Confirm the install path matches a directory your agent scans.
3. Fully quit and relaunch the agent. Skills are loaded at startup.
4. In opencode, check `/skills` (or the equivalent) to see if `jobs-done`
   is listed.

**Agent fires the wrong sound.** It's confusing `done` with `input`.
Tighten your prompt: "Use `input` mode only when you've literally asked me
a question and need my answer to proceed; otherwise use `done`."

**Agent fires the skill mid-work.** Open `SKILL.md` and tighten the
"When NOT to run" section, or just tell the agent in your prompt: "Run
jobs-done only at the very end of the turn, never between steps."

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

MIT-licensed. The bash script, SKILL.md, and surrounding documentation
were written from scratch for this project.

## License

MIT. See [LICENSE](./LICENSE). Applies to the code and documentation
only. The Warcraft II audio sample is governed by Blizzard's rights as
described in [Credits](#credits).
