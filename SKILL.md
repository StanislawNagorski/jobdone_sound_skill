---
name: jobs-done
description: Play EXACTLY ONE short audio notification (macOS) at the end of every agent turn. Pick ONE of two modes - never both, never two sounds in a row. Use `done` when work is finished and no question is pending. Use `input` when blocked and waiting for the user's decision. The two modes are mutually exclusive - if you fire one, you do NOT fire the other in the same turn. Do NOT play between intermediate tool calls. Do NOT play more than once per turn. Trigger keywords - jobs done, your command master, agent finished, agent waiting, end of turn notification, audio ping, pause for user.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Bash
---

# jobs-done

Play a notification sound on macOS at the end of every agent turn so the
human knows control is back to them, and what kind of attention is needed.

## CRITICAL RULE: one sound per turn, never both

The two modes (`done` and `input`) are **mutually exclusive**. In a single
turn you fire **exactly one** of them, **never both**.

If you've already run `jobs-done.sh done` in this turn, you do NOT also run
`jobs-done.sh input`. If you've already run `jobs-done.sh input`, you do
NOT also run `jobs-done.sh done`. Pick one before you call the script and
stick with it.

Wrong:

```bash
"${SKILL_DIR}/jobs-done.sh" done
"${SKILL_DIR}/jobs-done.sh" input   # NO. Already played one. Stop.
```

Right (pick one of these, not both):

```bash
"${SKILL_DIR}/jobs-done.sh" done    # turn ends without a pending question
```

```bash
"${SKILL_DIR}/jobs-done.sh" input   # turn ends asking the user something
```

If you catch yourself about to play a second sound in the same turn, do
nothing instead. One turn, one sound.

## Two sounds, two states

| Mode    | When                                                               | Sound                          |
|---------|--------------------------------------------------------------------|--------------------------------|
| `done`  | Work is finished. No question pending. Just summarising and idling. | `assets/jobs-done.mp3`         |
| `input` | Stopping mid-flow because you need a decision or answer before continuing. | `assets/your-command-master.mp3` |

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
- Not after every tool call. Only once at the very end.
- Not more than once per turn (no double-sound, no "done then input" combo).
- Not in non-interactive contexts (CI, scripted runs, batch jobs).
- Not if the user explicitly asked to silence notifications this session.

## How to choose `done` vs `input`

Use **`done`** when:

- The user's request is fully completed.
- You are summarising results and moving aside.
- Any question in your message is purely rhetorical ("let me know if you
  want changes" style). You are not actively waiting on a specific answer
  to proceed.
- The user can ignore your message and nothing breaks.

Use **`input`** when:

- You are pausing because you genuinely need a decision before continuing.
- You asked a clarifying question whose answer changes what you do next.
- A tool call needs explicit user permission or approval to proceed.
- The plan branches and you cannot pick the right branch on your own.
- You're presenting options and waiting for the user to choose.

If you're unsure, default to **`done`**. It's the lower-friction signal.

## How to run

Pick **one** of the two commands below per turn. Never both.

```bash
# Agent finished, no question pending
"${SKILL_DIR}/jobs-done.sh" done
```

```bash
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
normally. Do **not** retry, and do **not** surface the error as if it were
part of the task.

## Platform

macOS only. The script depends on `/usr/bin/afplay`. On Linux or Windows it
exits with code 2. That's expected.

## Anti-spam guardrails

- Run the script **at most once per turn**.
- Pick exactly one mode (`done` or `input`). **Never both in the same turn.**
- If you've already played a sound in this turn, the next sound waits for
  the next turn. No exceptions, even if your circumstances changed mid-turn
  (e.g. you finished work and then realized you also have a question).
  Pick the mode that fits your final message and stop.
- Treat each new user message as a fresh turn. Fire again only when that
  new turn itself ends in "idle" or "blocked-on-input".
- Never loop, never schedule, never queue multiple playbacks.

## Examples

**End of a successful task, no question pending. Use `done`:**

> Refactored `auth.ts` and updated tests, all green. Let me know if you
> want me to look at anything else.
>
> *(runs `jobs-done.sh done`)*

**Need user to choose between options. Use `input`:**

> I see two ways to handle this: drop the row entirely, or keep it and
> mark it deprecated. Which do you want?
>
> *(runs `jobs-done.sh input`)*

**Tool requires permission you can't grant yourself. Use `input`:**

> I need to run `rm -rf node_modules` to fix this. Confirm you want me
> to proceed.
>
> *(runs `jobs-done.sh input`)*

**Quick clarification but you already know what to do next either way.
Use `done`:**

> Done. (Side note: I assumed UTC. Happy to switch to local if you'd
> rather.)
>
> *(runs `jobs-done.sh done`)*

**WRONG: playing both sounds in one turn.**

> Finished the refactor. By the way, should the timezone stay UTC or
> switch to local?
>
> *(runs `jobs-done.sh done`)*
> *(runs `jobs-done.sh input`)*   <- NO. One turn, one sound.

The message above asks a question that changes what happens next, so the
correct call is **only** `jobs-done.sh input`. The `done` call should not
have happened. If you genuinely don't know which to pick, default to
`done` and stop.
