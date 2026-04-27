#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(id -un)"

step() {
	printf '\n==> %s\n' "$1"
}

link() {
	src="$1"
	dst="$2"
	if [ -L "$dst" ]; then
		current="$(readlink "$dst")"
		if [ "$current" = "$src" ]; then
			echo "  already linked: $dst"
			return
		fi
		# Dangling symlink (target missing) — safe to replace. Handles the
		# case where a previous install pointed at an old repo layout and
		# the source has since moved (e.g. claude-* -> bin/claude-*).
		if ! [ -e "$dst" ]; then
			echo "  replacing stale symlink: $dst (was -> $current)"
			rm "$dst"
			ln -s "$src" "$dst"
			echo "  linked: $dst -> $src"
			return
		fi
		echo "  ERROR: $dst -> $current (refusing to clobber live target)" >&2
		exit 1
	fi
	if [ -e "$dst" ]; then
		echo "  ERROR: $dst exists and is not a symlink (refusing to clobber)" >&2
		exit 1
	fi
	ln -s "$src" "$dst"
	echo "  linked: $dst -> $src"
}

step "Checking tmux"
if ! command -v tmux >/dev/null 2>&1; then
	echo "  ERROR: tmux is not installed." >&2
	echo "  Debian/Ubuntu: sudo apt-get install tmux" >&2
	echo "  Arch:          sudo pacman -S tmux" >&2
	exit 1
fi
echo "  ok: $(tmux -V)"

step "Checking claude CLI"
# If claude is already on PATH (e.g. previously npm-installed globally),
# symlink it to the expected location so the rest of the setup finds it.
if ! [ -x "$HOME/.local/bin/claude" ] && command -v claude >/dev/null 2>&1; then
	mkdir -p "$HOME/.local/bin"
	ln -sf "$(command -v claude)" "$HOME/.local/bin/claude"
	echo "  linked existing claude: $(command -v claude) -> $HOME/.local/bin/claude"
fi

if ! [ -x "$HOME/.local/bin/claude" ]; then
	echo "  claude CLI not found at $HOME/.local/bin/claude"
	installed=0

	# First attempt: native installer via curl. Can fail on Hetzner if the
	# CDN fronting downloads.claude.ai blocks the IP range.
	if command -v curl >/dev/null 2>&1; then
		echo "  trying native installer: curl -fsSL https://claude.ai/install.sh | bash"
		if curl -fsSL https://claude.ai/install.sh | bash; then
			if [ -x "$HOME/.local/bin/claude" ]; then
				installed=1
			fi
		else
			echo "  native installer failed — will try npm fallback"
		fi
	else
		echo "  curl not available; skipping native installer"
	fi

	# Fallback: npm. Installs into $HOME/.local (via --prefix) so no sudo
	# needed and the binary lands where the rest of the script expects it.
	if [ "$installed" -eq 0 ]; then
		if command -v npm >/dev/null 2>&1; then
			echo "  trying npm: npm install -g --prefix $HOME/.local @anthropic-ai/claude-code"
			npm install -g --prefix "$HOME/.local" @anthropic-ai/claude-code
			if [ -x "$HOME/.local/bin/claude" ]; then
				installed=1
			fi
		else
			echo "  npm not installed either."
			echo "  Install one of:"
			echo "    - node/npm  (Debian/Ubuntu: sudo apt-get install nodejs npm; Arch: sudo pacman -S nodejs npm)"
			echo "    - OR fix the network path to downloads.claude.ai (Hetzner IPs are sometimes blocked)"
			exit 1
		fi
	fi

	if [ "$installed" -ne 1 ] || ! [ -x "$HOME/.local/bin/claude" ]; then
		echo "  ERROR: install attempted but $HOME/.local/bin/claude is still missing" >&2
		exit 1
	fi
fi
echo "  ok: $("$HOME/.local/bin/claude" --version 2>/dev/null || echo 'version unknown')"

step "Checking claude.ai login (required for --rc)"
check_login() {
	"$HOME/.local/bin/claude" auth status --json 2>/dev/null | grep -qE '"loggedIn"[[:space:]]*:[[:space:]]*true'
}
check_method_claude_ai() {
	"$HOME/.local/bin/claude" auth status --json 2>/dev/null | grep -qE '"authMethod"[[:space:]]*:[[:space:]]*"claude\.ai"'
}

