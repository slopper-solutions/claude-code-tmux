claude-code-tmux
================

***Generated with Claude***

N+1 solution for setting up Claude Code on a remote server with tmux. Wow. Exciting.

Working with Claude Code in the app is 'fine', but you can only really control your
single instance of Claude Code via --rc. This helps alleviate that by giving you a
handful of skills and scripts that Claude Code can run (by simply asking) to spawn
a new Claude Code session, in case you want to work within different contexts without
potentially murking the context you're working in. Equally, this allows your setup
to be persistent and easily restartable via systemctl - once you have it set up,
all you need to do is start the service unit, and you can connect to the main window.

By default, this will automatically setup ALL SSH logins to immediately connect to
the current tmux session that has Claude Code. This effectively turns an entire box
into a slop system that you can prompt and vibe your tokens off. Amazing.

Usage
-----

- Clone the repository into a persistant directory (recommended: /opt/)
- Run setup.sh
- Go through the setup process
- Relog into your SSH session, or attach to the resultant tmux session (as
  reported by the setup complete hints)

Congratulations. Have fun slopping persistently with Claude mobile app access.

Bug reports
-----------

Create an issue.

Contributing
------------

Generally, I will not accept pull requests made directly into this repository.
All code *is* AI generated, and this will be a persistant state for this
repository.

Copyright
---------

***WHAT copyright???***
