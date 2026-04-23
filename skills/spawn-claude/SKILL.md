---
name: spawn-claude
description: Spawn a new Claude Code instance in a tmux window inside the persistent `main` session, with Remote Control enabled so the user can attach from their phone via the Claude mobile app. Use when the user asks to start a helper Claude, a parallel/background Claude, or a new mobile-accessible session. Accepts an optional name and an optional handoff prompt sent after startup.
---

# spawn-claude

The persistent tmux session `main` is managed by the `claude-tmux.service` user unit. Each spawned Claude runs in its own named window inside that session, launched with `claude --rc "<name>"` so Remote Control is on from the start. From a phone the user opens the Claude app and picks the session out of the list; from a laptop they can `tmux attach -t main` and switch with `Ctrl-b w`.

## How to spawn

```
claude-spawn [--rc|--no-rc] [--yolo|--safe] [<name>] [<handoff prompt>]
```

(`claude-spawn` is installed into `~/.local/bin` by `setup.sh`, so it's on PATH.)

Positional args are all optional but order-dependent. Omit the name to get an auto-generated three-word identifier like `brave-swift-fox` (what3words-style — more memorable than a timestamp). The script prints the window target on success — it will look like `main:=[<hostname>] <name>`, using tmux's `=` exact-match prefix because window names contain `[` and `]`.

## Flags (per-call overrides of config defaults)

Defaults for both come from `~/.config/remote-claude/config.env` (`REMOTE_CONTROL`, `SKIP_PERMISSIONS`); when the file is absent, both are on. Flags override for one call only:

- `--rc` / `--no-rc` — force Remote Control on/off. `--no-rc` means the spawn will not be reachable from the mobile app; useful for a strictly-local helper the user doesn't want cluttering the session list.
- `--yolo` / `--safe` — `--yolo` forces `--dangerously-skip-permissions` on (auto-approve every tool call); `--safe` forces it off (prompt for each tool use, the normal Claude Code behaviour). Pick `--safe` when handing the new Claude an untrusted task you want friction in front of.
- `--` ends flag parsing, in case a name or prompt starts with `-`.

## Choosing a name

The name is used for both the tmux window and the Remote Control session title — it's what the user sees in the Claude app's session list. Pick something descriptive:

- If the handoff prompt names a task ("watch the deploy"), use a short slug of that task (`deploy-watcher`).
- If the user gave no context ("spawn another Claude"), let the script auto-generate.
- Use only alphanumerics and hyphens — the script passes the name through shell quoting, so spaces or special characters are brittle.

The script automatically decorates whatever you pass into `[<hostname>] <name>`, so `claude-spawn deploy-watcher` produces a window and RC session titled `[<hostname>] deploy-watcher`. Pass the *bare* name; do not include the brackets or hostname yourself. The decoration makes sessions from different VPS hosts distinguishable in the mobile session list.

## Writing the handoff prompt

The spawned Claude starts cold. Treat the prompt like briefing a new colleague:

- Self-contained: name the task, relevant paths, what "done" looks like.
- No deictic references ("you", "this", "the file we were looking at") — the new Claude has no idea what those mean.
- If the task shouldn't touch the same files as the current session, say so explicitly: `cd ~/work/<somewhere>` as the first instruction, or skip the prompt and have the user brief it manually.

## Returning the mobile URL to the user

Once the spawn script returns, wait a few seconds for `--rc` to register and then capture the pane to fish out the session URL:

```
sleep 5
tmux capture-pane -p -t <window-target> | grep -oE 'https://claude\.ai/code/[^ ]+' | head -1
```

where `<window-target>` is exactly what the spawn script printed (e.g. `main:=[<hostname>] deploy-watcher`). Always keep the `=` — without it, tmux treats `[...]` as a character-class glob and may match the wrong window.

Hand that URL back to the user. That lets them jump into the session from their phone without attaching via SSH first.

## After spawning — tell the user

1. The window target as printed (`main:=[<hostname>] <name>`).
2. The mobile URL (if you captured it).
3. How to attach locally if they want: `tmux attach -t main` then `Ctrl-b w` to pick the window interactively.
4. How to list active Claudes: `tmux list-windows -t main`.

## Constraints to flag

- **No filesystem isolation.** Two spawned Claudes touching the same repo can collide on git state or working files. If the task involves shared state, include a dedicated `cd` in the handoff prompt.
- **Claude.ai OAuth required.** `--rc` only works if the user is logged in via `/login` (not API key). If spawn fails with a login error, they need to run `claude` once and `/login` first.
- **API quota is per-session.** Mention only if the user is about to spawn several at once.