if ! check_login; then
	echo "  not logged in."
	echo "  This script will launch 'claude' so you can run /login interactively."
	echo "  In the TUI: type /login, choose 'Claude.ai' (not API key), complete the OAuth code flow,"
	echo "  then type /exit to come back here."
	printf "  Press Enter to launch claude..."
	read _unused
	"$HOME/.local/bin/claude" || true
	if ! check_login; then
		echo "  ERROR: still not logged in. Re-run this script once /login is complete." >&2
		exit 1
	fi
fi
if ! check_method_claude_ai; then
	echo "  ERROR: logged in, but not via claude.ai OAuth (--rc will not work)." >&2
	echo "  Run 'claude auth logout', then 'claude' + '/login' choosing claude.ai." >&2
	exit 1
fi
echo "  ok: logged in via claude.ai"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
	echo "  WARN: ANTHROPIC_API_KEY is set in this shell; it can shadow claude.ai auth." >&2
	echo "        If Remote Control errors out, unset it from your login env." >&2
fi

step "Checking bubblewrap (optional — needed for agent-spawn-sandbox)"
if command -v bwrap >/dev/null 2>&1; then
	echo "  ok: $(bwrap --version 2>/dev/null | head -1)"
else
	echo "  bwrap not found. Folder-restricted spawns (agent-spawn-sandbox) will not work until installed."
	echo "  Debian/Ubuntu: sudo apt-get install bubblewrap"
	echo "  Arch:          sudo pacman -S bubblewrap"
fi

step "Migrating from a previous install (no-op on fresh)"
# The claude-tmux -> agent-tmux rename (service unit, config dir, helper
# script names) means upgrades have leftover state. Handle it here so the
# rest of the script can assume a clean slate. Fresh installs hit no
# branches and breeze through.
OLD_UNIT="$HOME/.config/systemd/user/claude-tmux.service"
OLD_CONFIG_DIR="$HOME/.config/remote-claude"
if [ -f "$OLD_UNIT" ]; then
	echo "  stopping and disabling old claude-tmux.service (so agent-tmux.service can take over)"
	systemctl --user disable --now claude-tmux.service >/dev/null 2>&1 || true
	rm -f "$OLD_UNIT"
	systemctl --user daemon-reload
fi
if [ -d "$OLD_CONFIG_DIR" ] && [ ! -d "$HOME/.config/agents" ]; then
	echo "  copying config from $OLD_CONFIG_DIR to ~/.config/agents (originals left in place)"
	mkdir -p "$HOME/.config/agents"
	cp -r "$OLD_CONFIG_DIR/." "$HOME/.config/agents/"
	echo "  remove old dir manually when ready: rm -rf $OLD_CONFIG_DIR"
fi
for stale in "$HOME/.local/bin/claude-tmux-launch" "$HOME/.local/bin/claude-random-name"; do
	if [ -L "$stale" ] && ! [ -e "$stale" ]; then
		echo "  removing dangling symlink: $stale"
		rm -f "$stale"
	fi
done

step "Installing helper scripts into ~/.local/bin"
mkdir -p "$HOME/.local/bin"
# agent-* are the canonical harness-neutral entry points. claude-* are kept as
# thin deprecated forwarders for backwards compatibility — they still install,
# print a deprecation warning, and exec the agent-* equivalent.
for s in \
	agent-spawn agent-spawn-sandbox agent-talk agent-peek agent-list agent-kill \
	claude-spawn claude-spawn-sandbox claude-talk claude-peek claude-list claude-kill \
	agent-random-name agent-tmux-launch \
; do
	link "$DIR/bin/$s" "$HOME/.local/bin/$s"
done

step "Installing skills into ~/.claude/skills (canonical location)"
# Both new agent-* skills and the deprecated claude-* skills install here.
# Other harnesses' skill dirs are handled below (conditional on detection).
mkdir -p "$HOME/.claude/skills"
SKILLS="\
	spawn-agent spawn-agent-sandbox agent-talk agent-peek agent-list agent-kill \
	spawn-claude spawn-claude-sandbox claude-talk peek-claude list-claudes kill-claude \
"
for sk in $SKILLS; do
	link "$DIR/skills/$sk" "$HOME/.claude/skills/$sk"
done

