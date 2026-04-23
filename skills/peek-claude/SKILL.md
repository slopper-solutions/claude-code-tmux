---
name: peek-claude
description: Read back the current pane contents of a spawned Claude Code window in the `main` tmux session — what the helper just said, whether it's stuck at a prompt, or what tool call it's currently running. Use before deciding to talk/kill/ignore a helper, when the user asks "what is X doing", or when triaging a fleet. Observational only — does not send input.

# peek-claude

Read-only counterpart to `claude-talk` and `claude-list`. `claude-talk` writes to a helper; `claude-list` inventories them; `claude-peek` reads what one is showing.

## How to peek

```
claude-peek [-n <lines>] <window>
```

- `<window>` — the decorated window name (e.g. `[myvps] auth-refactor`). Quote it; it contains a space. Bare name only (no `=` prefix — the script handles exact matching internally).
- `-n <lines>` — extends the capture backward into tmux scrollback by that many lines. Without it, you get exactly what's currently on screen.

Installed into `~/.local/bin` by `setup.sh`.

## Typical flow

1. `claude-list` to see what's running.
2. `claude-peek "[myvps] auth-refactor"` to read the visible state.
3. **Summarize** to the user — don't dump the raw capture. "It's in the middle of running a test; last message is about a failing assertion in `foo_test.py`." The capture can be ~30 lines of box-drawn TUI; the user wants the signal.
4. If action is needed (reply, interrupt, kill), use the appropriate sibling skill.

## What the output looks like

Claude Code's TUI uses Unicode box-drawing for borders (`│ ─ ┌ ┐ └ ┘ ├ ┤`). The bottom of the pane is the input prompt area; above it, the most recent assistant message; above that, the most recent user turn, and so on up. Sparse lines or a big empty pane bottom usually means idle / waiting for input. A progress indicator or "Running tool: …" line usually means mid-task.

If you need full history rather than just the visible region, add `-n 200` or so. Don't go unbounded — very large captures waste orchestrator context with little added signal.

## Parsing tips

- Strip box-drawing if you want plain text: `claude-peek ... | sed 's/[│─┌└┐┘├┤┬┴┼╭╮╯╰]/ /g' | sed 's/[[:space:]]\+$//'`.
- The pane almost always ends with the input prompt — the last non-empty line is rarely the "answer."
- Empty output / "no server running" / exit code non-zero means the window is gone; `claude-list` to confirm.

## Constraints

- **Observational.** Does not change the helper's state. No keystrokes sent.
- **Text-only.** Screenshots of the mobile app are not available; you see what the TTY rendered.
- **Snapshot, not stream.** One-shot read; re-run for an updated view. There is no `-f` / follow mode (intentional — streaming into orchestrator context is wasteful).
- **Scrollback is bounded** by tmux's `history-limit` (default 2000 lines per pane). Long-running Claudes may have already rotated out their earliest turns.
