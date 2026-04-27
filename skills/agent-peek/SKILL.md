---
name: agent-peek
description: Read back the current pane contents of a spawned LLM-CLI window in the `main` tmux session — what the helper just said, whether it's stuck at a prompt, or what tool call it's currently running. Use before deciding to talk/kill/ignore a helper, when the user asks "what is X doing", or when triaging a fleet. Observational only — does not send input.
---

# agent-peek

Read-only counterpart to `agent-talk` and `agent-list`. `agent-talk` writes to a helper; `agent-list` inventories them; `agent-peek` reads what one is showing. Harness-agnostic — it captures whatever the TTY rendered, regardless of which CLI is running.

## How to peek

```
agent-peek [-n <lines>] <window>
```

- `<window>` — bare slug (`auth-refactor`) auto-decorated to `[<host>][claude] auth-refactor`. To peek at a non-claude or foreign-host window, pass the full `[host][harness] slug` form (quoted — contains spaces). The script handles exact matching internally; no `=` prefix needed.
- `-n <lines>` — extends capture backward into tmux scrollback by that many lines. Without it, you get exactly what's currently on screen.

## Typical flow

1. `agent-list` to see what's running and which harnesses are active.
2. `agent-peek <slug>` to read the visible state.
3. **Summarize** to the user — don't dump the raw capture. Each harness has its own TUI quirks; the user wants the signal, not the box-drawing.
4. If action is needed, use `agent-talk` / `agent-kill` accordingly.

## Parsing tips

- Strip box-drawing if you want plain text: `agent-peek ... | sed 's/[│─┌└┐┘├┤┬┴┼╭╮╯╰]/ /g' | sed 's/[[:space:]]\+$//'`.
- The pane almost always ends with the input prompt — the last non-empty line is rarely the "answer".
- Empty output / non-zero exit means the window is gone; `agent-list` to confirm.

## Constraints

- **Observational.** No keystrokes sent.
- **Snapshot, not stream.** One-shot read; re-run for an updated view.
- **Scrollback bounded** by tmux's `history-limit` (default 2000 lines).
