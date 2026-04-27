claude-code-tmux
================

***Generated with Claude***

N+1 solution for setting up Claude Code on a remote server with tmux. Wow. Exciting.

Working with Claude Code in the app is 'fine', but you can only really control your
single instance of Claude Code via --rc. This helps alleviate that by giving you a
handful of skills and scripts that Claude Code (or another supported harness) can
run (by simply asking) to spawn a new agent session, in case you want to work within
different contexts without potentially murking the context you're working in. Equally,
this allows your setup to be persistent and easily restartable via systemctl - once
you have it set up, all you need to do is start the service unit, and you can connect
to the main window.

By default, this will automatically setup ALL SSH logins to immediately connect to
the current tmux session that has Claude Code. This effectively turns an entire box
into a slop system that you can prompt and vibe your tokens off. Amazing.

Harnesses
---------

The helpers are harness-neutral. The harness map at `~/.config/agents/harnesses.d/`
holds one file per registered harness — Claude Code, Codex CLI, Gemini CLI,
and OpenCode ship out of the box. Phase 1 wires Claude Code (`STATUS=stable`)
only; the others are `STATUS=stub` — registered for dispatch but `agent-spawn`
will refuse them until per-harness paste/idle adapters are written. Skills
install into each harness's user-level skills directory at setup time,
conditional on the relevant binary being on PATH.

Migration note
--------------

This release renamed `claude-tmux` → `agent-tmux` (systemd unit, config dir,
launcher script). `setup.sh` handles the upgrade automatically: it stops and
removes the old `claude-tmux.service`, copies `~/.config/remote-claude/` to
`~/.config/agents/`, and clears any dangling symlinks. The original config
dir is left in place for safety; remove it manually with `rm -rf
~/.config/remote-claude/` once you're satisfied the new install works.

Window naming changed from `[<host>] <slug>` to `[<host>][<harness>] <slug>`.
After upgrading, the next `systemctl --user restart agent-tmux` brings up the
main window as `[<host>][claude] main`. Existing `[<host>] <slug>` windows
from a long-running session keep working — `agent-list`, `agent-talk`,
`agent-peek`, `agent-kill` all accept both forms.

The `claude-*` scripts (`claude-spawn`, `claude-talk`, etc.) still work but are
deprecated forwarders that print a warning and call the matching `agent-*`.
Migrate when convenient.

Usage
-----

- Clone the repository into a persistant directory (recommended: /opt/)
- Run setup.sh
- Go through the setup process
- Relog into your SSH session, or attach to the resultant tmux session (as
  reported by the setup complete hints)

Congratulations. Have fun slopping persistently with Claude mobile app access.

Copyright
---------

***WHAT copyright???***