step "Installing skills into other harness dirs (conditional on harness present)"
# Each harness has its own user-level skills directory. Detection: binary on
# PATH. If detected, symlink the whole catalog there. ~/.agents/skills/ is the
# emerging cross-harness fallback (OpenCode reads it; others may converge) —
# install unconditionally so future-installed harnesses pick it up.
install_skills_to() {
	dest_dir="$1"
	mkdir -p "$dest_dir"
	for sk in $SKILLS; do
		link "$DIR/skills/$sk" "$dest_dir/$sk"
	done
	echo "  installed skills → $dest_dir"
}
# Cross-harness fallback path — always install.
install_skills_to "$HOME/.agents/skills"
# Per-harness paths — only if the binary is on PATH.
if command -v codex >/dev/null 2>&1; then
	install_skills_to "$HOME/.codex/skills"
else
	echo "  codex not on PATH — skipping ~/.codex/skills"
fi
if command -v gemini >/dev/null 2>&1; then
	install_skills_to "$HOME/.gemini/skills"
else
	echo "  gemini not on PATH — skipping ~/.gemini/skills"
fi
if command -v opencode >/dev/null 2>&1; then
	install_skills_to "$HOME/.config/opencode/skills"
else
	echo "  opencode not on PATH — skipping ~/.config/opencode/skills"
fi

step "Installing systemd user unit"
mkdir -p "$HOME/.config/systemd/user"
link "$DIR/agent-tmux.service" "$HOME/.config/systemd/user/agent-tmux.service"

step "Installing tmux config niceties"
# Tmux settings Claude Code's docs recommend (passthrough, extended keys) live
# in $DIR/tmux.conf. We don't own ~/.tmux.conf — just inject a sentinel-guarded
# 'source-file -q' line so existing user configs keep winning.
TMUX_CONF_SRC="$DIR/tmux.conf"
TMUX_CONF_DST="$HOME/.tmux.conf"
TMUX_SENTINEL="# agent-tmux source (tmux niceties for the agent session)"
if [ -f "$TMUX_CONF_DST" ] && grep -qF "$TMUX_SENTINEL" "$TMUX_CONF_DST" 2>/dev/null; then
	echo "  already present: $TMUX_CONF_DST"
else
	# Leading newline separates from any existing config; harmless if file is
	# empty or missing (>> creates it).
	{
		echo ""
		echo "$TMUX_SENTINEL"
		echo "source-file -q $TMUX_CONF_SRC"
	} >> "$TMUX_CONF_DST"
	echo "  appended to: $TMUX_CONF_DST (sources $TMUX_CONF_SRC)"
	# If a tmux server is already running (common on re-runs), reload in place
	# so the new settings apply without waiting for the next server restart.
	if tmux info >/dev/null 2>&1; then
		tmux source-file "$TMUX_CONF_DST" 2>/dev/null || true
		echo "  reloaded live tmux server"
	fi
fi

step "Installing default config (first run only)"
# Config is a user-edited file, not a symlink — a symlink would either force
# edits in the repo or get clobbered on pull. First-run prompts default to
# 'no' so a user who hammers Enter ends up with the conservative config.
CONFIG_DIR="$HOME/.config/agents"
CONFIG_DST="$CONFIG_DIR/config.env"
mkdir -p "$CONFIG_DIR"
if [ -e "$CONFIG_DST" ]; then
	echo "  already present: $CONFIG_DST (leaving user edits alone)"
else
	ask_yn() {
		# $1 = prompt. Emits 1/0 on stdout; the prompt itself goes to stderr
		# so command substitution `$(ask_yn ...)` doesn't capture the prompt
		# text into the return value.
		printf '  %s [y/N] ' "$1" >&2
		ans=""
		read ans || ans=""
		case "$ans" in
			[Yy]|[Yy][Ee][Ss]) echo 1 ;;
			*) echo 0 ;;
		esac
	}
	echo "  configure defaults (edit $CONFIG_DST any time to change):"
	RC_VAL=$(ask_yn "Enable Remote Control so sessions show up in the Claude mobile app?")
	SP_VAL=$(ask_yn "Auto-approve all tool calls (--dangerously-skip-permissions)? Needed if you want the VPS Claude to work unattended.")
	cat > "$CONFIG_DST" <<EOF
# Agent-tmux config — generated by setup.sh.
# Strict KEY=VALUE (no shell expansion); loaded by agent-tmux-launch,
# agent-spawn, agent-spawn-sandbox, and systemd's EnvironmentFile.
# 1 = on, 0 = off. After editing: systemctl --user restart agent-tmux.
REMOTE_CONTROL=$RC_VAL
SKIP_PERMISSIONS=$SP_VAL
EOF
	echo "  installed: $CONFIG_DST (REMOTE_CONTROL=$RC_VAL, SKIP_PERMISSIONS=$SP_VAL)"
