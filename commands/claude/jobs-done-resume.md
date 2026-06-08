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

3. Resume normal behavior: from the next turn onward, play exactly one
   sound at the end of every turn (the usual `done` / `input` / silent
   rules from the jobs-done skill apply again).

4. End this turn with a short confirmation like: "Sounds re-enabled."

Then run the appropriate sound for the CURRENT turn (which is this one).
Since this turn is just a confirmation with no question pending, that
means `done`. Specifically run:

```bash
~/.claude/skills/jobs-done/jobs-done.sh done
```
