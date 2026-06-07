---
name: jobs-done
description: Play a short audio notification (macOS) the moment the agent finishes its work and is about to hand control back to the user. Use ONLY at the very end of a turn — after the final tool call, immediately before pausing for the user's next input. Do NOT use between intermediate steps, after every tool call, in CI, or while a question to the user is still pending an answer. Trigger this whenever the agent is idle and waiting.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Bash
---

# jobs-done

Play a notification sound on macOS to let the human know the agent has
stopped working and is now waiting for their next message.

## When to run

Run **exactly once**, at the moment the agent transitions from "working" to
"idle and waiting for user input". In practice that means:

- The final task in the user's request is fully completed.
- All tool calls for this turn are done.
- The next thing about to happen is the user reading your message and
  replying.

Run it as the **last action of the turn**, ideally as your final Bash call
before you produce the closing summary text.

## When NOT to run

- Not between intermediate tool calls inside a single turn.
- Not after every tool call — only at the very end of the whole task.
- Not while you are asking the user a clarifying question that you will
  immediately resume on (no real pause, no real "jobs done").
- Not in non-interactive contexts (CI, scripted runs, batch jobs).
- Not if the user explicitly asked to silence notifications this session.

## How to run

Execute the bundled script:

```bash
"${SKILL_DIR}/jobs-done.sh"
```

where `${SKILL_DIR}` is the directory containing this `SKILL.md`. The script
resolves its audio file relative to its own location, so it works from any
install path.

Default behavior: plays the sound in the background and returns immediately,
so it never blocks the agent or the terminal.

### Options

| Flag       | Effect                                          |
|------------|-------------------------------------------------|
| `--wait`   | Block until playback finishes                   |
| `-h`, `--help` | Print built-in help                         |

### Environment variables

| Variable           | Default | Purpose                              |
|--------------------|---------|--------------------------------------|
| `JOBS_DONE_VOLUME` | `1.0`   | Playback volume (0.0 – 2.0+)         |
| `JOBS_DONE_AUDIO`  | bundled mp3 | Override path to a custom audio file |

Example, quieter playback:

```bash
JOBS_DONE_VOLUME=0.4 "${SKILL_DIR}/jobs-done.sh"
```

## Exit codes

| Code | Meaning                                       |
|------|-----------------------------------------------|
| 0    | Sound played, or playback started in background |
| 1    | Audio file missing                            |
| 2    | `afplay` not available (system is not macOS)  |
| 64   | Unknown CLI argument                          |

Treat any non-zero exit code as a no-op: continue and finish the turn
normally. Do **not** retry, do **not** show the error to the user as if it
were part of the task — it's just a notification.

## Platform

macOS only. The script depends on the system-bundled `/usr/bin/afplay`. On
Linux/Windows the script will exit with code 2 and print a short message;
that's expected and you should just move on.

## Anti-spam guardrails

- Run the script at most once per turn.
- If you just ran it and the user immediately replies with a follow-up,
  treat the follow-up as a new turn — run again only when that new turn
  itself ends in "idle and waiting".
- Never loop, never schedule, never queue multiple playbacks.
