# Existing workspace docs

For a developer who already has a Perforce user and workspace (Google SSO) and wants to use Claude Code with it.

## Order of connecting
1. Install the plugin: `/plugin marketplace add ...` then `/plugin install helix-connector@mds-helix`.
2. Open your workspace folder in Claude Code.
3. Sign in yourself if needed: `! p4 login` (Google opens).
4. Type `/helix-connect` (answer only what it asks).
5. Restart Claude Code once and approve `perforce-p4-mcp`.
6. `/helix-status`, then `/helix-init`, then `/helix-learn`.
7. Work: code, guard, review, shelve, submit when you ask.

No clone and no script is needed. A script path (`onboard.ps1 -ExistingWorkspace`) is still available.

| Read | What it is | When |
|---|---|---|
| [03 - Complete guide](03-complete-guide.md) | Prerequisites, setup steps, daily workflow, safety model, troubleshooting, files | **Start here** |
| [01 - System boundary and integration](01-system-boundary-and-integration.md) | Boundary, sign-in and workflow diagrams, the layers that keep server rules read-only | To understand how it fits together |
| [02 - Skills and agents guide](02-skills-and-agents-guide.md) | Every skill, agent, command and the guard hook: what, why, how, and the order to use them | While working |

The shared guides one level up describe the kit as a whole.
