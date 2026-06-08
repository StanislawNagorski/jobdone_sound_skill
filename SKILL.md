---
name: jobs-done
description: A short audio notification fires automatically (macOS) at the end of every main-agent turn via a Claude Code Stop hook. This skill explains the mechanism and tells you when (rarely) you should override it. Default behavior - do NOTHING and the Stop hook plays the "done" sound once per turn. Override 1 - if your final message blocks on a user decision, run `jobs-done.sh input` BEFORE returning so the "your-command-master" sound plays instead. Override 2 - if you're only acknowledging a background-task progress notification with more work still pending, run `jobs-done.sh skip` to silence the autofire for this turn. Subagents (spawned via Task or Agent tool) MUST NOT call this script - even if they try, the script silently no-ops in subagent context, but skipping the call saves a tool slot. Honor the mute lockfile /tmp/jobs-done-mute - if it exists, skip the call entirely. Trigger keywords - jobs done, your command master, agent finished, agent waiting, end of turn notification, audio ping, pause for user, mute sounds, resume sounds.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Bash
---

# jobs-done

End-of-turn audio notification for AI coding agents on macOS. Tells the
human whether the agent is idle (`done`) or waiting on them (`input`).

## How it actually works now

**You almost never need to invoke this script.** A Claude Code `Stop` hook
runs `jobs-done.sh autofire` automatically at the end of every main-agent
turn and plays the `done` sound. This means:

- You do NOT call `jobs-done.sh done` at end of turn. The hook handles it.
- You DO call `jobs-done.sh input` (BEFORE producing your final message)
  when your final message blocks on a user decision — the script plays the
  `input` sound and marks the turn so the autofire Stop hook stays silent
  (no double sound).
- You DO call `jobs-done.sh skip` when this turn is a background-progress
  acknowledgement and no sound is appropriate — that marker also silences
  the Stop hook for this turn.

That's it. Three buttons:

| Situation                                                   | What you run               | What plays           |
|-------------------------------------------------------------|----------------------------|----------------------|
| Done with everything, nothing else needed                   | *(nothing)*                | `done` (autofire)    |
| Final message asks the user a question that gates next step | `jobs-done.sh input`       | `input`              |
| Acknowledging background progress, more work still running  | `jobs-done.sh skip`        | *(silence)*          |

## Subagent rule (CRITICAL)

**If you are a subagent — spawned through the Task or Agent tool — do NOT
call `jobs-done.sh` at all.** Only the main orchestrator's turn-end matters
to the user. The Stop hook fires only for the main agent; subagent
finishes have their own `SubagentStop` event that is intentionally NOT
wired to sound.

As a safety net, the script detects subagent context (via marker files
maintained by `SubagentStart` / `SubagentStop` hooks) and silently no-ops
any call originating from inside a subagent. So even a stray call is
harmless — but the right behavior is "don't call".

This rule applies recursively. A subagent that itself spawns subagents
must also not call the script.

## Decision rule for the main agent

Before you produce your final message, choose ONE branch:

1. **Final message blocks on a user decision?**
   → run `jobs-done.sh input`. The autofire Stop hook will NOT play
   another sound after your message.
2. **Final message is a silent progress acknowledgement (background
   work still in flight, nothing for the user to do)?**
   → run `jobs-done.sh skip`. The autofire Stop hook will play nothing.
