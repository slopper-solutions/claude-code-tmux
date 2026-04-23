# Sourced from ~/.profile / ~/.bash_profile / ~/.zprofile at login.
# On interactive SSH logins, attach to the persistent `main` tmux session so
# the user lands directly in Claude. Guard rails:
#   - Only fire under SSH (leaves local console logins alone).
#   - Only if we're not already inside a tmux session (no nesting).
#   - Only if stdin is a tty (skip scp, rsync, non-interactive runs).
#   - Only if `main` is actually running (if the service failed, drop to shell
#     so the user can investigate instead of hanging on a missing session).
#   - Opt out for a single login by setting NOAUTOATTACH=1 before ssh'ing,
#     e.g. `ssh -o SendEnv=NOAUTOATTACH host` after `export NOAUTOATTACH=1`,
#     or simpler: `ssh host` then detach with Ctrl-b d.
# No `exec`: detaching (prefix + d) returns you to a normal shell; `exit`
# logs out. To re-attach after detach: `tmux attach -t main`.
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ -z "${NOAUTOATTACH:-}" ] && [ -t 0 ] && command -v tmux >/dev/null 2>&1; then
	if tmux has-session -t main 2>/dev/null; then
		tmux attach -t main
	fi
fi
