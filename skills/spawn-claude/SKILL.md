---
name: spawn-claude
description: DEPRECATED — use the harness-neutral `spawn-agent` skill instead (it accepts `--harness=claude` as the default and behaves identically). This skill is kept only so existing references resolve. New work should call `agent-spawn`, not `claude-spawn`.
---

# spawn-claude (deprecated)

This skill has been superseded by [`spawn-agent`](../spawn-agent/SKILL.md), which is harness-neutral and selects Claude Code by default. Use that one.

The underlying `claude-spawn` script is now a thin forwarder to `agent-spawn --harness=claude`; it still works but prints a deprecation warning and will be removed in a future release.

Migration: replace `claude-spawn ...` with `agent-spawn ...` — flags and positional args are unchanged. Note that window names now carry a harness tag: `[<host>][claude] <slug>` instead of the old `[<host>] <slug>`.
