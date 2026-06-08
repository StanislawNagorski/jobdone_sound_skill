---
description: Mute jobs-done sounds for the rest of this session
allowed-tools: Bash
---

Mute the jobs-done audio notifications until I explicitly resume them with
`/jobs-done-resume` (or until the system reboots).

Do all of the following:

1. Run this bash command exactly once:

   ```bash
   ~/.claude/skills/jobs-done/jobs-done.sh mute
   ```

2. Confirm the mute lockfile exists by also running:

   ```bash
   ~/.claude/skills/jobs-done/jobs-done.sh status
   ```

3. For the rest of this session, do NOT invoke
   `~/.claude/skills/jobs-done/jobs-done.sh input` or
   `~/.claude/skills/jobs-done/jobs-done.sh skip`. The Stop-hook autofire
   path also no-ops while muted, so nothing extra is needed from you.

4. End this turn with a short confirmation like: "Sounds muted. Use
   `/jobs-done-resume` to re-enable."

Treat the silence as a positive acknowledgement, not a problem to fix.
