---
name: list-claudes
description: DEPRECATED — use the harness-neutral `agent-list` skill instead. This skill is kept only so existing references resolve. New work should call `agent-list`, not `claude-list`.
---

# list-claudes (deprecated)

Superseded by [`agent-list`](../agent-list/SKILL.md). The underlying `claude-list` script is now a thin forwarder.

Output format note: `agent-list` adds a harness column (3 columns: role, harness, window-name) compared to the old 2-column `claude-list` output. Scripts that parsed the old format need updating.

Migration: replace `claude-list` with `agent-list`.
