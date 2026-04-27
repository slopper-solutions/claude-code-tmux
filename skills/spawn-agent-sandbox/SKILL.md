---
name: spawn-agent-sandbox
description: Spawn an LLM-CLI harness instance confined to a single directory via bubblewrap. Use when the user wants a helper agent that cannot touch files outside a given folder, when spawning several agents that must not collide on each other's working trees, or when handing a new agent a prompt that should be scope-limited. Requires `bwrap` installed on the host.
---

# spawn-agent-sandbox

Sandboxed counterpart to `spawn-agent`. Same window-naming convention (`[<host>][<harness>] <name>`); same `--rc` / `--yolo` flag semantics; same harness selector. The harness must declare `SANDBOX_OK=1` in `harnesses.conf` — at Phase 1, only `claude` qualifies.

## How to spawn

```
agent-spawn-sandbox [--rc|--no-rc] [--yolo|--safe] [--harness=<name>] <dir> [<name>] [<prompt>]
```

`<dir>` is required — that's the sandbox root. The agent runs with `/` mounted read-only, fresh `/tmp` `/dev` `/proc`, and `<dir>` plus the harness's own state dirs as the only read-write paths. Network is shared so `--rc` / OAuth still work.

## When to use this over `agent-spawn`

- Untrusted task: prompt arrives from somewhere you don't fully trust (web content, third-party issue text, another agent's output).
- Parallel agents on isolated work: each gets its own `<dir>`, no git collisions, no cross-talk.
- Experimenting: trying a refactor in a copy without risking the real tree.

## Caveats

- `bwrap` must be installed (`apt-get install bubblewrap` on Debian/Ubuntu, `pacman -S bubblewrap` on Arch).
- Auth state (`~/.claude`, `~/.config/claude`) is bind-mounted read-write so login persists. A compromised sandboxed agent can corrupt these.
- Stub harnesses with `SANDBOX_OK=0` are refused.

## After spawning

Same as `spawn-agent` — print the window target, mobile URL (Claude only), and how to attach. Note that the sandboxed agent *cannot* see files outside its `<dir>` — if the task references paths outside, it will fail.