3. **Anything else (real handoff, idle, summary, side-note question
   that doesn't gate anything)?**
   → do nothing. The autofire Stop hook will play `done`.

If you're unsure between branches 1 and 3, prefer 3 — `done` is safe for
most cases. Only use `input` when the user really must answer something
before you can proceed.

## CRITICAL: one sound per turn, never two

The autofire Stop hook + your `input` / `skip` calls are coordinated via
a `played-this-turn` marker. As long as you call `input` or `skip` at
most once per turn (and never both, never both `done` and `input`), you
will hear exactly one sound (or none, for `skip`) per turn.

Anti-pattern (do NOT do this):

```bash
"${SKILL_DIR}/jobs-done.sh" done     # autofire already covers this
"${SKILL_DIR}/jobs-done.sh" input    # AND now you have two markers — bug-prone
```

Right (pick one branch from the decision rule):

```bash
"${SKILL_DIR}/jobs-done.sh" input    # final message blocks on user
```

or

```bash
"${SKILL_DIR}/jobs-done.sh" skip     # final message is silent ack
```

or nothing at all (let autofire play `done`).

## Mute mechanism

The user can silence the skill for the rest of a session via the slash
command `/jobs-done-mute` (creates `/tmp/jobs-done-mute`). Re-enable with
`/jobs-done-resume` (removes the lockfile).

While the lockfile exists:

- All sound-producing paths (model-driven `input`, autofire `done`) are
  no-ops. You'll hear nothing.
- `skip` and the subagent markers still operate normally — they're
  stateless w.r.t. sound.

Once you observe that mute is on for this session, skip the call entirely
to save a tool slot:

```bash
"${SKILL_DIR}/jobs-done.sh" status
# prints: jobs-done: MUTED (lockfile: /tmp/jobs-done-mute)
#  or:    jobs-done: active
```

The lockfile lives in `/tmp/`, so it clears on reboot.

## When NOT to invoke

- Do not call `done` from the model. That's autofire's job. A redundant
  `done` call doesn't break anything but burns a tool slot.
- Do not call between intermediate tool calls inside a single turn.
- Do not call from inside a subagent. The script no-ops in that context
  but skipping the call entirely is better.
- Do not call more than once per turn. `input` once OR `skip` once OR
  neither — never two of these.
- Do not call in non-interactive contexts (CI, scripted runs).
- Do not call if `/jobs-done-mute` has been run this session.

## How to run

```bash
# Default for most turns: do nothing. The Stop hook handles it.

# Final message blocks on user input:
"${SKILL_DIR}/jobs-done.sh" input

# Silent progress-ack turn (background work still running):
"${SKILL_DIR}/jobs-done.sh" skip

# Check mute state:
"${SKILL_DIR}/jobs-done.sh" status
```

`${SKILL_DIR}` is the directory containing this `SKILL.md`. The script
resolves audio files relative to its own location, so it works from any
install path.

Playback is non-blocking by default.

### Options

| Flag           | Effect                                          |
|----------------|-------------------------------------------------|
| `--wait`       | Block until playback finishes                   |
| `-h`, `--help` | Print built-in help                             |

### Environment variables

| Variable                | Default                       | Purpose                                |
|-------------------------|-------------------------------|----------------------------------------|
| `JOBS_DONE_VOLUME`      | `1.0`                         | Playback volume (0.0 – 2.0+)           |
| `JOBS_DONE_AUDIO_DONE`  | `assets/jobs-done.mp3`        | Override "done" sound                  |
| `JOBS_DONE_AUDIO_INPUT` | `assets/your-command-master.mp3` | Override "input" sound              |
| `JOBS_DONE_STATE_DIR`   | `$TMPDIR/jobs-done-state`     | Per-session state dir (markers)        |
| `JOBS_DONE_STALE_SECS`  | `120`                         | Max age for "played" marker freshness  |

## Exit codes

| Code | Meaning                                              |
|------|------------------------------------------------------|
| 0    | Sound played, started, or skipped (mute / subagent / dedupe) |
| 1    | Audio file missing                                   |
| 2    | `afplay` not available (system is not macOS)         |
| 64   | Unknown CLI argument                                 |

Treat any non-zero exit code as a no-op: continue and finish the turn
normally. Do **not** retry, and do **not** surface the error.

## Platform

macOS only (script needs `/usr/bin/afplay`). On Linux/Windows the script
exits with code 2.

Claude Code's hook events (`Stop`, `SubagentStart`, `SubagentStop`,
`SessionStart`) drive the auto-fire and subagent-isolation behavior.
opencode does not currently have equivalent hooks, so on opencode the
script still works for manual `input` / `done` invocation, but auto-fire
and subagent isolation are not active — fall back to the model-driven
discipline of "one explicit call per turn, never from a subagent".

## Examples

**Default end-of-turn (autofire handles it):**

> Refactored `auth.ts` and updated tests, all green.
>
> *(no explicit jobs-done call. Stop hook fires `done` automatically.)*

**Final message blocks on user input:**

> I see two ways to handle this: drop the row, or mark it deprecated.
> Which do you want?
>
> *(before returning, runs `jobs-done.sh input`. Stop hook stays silent.)*

**Silent progress-ack:**

> Agent 2 of 4 just reported back. Agents 1, 3, and 4 are still running.
> I'll process all results once they're in. Nothing for you to do.
>
> *(runs `jobs-done.sh skip`. Stop hook stays silent.)*

**Subagent finishing its work — does nothing:**

> *(Subagent's final message — no jobs-done call. The orchestrator's
> own Stop event will fire the sound at the proper time.)*

**WRONG: model calling `done` manually:**

> Done. Anything else?
>
> *(runs `jobs-done.sh done`)* ← unnecessary; autofire already covers this.
> Not harmful (marker dedupes) but wastes a tool slot.

**WRONG: model calling both `done` and `input`:**

> Finished the refactor. Want me to also rename the tests?
>
> *(runs `jobs-done.sh done`)*
> *(runs `jobs-done.sh input`)* ← only one allowed per turn.

The right call for the example above is **only** `jobs-done.sh input`
(the question gates next step). Or, if you decide the question is
rhetorical and you're truly idle, call nothing and let autofire play
`done`.
