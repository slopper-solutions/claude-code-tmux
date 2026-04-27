---
name: spawn-agent
description: Spawn a new LLM-CLI harness instance (Claude Code, Codex CLI, Gemini CLI, OpenCode) in a tmux window inside the persistent `main` session. Use when the user asks to start a helper agent, a parallel/background agent, or a new mobile-accessible session. Accepts a harness selector, an optional name, and an optional handoff prompt sent after startup.
---

# spawn-agent

The persistent tmux session `main` is managed by the `agent-tmux.service` user unit. Each spawned agent runs in its own named window inside that session, decorated as `[<host>][<harness>] <name>`. Claude Code spawns get `--rc "<name>"` so Remote Control is on from the start, making them reachable from the Claude mobile app.

## How to spawn

```
agent-spawn [--rc|--no-rc] [--yolo|--safe] [--harness=<name>] [<name>] [<handoff prompt>]
```

(`agent-spawn` is installed into `~/.local/bin` by `setup.sh`, so it's on PATH.)

Positional args are all optional but order-dependent. The harness defaults to `claude` if not specified. Omit the name to get an auto-generated three-word identifier like `brave-swift-fox` (what3words-style — more memorable than a timestamp). The script prints the window target on success — `main:=[<host>][<harness>] <name>`, using tmux's `=` exact-match prefix because window names contain `[` and `]`.

## Picking a harness

`--harness=<name>` selects which CLI to launch. The current registry lives in `~/.config/agents/harnesses.d/`, one file per harness:

- `claude` — Claude Code (Anthropic). The default. Mobile-app reachable via `--rc`. Sandbox-compatible.
- `codex`, `gemini`, `opencode` — registered for dispatch but adapter not yet implemented as of Phase 1. Spawning these will refuse with a clear error pointing at what's missing (paste/idle behavior verification). Phase 2 wires per-harness adapters; until then, only `claude` is operational.

## Flags (per-call overrides of config defaults)

Defaults for `--rc` and `--yolo` come from `~/.config/agents/config.env` (`REMOTE_CONTROL`, `SKIP_PERMISSIONS`); both on if file missing. Per-harness behavior (does this harness *support* `--rc`? does it support skip-permissions?) comes from `harnesses.d/<harness>.conf` — flags that don't apply to the chosen harness are silently dropped.

- `--rc` / `--no-rc` — force Remote Control on/off. `--no-rc` keeps the spawn off the mobile session list.
- `--yolo` / `--safe` — `--yolo` forces auto-approve-all-tool-calls on; `--safe` forces it off (per-tool prompts).
- `--harness=<name>` — pick the harness. Defaults to `claude`.
- `--` ends flag parsing if a name or prompt starts with `-`.

## Choosing a name

The name is used for both the tmux window and (for Claude Code) the Remote Control session title — what the user sees in the mobile app's session list. Pick something descriptive:

- If the handoff prompt names a task ("watch the deploy"), use a short slug of that task (`deploy-watcher`).
- If the user gave no context ("spawn another"), let the script auto-generate.
- Use only alphanumerics and hyphens — the script passes the name through shell quoting, so spaces or special characters are brittle.

The script automatically decorates whatever you pass into `[<host>][<harness>] <name>`. Pass the *bare* name; do not include the brackets, hostname, or harness tag yourself. The decoration makes sessions from different VPS hosts and different harnesses distinguishable in the mobile session list.

## Writing the handoff prompt

The spawned agent starts cold. Treat the prompt like briefing a new colleague:

- Self-contained: name the task, relevant paths, what "done" looks like.
- No deictic references ("you", "this", "the file we were looking at") — the new agent has no idea what those mean.
- If the task shouldn't touch the same files as the current session, say so explicitly: `cd ~/work/<somewhere>` as the first instruction, or skip the prompt and have the user brief it manually.

## Returning the mobile URL to the user (Claude Code only)

For Claude Code spawns with `--rc`, capture the pane to fish out the session URL:

```
sleep 5
tmux capture-pane -p -t <window-target> | grep -oE 'https://claude\.ai/code/[^ ]+' | head -1
```

where `<window-target>` is exactly what the spawn script printed (e.g. `main:=[<host>][claude] deploy-watcher`). Always keep the `=` — without it, tmux treats `[...]` as a character-class glob and may match the wrong window. Non-Claude harnesses don't have a mobile URL — they're SSH-only.

## After spawning — tell the user

1. The window target as printed (`main:=[<host>][<harness>] <name>`).
2. The mobile URL if you captured one (Claude Code spawns only).
3. How to attach locally: `tmux attach -t main` then `Ctrl-b w` to pick the window interactively.
4. How to list active agents: `agent-list`.

## Constraints to flag

- **No filesystem isolation** unless using `agent-spawn-sandbox`. Two spawned agents touching the same repo can collide on git state.
- **`--rc` is Claude-Code-only.** Codex / Gemini / OpenCode spawns are SSH-only.
- **Stub harnesses refuse to spawn.** Only `claude` is operational in Phase 1.
