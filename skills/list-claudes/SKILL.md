---
name: list-claudes
description: List all Claude Code instances currently running in the persistent `main` tmux session. Use when the user asks what Claudes are running, what helpers exist, before deciding whether to spawn another or kill an existing one, or when triaging a session list they've lost track of — e.g. "what Claudes are running", "list the helpers", "show me the active sessions".

# list-claudes

Inventories windows inside the `main` tmux session. Each window is one Claude instance. Output labels which is the persistent main session (managed by `claude-tmux.service`, protected from `claude-kill`) versus spawned helpers.

## How to list

```
claude-list
```

(Installed into `~/.local/bin` by `setup.sh`.) Tab-separated output:

```
main	[myvps] main
helper	[myvps] auth-refactor
helper	[myvps] deploy-watcher
```

Column 1 is the role (`main` or `helper`). Column 2 is the window name, which is the exact value to pass — quoted — to `claude-talk` or `claude-kill`. Names contain a space and brackets.

## Parsing tips

- Split on the first tab. `cut -f1` for role, `cut -f2-` for name (use `-f2-` in case the name contains further tabs, though by convention it won't).
- If the session doesn't exist, `claude-list` exits non-zero with a message on stderr pointing at `systemctl --user status claude-tmux`. Don't treat that as "zero Claudes" — the service itself is down.

## Typical flow

1. User asks "what Claudes do I have running?" → run `claude-list`, relay the list.
2. User asks "is the deploy-watcher still up?" → run `claude-list`, grep for the name.
3. Before spawning, especially without a specific name from the user, list first to avoid collisions.
4. Before killing, list to confirm the exact window name (which is what `claude-kill` needs).

## What this skill does *not* show

- Pane contents or what each Claude is currently doing — use `tmux capture-pane -p -t "main:=<name>"` for that.
- Mobile `--rc` URLs — those are printed at spawn time; `tmux capture-pane` on the target window usually still has the URL in scrollback.
- Other tmux sessions — only the `main` session is inventoried, because that's the one managed by this toolkit.
