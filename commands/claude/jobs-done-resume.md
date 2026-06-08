---
description: Resume jobs-done sounds after a previous mute
allowed-tools: Bash
---

Re-enable the jobs-done audio notifications.

Do all of the following:

1. Run this bash command exactly once:

   ```bash
   ~/.claude/skills/jobs-done/jobs-done.sh resume
   ```

2. Confirm the lockfile is gone by running:

   ```bash
   ~/.claude/skills/jobs-done/jobs-done.sh status
   ```

3. End this turn with a short confirmation like: "Sounds re-enabled."

The Stop-hook autofire will play the `done` sound at the end of this
turn automatically — you do NOT need to call `jobs-done.sh done`
manually.
