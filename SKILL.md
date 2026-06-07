---
name: jobs-done
description: Play AT MOST ONE short audio notification (macOS) per agent turn, but ONLY after every subagent, background process, parallel wave, and queued task for this session has fully finished. Pick ONE of two modes - never both, never two sounds in a row. Use `done` ONLY when all work is complete AND no question is pending. Use `input` when blocked and waiting for the user's decision. SKIP the sound entirely (silent turn) when only acknowledging a background-task progress notification with more background work still pending and no question for the user - the sound would falsely signal that the user needs to act. The two modes are mutually exclusive - if you fire one, you do NOT fire the other in the same turn. Do NOT play between intermediate tool calls. Do NOT play after a single wave or subagent finishes if more work is still running or pending. Do NOT play more than once per turn. Trigger keywords - jobs done, your command master, agent finished, agent waiting, end of turn notification, audio ping, pause for user.
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

## CRITICAL RULE: `done` only after EVERYTHING finishes

`done` means **the entire session for this user request is idle**. Not
"the current step finished". Not "the current wave finished". Not "the
subagent I spawned finished".

Before you fire `jobs-done.sh done`, verify ALL of the following are true:

- Every tool call you've made has returned.
- Every subagent / task / delegated worker you've spawned has reported back
  with its final result.
- Every background process you've kicked off (e.g. `(some_cmd &)`,
  `nohup`, long-running watchers, dev servers, build pipelines, file
  watchers) is either finished OR explicitly intentional (a server the
  user asked you to leave running).
- Every parallel wave / phase / batch has fully completed; no wave is
  still in flight or queued.
- There is no follow-up work you yourself are about to start.

If ANY of those is still live, do NOT play `done`. Either:

1. Wait for it to finish, THEN play `done` (preferred), or
2. Use `input` if you're actually pausing to ask the user about it.

The most common failure mode: playing `done` after the first wave of a
multi-wave job, because that wave "feels finished". It isn't finished.
The session is finished only when the whole tree of work is finished.

Wrong:

```bash
# Wave 1 of 3 just completed, waves 2 and 3 still queued
"${SKILL_DIR}/jobs-done.sh" done   # NO. More work is pending.
```

Wrong:

```bash
# Spawned 3 subagents in parallel, only 1 has reported back
"${SKILL_DIR}/jobs-done.sh" done   # NO. The other 2 are still running.
```

Wrong:

```bash
# Started a background server with `(npm run dev &)` 30 seconds ago
"${SKILL_DIR}/jobs-done.sh" done   # NO, unless the user asked you to
                                   # leave it running and you've told
                                   # them so in this turn's message.
```

Right:

```bash
# All 3 subagents reported back, all waves done, no background jobs left
"${SKILL_DIR}/jobs-done.sh" done
```

## Two sounds, two states (and one silent case)

| Mode       | When                                                               | Sound                          |
|------------|--------------------------------------------------------------------|--------------------------------|
| `done`     | **Entire session is idle.** All subagents, background processes, and parallel waves have finished. No question pending. | `assets/jobs-done.mp3`         |
| `input`    | Stopping mid-flow because you need a decision or answer before continuing. | `assets/your-command-master.mp3` |
| *(silent)* | Acknowledging a background-task progress notification while more background work is still in flight. No question for the user, no real handoff. | *(no sound)*                   |

Decision rule, checked in order:

1. **`input`** if your final message asks the user something whose answer
   changes what you do next.
2. **`done`** if the entire session is now idle (all subagents and
   background jobs finished) and you're handing meaningful control back.
3. **Silent** if you're only reporting that a background agent or job
   just finished AND other background work is still running AND you're
   not asking the user anything. Playing any sound here would falsely
   signal "your turn now" when nothing is waiting on the user.

## When to run

Run **exactly once per turn**, as the very last action before producing
your closing message. In practice:

- All tool calls for this turn are complete.
- All subagents you spawned have reported back.
- All background processes you started are finished (or explicitly
  intentional to keep running, per the section above).
- All parallel waves / phases have wrapped up.
- The next thing about to happen is the user reading your message.
- You have decided whether you are "done" or "asking for input".

Every turn that hands control back to the user gets one sound. No turn
should end silently.

## When NOT to run

- Not between intermediate tool calls inside a single turn.
- Not after every tool call. Only once at the very end.
- **Not after a single wave finishes when more waves are still queued.**
- **Not after a subagent reports back when other subagents are still running.**
- **Not while a background process you started is still doing useful
  work** (unless leaving it running is the intended deliverable).
- Not more than once per turn (no double-sound, no "done then input" combo).
- Not in non-interactive contexts (CI, scripted runs, batch jobs).
- Not if the user explicitly asked to silence notifications this session.

## How to choose `done` vs `input`

Use **`done`** when:

- The user's request is **fully** completed, including all spawned
  subagents, background jobs, and parallel waves.
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

If you're unsure whether work is fully complete, do NOT play `done` yet.
Wait for everything to finish first. Only after the session is truly idle
should you fire `done`. If you're unsure between `done` and `input` in a
truly-idle state, default to `done`.

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

- Run the script **at most once per turn**. Zero plays is fine and is
  the right call for silent (background-acknowledge) turns.
- Pick exactly one mode (`done` or `input`). **Never both in the same turn.**
- **Do NOT play `done` while ANY subagent, background process, or queued
  wave is still running.** A wave finishing is not the session finishing.
- If you've already played a sound in this turn, the next sound waits for
  the next turn. No exceptions, even if your circumstances changed mid-turn
  (e.g. you finished work and then realized you also have a question).
  Pick the mode that fits your final message and stop.
- Treat each new user message as a fresh turn. Fire again only when that
  new turn itself ends in "idle" or "blocked-on-input". NOT when it ends
  in "still waiting on background work, just acknowledging progress".
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

**Background-task progress update with more work in flight. End silently:**

> Agent 2 of 4 just reported back. Agents 1, 3, and 4 are still running.
> I'll process all results once they're in. Nothing for you to do.
>
> *(no sound. The user isn't being handed control. Playing `done` would
> falsely signal "your turn now" when nothing is waiting on them.)*

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

**WRONG: playing `done` after the first wave when more waves are queued.**

> Wave 1 of 3 complete. Starting wave 2 now.
>
> *(runs `jobs-done.sh done`)*   <- NO. Session is not idle. More work
>                                    is about to run.

`done` means the **entire session** is idle. Wave 1 finishing is an
intermediate step, not the end. Do not play any sound here. Wait until
all 3 waves have completed, then play `done` once.

**WRONG: playing `done` while a subagent is still running.**

> I spawned a research agent to investigate option B. Here are my
> findings on options A and C in the meantime.
>
> *(runs `jobs-done.sh done`)*   <- NO. The research agent is still
>                                    running. Session is not idle.

Either wait for the subagent to return and then play `done` once, or
(if you're explicitly pausing for the user's input on A and C before
deciding what to do with B's eventual result) play `input` instead.

**WRONG: playing `done` while a background process is still doing work.**

> Started the test suite in the background and started the linter.
> Here's the file structure in the meantime.
>
> *(runs `jobs-done.sh done`)*   <- NO. Tests and linter haven't
>                                    finished. Session is not idle.

Wait for the background jobs to finish (or kill them) before playing
`done`. The only exception is a process the user explicitly asked you to
leave running (e.g. a dev server), and in that case your turn message
should make that clear.
