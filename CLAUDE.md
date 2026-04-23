# CLAUDE.md

This repo is a turnkey VPS bootstrap for running Claude Code in a persistent tmux session, reachable from the Claude mobile app via `--rc`. The design target is "cheap VPS, one user, a handful of concurrent Claudes" — not a multi-tenant orchestrator.

## Design principles

Load-bearing. When a proposed change doesn't fit, the right answer is usually "don't make it" or "push back on the request."

- **Shell-only, POSIX `sh`.** No bash-isms (`[[`, `<<<`, arrays, `$RANDOM`-dependence). If a feature requires bash, Python, or Node, that's a signal the feature belongs in a different project.
- **Minimalism over breadth.** The repo is small on purpose. Before adding a script, check whether the primitive already exists and a skill doc would be enough to expose it. Before adding a flag, check whether the config file would be a better home.
- **One script, one verb.** `claude-<verb>` naming. A script that wants to do two distinct things should become two scripts.
- **Config lives in one file.** `config.env` is strict `KEY=VALUE`, no shell expansion, because it is loaded both by systemd `EnvironmentFile=` and by shell `.` sourcing. Don't add shell syntax to it.
- **Window names carry the hostname.** The `[<host>] <slug>` format is load-bearing — it keeps multiple VPS hosts distinguishable in the Claude mobile session list. Don't shorten, omit, or URL-encode it.
- **`--rc` is the mobile primitive.** Built into Claude Code; don't reinvent the transport layer (no Discord bots, no custom sockets, no web dashboards baked into this repo).
- **No runtime deps beyond tmux, systemd, coreutils, and optionally bwrap.** Anything else is out.
- **Stay current with Claude Code.** This repo is a thin wrapper. When Claude Code ships a new flag, feature, or install mechanism, check whether to adopt it. When it deprecates something we use, migrate. Diverging from Claude Code's conventions is how this project rots.

## Layout

- `bin/claude-*` — all helper scripts, one verb each (`claude-spawn`, `claude-spawn-sandbox`, `claude-talk`, `claude-peek`, `claude-kill`, `claude-list`, `claude-random-name`, `claude-tmux-launch`). Symlinked into `~/.local/bin/` by `setup.sh`.
- `claude-tmux.service` — systemd user unit; invokes `bin/claude-tmux-launch` via the installed `~/.local/bin` copy.
- `config.env` — reference file documenting `REMOTE_CONTROL` and `SKIP_PERMISSIONS`. The actual runtime config is written to `~/.config/remote-claude/config.env` interactively on first install.
- `skills/<name>/SKILL.md` — how a live Claude discovers each helper.
- `ssh-autoattach.sh` — login-shell snippet that drops SSH users into the main session.
- `setup.sh` — one-shot installer. Expected to be interactive.

## When making changes

- Every script starts with a one-line purpose comment and a usage line. Longer explanation goes in the matching skill file, not the script body.
- If you touch a script's flags, update the matching skill doc in the same commit.
- Don't hardcode `/home/<user>` paths. Use `$HOME`, `%h` (systemd specifier), or `~` for display strings only (never as an actual path argument — `~` doesn't expand inside double quotes).
- Tmux targets with brackets need the `=` exact-match prefix (e.g. `tmux send-keys -t "main:=[host] name"`). Scripts should handle the prefix internally so callers pass bare names.
- `set -e` everywhere. Use `cmd || true` deliberately when you want to suppress a failure.
- Test script changes against a temporary `HOME` with a fake `claude` binary on `PATH`, rather than against a real install. `sh -n <script>` for syntax, then a sandboxed exec.
- Commits describe the *why*. The *what* is in the diff.

## What's deliberately out of scope

These have been considered and rejected for this repo. Point at the named alternative rather than reimplementing:

- Agent farms / parallel multi-Claude orchestration / CI auto-fixers — see `claude_code_agent_farm`, `ComposioHQ/agent-orchestrator`.
- Git-worktree-per-agent isolation — orthogonal approach; our isolation primitive is bwrap (`claude-spawn-sandbox`).
- Notification bridges (ntfy / Discord / Telegram) — see `tap-to-tmux`, or Claude Code Channels. If added here, it belongs in a separate opt-in script, not baked into the core.
- Web dashboards, TUI frontends, multi-user support.

## Compare-yourself audit

The point of this audit is catching Claude Code drift, not re-litigating repo design. A live Claude working here can be asked:

> Compare this repo against current Claude Code. Flag anything we should adopt, anything we use that's been deprecated, and anything an official Claude Code feature would handle better than our wrappers.

The audit is only as good as the Claude running it. It should pull current state from `claude --help`, `claude --version`, the `claude-code-guide` subagent, or `WebFetch` of `code.claude.com` / the official changelog before flagging anything — knowledge-cutoff recall alone will miss recent changes. Output should cite specific deltas (new flags, renamed commands, install-path changes, newly-stabilized features) with pointers to where in the repo they'd land, not broad rewrites.

Keep this file short enough that audits against it remain useful; if it grows into architecture docs that duplicate the code, it starts rotting against the code and should be trimmed back.
