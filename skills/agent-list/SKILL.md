---
name: agent-list
description: List all LLM-CLI instances running in the `main` tmux session, with detected harness type and main-vs-helper role. Use to inventory active agents before sending a message, killing one, or briefing the user on what's running.
---

# agent-list

Inventory of windows in the `main` tmux session.

## How to list

```
agent-list
```

(Installed into `~/.local/bin` by `setup.sh`.)

## Output

Tab-separated, stable, three columns:

```
main    claude    [myvps][claude] main
helper  claude    [myvps][claude] auth-refactor
helper  codex     [myvps][codex] deploy-watcher
helper  claude    [otherhost][claude] research
```

- **role** — `main` if the window slug is `main`, else `helper`.
- **harness** — parsed from the window-name prefix. Legacy `[<host>] <slug>` windows from pre-rename installs are reported as harness=`claude`.
- **window-name** — full bracket-prefixed name; pass it directly to `agent-talk`, `agent-peek`, or `agent-kill`.

## Typical flow

1. User asks "what's running".
2. `agent-list` and summarize: count by harness, name the helpers, flag anything unexpected.
3. Don't dump the raw output unless asked — the user wants signal.

## Constraints

- **Names only — no state.** `agent-list` doesn't tell you whether an agent is busy, idle, or stuck. For that, `agent-peek <window>`.
- **Local session only.** Lists windows in `main` on this host; cross-host inventory requires logging into the other host.
