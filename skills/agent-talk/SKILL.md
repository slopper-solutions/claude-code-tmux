---
name: agent-talk
description: Send input (a slash command, a chat message, a config toggle) to an LLM-CLI instance running in a named tmux window inside the `main` session. Use when the user asks to configure, activate features on, or pass a message to an already-spawned agent — e.g. "turn on remote control for the auth-refactor agent", "tell the helper to also run the linter", "rename that session to X".
---

# agent-talk

Relays keystrokes into an LLM TUI running in another tmux window. Harness-agnostic at the send-keys layer. Common uses for Claude Code targets:

- Activating Remote Control on a running session: send `/rc` or `/rc <name>`.
- Renaming a session for the mobile session list: send `/rename <name>`.
- Sending a follow-up chat message.

For non-Claude harnesses (Codex, Gemini, OpenCode), `agent-talk` works mechanically — text goes into the TUI's input — but slash commands and the paste-vs-Enter timing may not be a perfect fit. Phase 2 will dispatch per-harness adapters; until then, expect Claude-tuned behavior.

## How to send

```
agent-talk <window> <text...>
```

`<window>` is the tmux window slug. Bare slugs (`auth-refactor`) are decorated to `[<host>][claude] auth-refactor` by default. To target a non-claude harness or a foreign host, pass the full bracket-prefixed name verbatim (quoted — it contains spaces):

```
agent-talk "[myvps][codex] auth-refactor" /help
```

The script handles tmux's `=` exact-match prefix internally. It appends Enter automatically. Legacy `[<host>] <slug>` windows from pre-rename installs are still recognized.

## After sending `/rc` (Claude Code)

If the user wants the mobile URL returned:

```
sleep 5
tmux capture-pane -p -t "main:=<window>" | grep -oE 'https://claude\.ai/code/[^ ]+' | head -1
```

Note the `=` — needed for `capture-pane` even though `agent-talk` itself handles it for you.

## Constraints — IMPORTANT

- **send-keys blindly injects.** Reliable when the target is at its prompt; if it's mid-menu or mid-tool-approval, your text becomes input to that state. Before sending to a session you haven't been driving, sanity-check with `agent-peek <window> | tail -20`.
- **Shell quoting applies.** The script passes `"$*"` to `send-keys`. Text with quotes, backticks, or `$` needs escaping when invoking the script.
- **Don't send `/exit` or `/clear` without explicit user request** — destructive to the target session's state.
