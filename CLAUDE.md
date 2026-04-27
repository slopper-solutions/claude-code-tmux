# CLAUDE.md

This repo is a turnkey VPS bootstrap for running Claude Code in a persistent tmux session, reachable from the Claude mobile app via `--rc`. The design target is "cheap VPS, one user, a handful of concurrent Claudes" — not a multi-tenant orchestrator.

## Design principles

Load-bearing. When a proposed change doesn't fit, the right answer is usually "don't make it" or "push back on the request."

- **Shell-only, POSIX `sh`.** No bash-isms (`[[`, `<<<`, arrays, `$RANDOM`-dependence). If a feature requires bash, Python, or Node, that's a signal the feature belongs in a different project.
- **Minimalism over breadth.** The repo is small on purpose. Before adding a script, check whether the primitive already exists and a skill doc would be enough to expose it. Before adding a flag, check whether the config file would be a better home.
- **One script, one verb.** Canonical naming is `agent-<verb>` (harness-neutral) — `agent-spawn`, `agent-talk`, etc. The legacy `claude-<verb>` scripts remain as deprecated forwarders. A script that wants to do two distinct things should become two scripts.
- **Config is POSIX KV, no extra deps.** `config.env` (strict `KEY=VALUE`, no shell expansion — loaded both by systemd `EnvironmentFile=` and by shell `.` sourcing) holds runtime defaults. The harness map is split per-harness under `harnesses.d/<name>.conf`, each file a flat KV (`BINARY=`, `RC_FLAG=`, `RC_TAKES_NAME=`, `YOLO_FLAG=`, `SANDBOX_OK=`, `STATUS=`). The dispatchers source the one file matching the requested harness — no eval, no prefix gymnastics. Adding a harness = dropping a new file. JSON/TOML are out: they'd require `jq` / a parser, breaking the no-runtime-deps rule.
- **Window names carry the hostname *and* harness.** The `[<host>][<harness>] <slug>` format is load-bearing — it keeps multiple VPS hosts and multiple harnesses distinguishable in the mobile session list and in `agent-list` output. Don't shorten, omit, or URL-encode it. `agent-*` readers also accept legacy `[<host>] <slug>` windows from pre-rename installs (treated as harness=claude).
- **`--rc` is the mobile primitive.** Built into Claude Code; don't reinvent the transport layer (no Discord bots, no custom sockets, no web dashboards baked into this repo).
- **No runtime deps beyond tmux, systemd, coreutils, and optionally bwrap.** Anything else is out.
- **Stay current with Claude Code.** This repo is a thin wrapper. When Claude Code ships a new flag, feature, or install mechanism, check whether to adopt it. When it deprecates something we use, migrate. Diverging from Claude Code's conventions is how this project rots.

## Layout

- `bin/agent-*` — canonical harness-neutral helpers, one verb each (`agent-spawn`, `agent-spawn-sandbox`, `agent-talk`, `agent-peek`, `agent-list`, `agent-kill`). `agent-spawn` and `agent-spawn-sandbox` source `harnesses.d/<harness>.conf` to pick up the per-harness binary and flags; the read-only verbs (talk/peek/list/kill) just operate on tmux windows and don't need the map. Symlinked into `~/.local/bin/` by `setup.sh`.
- `bin/claude-*` — deprecated thin forwarders that print a warning and exec the matching `agent-*`. Kept for backwards compatibility; will be removed in a future release. `bin/claude-random-name` and `bin/claude-tmux-launch` are internal utilities (no agent-* equivalent yet) and stay.
- `claude-tmux.service` — systemd user unit; invokes `bin/claude-tmux-launch`, which now produces the `[<host>][claude] main` window.
- `config.env` — reference file documenting `REMOTE_CONTROL` and `SKIP_PERMISSIONS`. The actual runtime config is written to `~/.config/remote-claude/config.env` interactively on first install.
- `harnesses.d/<name>.conf` — one file per registered harness, mapping name → `{ BINARY, RC_FLAG, RC_TAKES_NAME, YOLO_FLAG, SANDBOX_OK, STATUS }`. Sourced (just the requested one) by `agent-spawn` and `agent-spawn-sandbox`. `STATUS=stable` means an adapter is wired and tested; `STATUS=stub` means registered for dispatch but the paste/idle behavior isn't verified, so spawn refuses. Phase 1 ships only `claude` as stable; codex/gemini/opencode are stubs. The directory IS the registry — there's no master list to keep in sync.
- `skills/spawn-agent/`, `skills/agent-talk/`, ... — canonical harness-neutral skill catalog. Skills are installed by `setup.sh` into `~/.claude/skills/` always; into `~/.agents/skills/` always (cross-harness fallback path); and into `~/.codex/skills/`, `~/.gemini/skills/`, `~/.config/opencode/skills/` conditionally on the relevant binary being on PATH at install time.
- `skills/spawn-claude/`, `skills/claude-talk/`, ... — deprecated skill stubs that point an LLM reader at the new neutral skill names. Kept so existing references still resolve.
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

- **Cross-harness orchestration as a coordination layer.** Harness-neutral *wrappers* are in scope (the `agent-*` scripts plus the harness map). A coordination layer — task queues, agent-to-agent messaging, shared state, scheduler — is not. For that, point at Claude Code's official Agent Teams + subagents (single-host), `mcp-agent-bridge` / `claude-squad` (cross-harness, with caveats), or roll a thin coordinator outside this repo.
- Agent farms / parallel multi-Claude orchestration / CI auto-fixers — see `claude_code_agent_farm`, `ComposioHQ/agent-orchestrator`.
- Git-worktree-per-agent isolation — orthogonal approach; our isolation primitive is bwrap (`agent-spawn-sandbox`).
- Notification bridges (ntfy / Discord / Telegram) — see `tap-to-tmux`, or Claude Code Channels. If added here, it belongs in a separate opt-in script, not baked into the core.
- Web dashboards, TUI frontends, multi-user support.
- **Per-harness paste/idle adapters for stub harnesses (Phase 2).** Each non-Claude harness has its own TUI quirks (paste-vs-Enter timing, idle pattern). Wiring those is real work and should be done when the user actually adopts that harness, not pre-emptively. Until then, `agent-spawn` correctly refuses stub harnesses with a clear error.

## Compare-yourself audit

The point of this audit is catching Claude Code drift, not re-litigating repo design. A live Claude working here can be asked:

> Compare this repo against current Claude Code. Flag anything we should adopt, anything we use that's been deprecated, and anything an official Claude Code feature would handle better than our wrappers.

The audit is only as good as the Claude running it. It should pull current state from `claude --help`, `claude --version`, the `claude-code-guide` subagent, or `WebFetch` of `code.claude.com` / the official changelog before flagging anything — knowledge-cutoff recall alone will miss recent changes. Output should cite specific deltas (new flags, renamed commands, install-path changes, newly-stabilized features) with pointers to where in the repo they'd land, not broad rewrites.

Keep this file short enough that audits against it remain useful; if it grows into architecture docs that duplicate the code, it starts rotting against the code and should be trimmed back.
