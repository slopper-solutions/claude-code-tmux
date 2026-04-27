---
name: kill-claude
description: DEPRECATED — use the harness-neutral `agent-kill` skill instead. This skill is kept only so existing references resolve. New work should call `agent-kill`, not `claude-kill`.
---

# kill-claude (deprecated)

Superseded by [`agent-kill`](../agent-kill/SKILL.md). The underlying `claude-kill` script is now a thin forwarder.

Migration: replace `claude-kill ...` with `agent-kill ...` — usage is identical.