fi

step "Installing harness map (per-harness files, first run only)"
# harnesses.d/<name>.conf maps each harness to its binary, flags, and adapter
# status. agent-* dispatchers source the file matching the requested harness.
# Each file is installed once and left alone on re-run; new harness files
# added in later releases are picked up automatically.
HARNESSES_DST="$CONFIG_DIR/harnesses.d"
mkdir -p "$HARNESSES_DST"
for src in "$DIR/harnesses.d"/*.conf; do
	[ -f "$src" ] || continue
	name=${src##*/}
	dst="$HARNESSES_DST/$name"
	if [ -e "$dst" ]; then
		echo "  already present: $dst (leaving user edits alone)"
	else
		cp "$src" "$dst"
		echo "  installed: $dst"
	fi
done

step "Installing SSH auto-attach into login rc"
AUTOATTACH_SRC="$DIR/ssh-autoattach.sh"
SENTINEL="# agent-tmux ssh auto-attach"
add_sourcer() {
	f="$1"
	if [ -f "$f" ] && grep -qF "$SENTINEL" "$f" 2>/dev/null; then
		echo "  already present: $f"
		return
	fi
	{
		echo ""
		echo "$SENTINEL"
		echo "[ -f \"$AUTOATTACH_SRC\" ] && . \"$AUTOATTACH_SRC\""
	} >> "$f"
	echo "  appended to: $f"
}
add_sourcer "$HOME/.profile"
if [ -f "$HOME/.bash_profile" ]; then
	add_sourcer "$HOME/.bash_profile"
fi
case "${SHELL:-}" in
	*zsh*) add_sourcer "$HOME/.zprofile" ;;
esac

step "Enabling linger (so the tmux session survives logout)"
if loginctl show-user "$USER_NAME" 2>/dev/null | grep -q '^Linger=yes'; then
	echo "  already enabled for $USER_NAME"
else
	echo "  enabling via: sudo loginctl enable-linger $USER_NAME"
	sudo loginctl enable-linger "$USER_NAME"
fi

step "Reloading systemd user daemon"
systemctl --user daemon-reload

step "Enabling and starting agent-tmux.service"
systemctl --user enable agent-tmux.service
if ! systemctl --user restart agent-tmux.service; then
	echo "  ERROR: service failed to start" >&2
	echo "  Logs: journalctl --user -u agent-tmux.service -n 50" >&2
	exit 1
fi

step "Done"
echo "  future SSH logins auto-attach to the main agent session."
echo "    detach to shell:    Ctrl-b d (then 'tmux attach -t main' to return)"
echo "    bypass once:        ssh user@host bash --noprofile   (skips login rc)"
echo "    disable for a session: ssh; then Ctrl-b d once attached"
echo ""
echo "  attach manually:      tmux attach -t main"
echo "  list agents:          agent-list"
echo "  spawn a helper:       agent-spawn [--harness=<name>] <name> \"<optional prompt>\""
echo "  spawn (sandboxed):    agent-spawn-sandbox [--harness=<name>] <dir> <name> \"<optional prompt>\""
echo "  send to a window:     agent-talk <window> <text...>"
echo "  peek at a window:     agent-peek <window>"
echo "  kill a helper:        agent-kill <window>"
echo ""
echo "  (claude-* commands still work as deprecated forwarders to agent-* —"
echo "   they print a warning. Migrate when convenient.)"
echo ""
echo "  edit defaults:        \$EDITOR $CONFIG_DST"
echo "    REMOTE_CONTROL=1    --rc on main session and new helpers"
echo "    SKIP_PERMISSIONS=1  --dangerously-skip-permissions on both"
echo "    after editing: systemctl --user restart agent-tmux  (main only)"
echo ""
echo "  edit harness map:     \$EDITOR $HARNESSES_DST/<harness>.conf"
echo "    Phase 1 only 'claude' is wired (STATUS=stable). codex/gemini/opencode"
echo "    ship as STATUS=stub — agent-spawn refuses them until per-harness"
echo "    paste/idle adapters are written and STATUS is flipped to stable."
echo ""
echo "  (these all live in ~/.local/bin — ensure that's on your PATH)"
echo ""
echo "  NOTE: window naming is now '[<host>][<harness>] <slug>'. After this"
echo "  install, the next 'systemctl --user restart agent-tmux' brings up the"
echo "  main window as '[<host>][claude] main' instead of the legacy"
echo "  '[<host>] main'. agent-* readers handle both forms during migration."
