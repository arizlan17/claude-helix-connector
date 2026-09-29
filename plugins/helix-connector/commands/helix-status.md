---
description: Show who you are on Helix Core, your workspace, ticket state, and what is open
---
Check the Helix Core connection and report briefly:

1. Use `query_server` (`current_user`) to show the signed-in user and server.
2. Use `query_workspaces` (`status`) for the workspace in `.p4config`.
3. Use `query_changelists` (`list`, status pending) to show anything opened or shelved.

If any call reports the login is invalid or expired, stop and tell me to run `p4 login` (it opens Google SSO). Do not attempt to log in yourself and never ask for a password.
