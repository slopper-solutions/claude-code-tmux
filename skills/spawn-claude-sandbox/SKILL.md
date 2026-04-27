---
name: spawn-claude-sandbox
description: DEPRECATED — use the harness-neutral `spawn-agent-sandbox` skill instead. This skill is kept only so existing references resolve. New work should call `agent-spawn-sandbox`, not `claude-spawn-sandbox`.
---

# spawn-claude-sandbox (deprecated)

Superseded by [`spawn-agent-sandbox`](../spawn-agent-sandbox/SKILL.md). The underlying `claude-spawn-sandbox` script is now a thin forwarder; it still works but prints a deprecation warning.

Migration: replace `claude-spawn-sandbox ...` with `agent-spawn-sandbox ...` — flags and positional args are unchanged.
