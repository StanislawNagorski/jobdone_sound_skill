---
name: jobs-done
description: Play a short audio notification (macOS) whenever the agent's turn ends. Two modes - `done` for "work finished, idle, no question pending" and `input` for "blocked, need user's decision before continuing". ALWAYS play exactly one sound at the end of every turn that hands control back to the user, and choose the mode based on whether the agent is asking the user a question. Do NOT play between intermediate tool calls. Do NOT play more than once per turn. Trigger keywords - jobs done, your command master, agent finished, agent waiting, end of turn notification, audio ping, pause for user.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Bash
---

# jobs-done

Play a notification sound on macOS at the end of every agent turn so the
human knows control is back to them — and which kind of attention is needed.

## Two sounds, two states

| Mode    | When                                                               | Sound                          |
|---------|--------------------------------------------------------------------|--------------------------------|
| `done`  | Work is finished. No question pending. Just summarising and idling. | `assets/jobs-done.mp3`         |
| `input` | Stopping mid-flow because you need a decision/answer before continuing. | `assets/your-command-master.mp3` |

Decision rule: **if your final message contains a question for the user
that you intend to act on next, use `input`. Otherwise use `done`.**

## When to run

Run **exactly once per turn**, as the very last action before producing
your closing message. In practice:

- All tool calls for this turn are complete.
- The next thing about to happen is the user reading your message.
- You have decided whether you are "done" or "asking for input".

Every turn that hands control back to the user gets one sound. No turn
should end silently.

## When NOT to run

- Not between intermediate tool calls inside a single turn.
- Not after every tool call — only once at the very end.
- Not more than once per turn (no double-sound, no "done then input" combo).
- Not in non-interactive contexts (CI, scripted runs, batch jobs).
- Not if the user explicitly asked to silence notifications this session.

## How to choose `done` vs `input`

Use **`done`** when:

- The user's request is fully completed.
- You are summarising results and moving aside.
- Any question in your message is purely rhetorical / "let me know if you
  want changes" style — you are not actively waiting on a specific answer
  to proceed.
- The user can ignore your message and nothing breaks.

Use **`input`** when:

- You are pausing because you genuinely need a decision before continuing.
- You asked a clarifying question whose answer changes what you do next.
- A tool call needs explicit user permission/approval to proceed.
- The plan branches and you cannot pick the right branch on your own.
- You're presenting options and waiting for the user to choose.

If you're unsure, default to **`done`** — it's the lower-friction signal.

## How to run

```bash
# Default: agent finished, no question pending
"${SKILL_DIR}/jobs-done.sh" done

# Agent is asking for a decision and waiting
"${SKILL_DIR}/jobs-done.sh" input
```

`done` is also the default if you call the script with no subcommand:

```bash
"${SKILL_DIR}/jobs-done.sh"
```

`${SKILL_DIR}` is the directory containing this `SKILL.md`. The script
resolves audio files relative to its own location, so it works from any
install path.

Default behavior: plays in the background and returns immediately.

### Options

| Flag           | Effect                                          |
|----------------|-------------------------------------------------|
| `--wait`       | Block until playback finishes                   |
| `-h`, `--help` | Print built-in help                             |

### Environment variables

| Variable                | Default                       | Purpose                          |
|-------------------------|-------------------------------|----------------------------------|
| `JOBS_DONE_VOLUME`      | `1.0`                         | Playback volume (0.0 – 2.0+)     |
| `JOBS_DONE_AUDIO_DONE`  | `assets/jobs-done.mp3`        | Override "done" sound            |
| `JOBS_DONE_AUDIO_INPUT` | `assets/your-command-master.mp3` | Override "input" sound        |

## Exit codes

| Code | Meaning                                           |
|------|---------------------------------------------------|
| 0    | Sound played, or playback started in background  |
| 1    | Audio file missing                                |
| 2    | `afplay` not available (system is not macOS)     |
| 64   | Unknown CLI argument                              |

Treat any non-zero exit code as a no-op: continue and finish the turn
normally. Do **not** retry, do **not** surface the error as if it were
part of the task.

## Platform

macOS only. The script depends on `/usr/bin/afplay`. On Linux/Windows it
exits with code 2 — that's expected.

## Anti-spam guardrails

- Run the script at most once per turn.
- Pick exactly one mode (`done` or `input`), never both.
- Treat each new user message as a fresh turn — fire again only when that
  new turn itself ends in "idle" or "blocked-on-input".
- Never loop, never schedule, never queue multiple playbacks.

## Examples

**End of a successful task, no question pending → `done`:**

> Refactored `auth.ts` and updated tests — all green. Let me know if you
> want me to look at anything else.
>
> *(runs `jobs-done.sh done`)*

**Need user to choose between options → `input`:**

> I see two ways to handle this: drop the row entirely, or keep it and
> mark it deprecated. Which do you want?
>
> *(runs `jobs-done.sh input`)*

**Tool requires permission you can't grant yourself → `input`:**

> I need to run `rm -rf node_modules` to fix this. Confirm you want me
> to proceed.
>
> *(runs `jobs-done.sh input`)*

**Quick clarification but already know what to do next either way → `done`:**

> Done. (Side note: I assumed UTC — happy to switch to local if you'd
> rather.)
>
> *(runs `jobs-done.sh done`)*
