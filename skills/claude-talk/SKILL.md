---
name: claude-talk
description: Send input (a slash command, a chat message, a config toggle) to a Claude Code instance running in a named tmux window inside the `main` session. Use when the user asks to configure, activate features on, or pass a message to an already-spawned Claude — e.g. "turn on remote control for the auth-refactor Claude", "tell the helper Claude to also run the linter", "rename that session to X".
---

# claude-talk

This skill relays keystrokes into a Claude Code TUI running in another tmux window. Common uses:

- Activating Remote Control on a running session: send `/rc` or `/rc <name>`.
- Renaming a session for the mobile session list: send `/rename <name>`.
- Opening `/config` and toggling options (requires further send-keys to navigate the menu — avoid unless needed).
- Sending a follow-up chat message to a spawned Claude.

## How to send

```
claude-talk <window> <text...>
```

(Installed into `~/.local/bin` by `setup.sh`.)

`<window>` is the tmux window name inside session `main`. Window names are decorated at spawn time as `[<hostname>] <name>` (e.g. `[myvps] main`, `[myvps] auth-refactor`) so sessions from different hosts stay distinguishable in the mobile app. List them with `tmux list-windows -t main` and pass the full name verbatim — quote it because it contains a space. The script handles tmux's `=` exact-match prefix internally, so you do *not* need to add `=` yourself. The script appends Enter automatically.

Example:

```
claude-talk "[myvps] auth-refactor" /rc
```

## After sending `/rc`

If the user wants the mobile URL returned directly, wait a few seconds then capture the pane:

```
sleep 5
tmux capture-pane -p -t "main:=<window>" | grep -oE 'https://claude\.ai/code/[^ ]+' | head -1
```

(Note the `=` exact-match prefix — without it, tmux treats the `[...]` in the window name as a character-class glob. Needed for `capture-pane` even though `claude-talk` itself handles it for you.)

Return that URL to the user so they don't have to attach to find it.

## Constraints — IMPORTANT

- **send-keys blindly injects.** It's reliable when the target Claude is at its prompt. If the target is mid-menu, mid-tool-approval, or showing a picker, your text becomes input to that state instead of a chat message. Before sending a message to a session you haven't been driving, consider `tmux capture-pane -p -t "main:=<window>" | tail -20` to sanity-check its state.
- **Shell quoting applies.** The script passes `"$*"` to `send-keys`. Text with quotes, backticks, or `$` needs escaping when you invoke the script.
- **Don't send `/exit` or `/clear` without explicit user request** — those are destructive to the target session's state.
