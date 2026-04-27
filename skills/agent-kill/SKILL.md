---
name: agent-kill
description: Close a spawned LLM-CLI window in the `main` tmux session. Use when the user asks to kill, stop, or end a specific helper agent. Refuses to kill any window whose slug is "main" — the foundational session window stays up.
---

# agent-kill

Closes a tmux window in the `main` session. Harness-agnostic.

## How to kill

```
agent-kill <window>
```

- Bare slugs (`auth-refactor`) are decorated to `[<host>][claude] <slug>`.
- Pass the full `[host][harness] slug` form (quoted) for non-claude or foreign-host windows.

## Refuses

Any window whose slug is `main`. Use `systemctl --user stop agent-tmux` if you really want the persistent session down.

## Typical flow

1. `agent-list` to confirm the target.
2. `agent-kill <slug>`.
3. If the user expected output capture before kill, run `agent-peek <slug>` first.

## Constraints

- **Destructive.** Closes the window, ending the agent's process. The agent gets no clean shutdown — uncommitted state is lost.
- **Mobile session disappears.** A killed Claude Code window with `--rc` drops off the mobile session list immediately.
