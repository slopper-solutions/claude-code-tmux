---
name: spawn-claude-sandbox
description: Spawn a Claude Code instance confined to a single directory via bubblewrap. Use when the user wants a helper Claude that cannot touch files outside a given folder, when spawning several Claudes that must not collide on each other's working trees, or when handing a new Claude a prompt that should be scope-limited. Requires `bwrap` installed on the host. Still uses `--rc` so the sandboxed session is reachable from the Claude mobile app.
---

# spawn-claude-sandbox

Same persistent-tmux model as `spawn-claude`, but the child Claude runs inside `bwrap`:

- Root filesystem is mounted read-only — Claude can read system tools and its own binary but cannot modify them.
- Only the named project dir is writable.
- Claude's own state (`~/.config/claude`, `~/.claude`, `~/.cache/claude`) is bound read-write so the session, auth, and skills work.
- Network is shared with the host — required for `--rc` to register the session with claude.ai.
- `--dangerously-skip-permissions` is passed inside the sandbox. The sandbox is the fence; per-tool prompts add nothing.

## How to spawn

```
claude-spawn-sandbox [--rc|--no-rc] [--yolo|--safe] <dir> [<name>] [<prompt>]
```

(Installed into `~/.local/bin` by `setup.sh`.)

- `<dir>` is required and will be created if missing.
- `[name]` becomes the tmux window name and `--rc` session title; auto-generated as a memorable three-word slug (e.g. `brave-swift-fox`) if omitted. The script decorates whatever you pass into `[<hostname>] <name>`, so `claude-spawn-sandbox ./proj scoped-refactor` yields a window/session titled `[<hostname>] scoped-refactor`. Pass the bare name; don't include brackets or the hostname yourself.
- `[prompt]` is sent after startup. Same briefing rules as `spawn-claude` — self-contained, no deictic references.

## Flags (per-call overrides of config defaults)

Defaults come from `~/.config/remote-claude/config.env` (`REMOTE_CONTROL`, `SKIP_PERMISSIONS`); when the file is absent, both are on. Flags override for one call only:

- `--rc` / `--no-rc` — force Remote Control on/off. `--no-rc` keeps the sandbox entirely off the mobile session list.
- `--yolo` / `--safe` — `--yolo` forces `--dangerously-skip-permissions` on inside the sandbox; `--safe` forces per-tool prompts. Since the sandbox already confines writes, `--safe` here is the "belt and suspenders" combination: filesystem fence *plus* tool-level friction.
- `--` ends flag parsing.

The script prints the full window target on success (e.g. `main:=[<hostname>] scoped-refactor`). The `=` is tmux's exact-match prefix — leave it in any follow-up `tmux` command, otherwise the `[...]` in the name is treated as a character-class glob. To capture the mobile URL, use exactly that target:

```
sleep 5
tmux capture-pane -p -t <window-target> | grep -oE 'https://claude\.ai/code/[^ ]+' | head -1
```

## When to pick this over plain `spawn-claude`

- User explicitly asks for confinement.
- Multiple spawns need to work on different repos without stepping on one another.
- You're handing the child an untrusted or exploratory prompt and want blast-radius limits.

For a helper working alongside the current session on the same files, plain `spawn-claude` is simpler.

## Constraints to flag

- **`bwrap` must be installed.** `apt-get install bubblewrap` on Debian/Ubuntu, `pacman -S bubblewrap` on Arch.
- **Reads are not restricted.** The root FS is visible read-only — Claude can still read `/etc/passwd`, other projects in `$HOME`, etc. The sandbox only prevents *writes* outside `<dir>`.
- **Network is not isolated.** The sandboxed Claude can reach anywhere the host can, including claude.ai. Data exfil via network is possible.
- **Auth state is shared.** All sandboxed and un-sandboxed Claudes on the box use the same claude.ai OAuth session and count against the same quota.
- **No filesystem isolation *between* sandboxes of the same dir.** If two sandbox spawns target the same `<dir>`, they'll collide on it just like `spawn-claude` instances would.
