---
name: kill-claude
description: Shut down a spawned Claude Code instance by closing its tmux window. Use when the user asks to stop, end, close, or kill a helper Claude — e.g. "kill the auth-refactor Claude", "close the deploy-watcher", "end the helper". Refuses to kill the persistent `main` session (use `systemctl --user stop claude-tmux` for that).

# kill-claude

Closes a tmux window inside the `main` session, which exits the Claude process running in it. Safe to use on any spawn produced by `spawn-claude` or `spawn-claude-sandbox`.

## How to kill

```
claude-kill <window>
```

`<window>` can be a bare slug (`auth-refactor`) — the script auto-decorates to `[<hostname>] <name>`, matching the convention `claude-spawn` uses. If you're targeting a window from another host, pass the full `[otherhost] name` form instead (quoted — it contains a space and brackets). List active windows with `claude-list` (or `tmux list-windows -t main`). The script adds tmux's `=` exact-match prefix internally, so you do not need to include it.

## What it refuses

- `claude-kill main` or `claude-kill "[<hostname>] main"` — both resolve to this host's persistent session window kept alive by `claude-tmux.service`. The script blocks either form.

If the user actually wants the main session down (maintenance, reinstall), that's `systemctl --user stop claude-tmux`, not this skill.

## Typical flow

1. `tmux list-windows -t main` to see what's running.
2. Confirm with the user which one to close (especially if names are ambiguous).
3. `claude-kill "<window>"`.
4. Report what you closed. Optionally run `tmux list-windows -t main` after to show the updated state.

## Constraints

- **No graceful shutdown.** This closes the window, which SIGHUPs the claude process. Claude doesn't persist in-progress chat state across windows, so there's nothing to save — but don't use this if the user explicitly wants a clean `/exit`. For that, use `claude-talk <window> /exit` instead.
- **Remote Control session disappears from the mobile app** the moment the window closes. If the user is actively viewing it on their phone, warn them first.
