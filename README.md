# Claude + Helix Core connector kit

Lets Claude Code work with Perforce Helix Core (read, edit, shelve, submit on request) with **Google SSO** through Helix Authentication. Version 0.1.0.

## Before you start
Your Helix admin must give you:
- a Perforce user whose **Email** is your Google account address (exact match)
- group membership for your project paths
- the server settings in `connector.config.json` (`p4port`, `serverFingerprint`, `depotRoot`, `auth.serviceUrl`)

You also need the `p4` command line client and Claude Code on Windows.

## Quick start

Your Helix admin adds your user first (see above), then:

```powershell
# 1. Connect this PC and a workspace folder (opens Google sign-in)
.\scripts\onboard.ps1 -User jsmith -Root D:\work\mds -GoogleEmail john.smith@mitrai.com

# 2. Check everything
.\scripts\check.ps1 -Root D:\work\mds
```
Google SSO through the Helix Authentication Service is **required**. `onboard.ps1` asks for the Google account email you will sign in with (or takes it from `-GoogleEmail`), confirms the Authentication Service in `connector.config.json` (`auth.serviceUrl`) is reachable, and after login checks that the email matches your Perforce user. If the service is down, onboarding stops before anything is written. Details: [docs/03](docs/03-google-sso-helix-auth.md).
Then open the workspace folder in Claude Code, approve `perforce-p4-mcp`, and run `/helix-status`.

### Already have a Perforce user and workspace?
**Easiest (no script, no clone):** install the plugin, open your workspace folder in Claude Code, and type:
```
/helix-connect
```
It detects your Perforce user, server and workspace, checks your login, refuses admin accounts, and writes only the missing `.p4config`, `.p4ignore`, `CLAUDE.md` and `.claude/settings.json`. It asks you only for what it cannot detect, never logs in for you (you run `! p4 login`), never trusts a certificate for you, and offers to download the P4 MCP server only if you say yes. Admins can pre-set the server address in `plugins/helix-connector/connect/connect.config.json` before sharing the plugin.

**Order:** install the plugin, open your workspace folder in Claude Code, `! p4 login` if needed, `/helix-connect`, restart Claude Code once and approve `perforce-p4-mcp`, then `/helix-status`, `/helix-init`, `/helix-learn`. Full order with diagrams: [docs/existing-workspace](docs/existing-workspace/README.md).

**Alternative (script):** connect from the kit folder:
Connect Claude to them without creating or syncing anything:
```powershell
.\scripts\onboard.ps1 -ExistingWorkspace -User jsmith -Workspace jsmith-myproj -P4Port ssl:helix.company.com:1666
```
This checks the server and your login (runs `p4 login` only if your ticket expired), confirms the workspace exists, and takes the folder from the workspace's Root unless you pass `-Root`. It writes `.p4config`, `.p4ignore`, `.mcp.json` and `CLAUDE.md` only if they are missing, and never overwrites existing ones. It skips the Google email prompt, the Authentication Service check, certificate pinning, workspace creation and sync. Your `p4 trust` must already be in place. The generated `CLAUDE.md` is generic: add your own stack and build commands, and follow your project's branching rules.

### Install the Claude Code plugin (skills, agents, command)
From a private repository that contains this folder as its root:
```
/plugin marketplace add <path-or-git-url-of-this-folder>
/plugin install helix-connector@mds-helix
```
For local testing, point `marketplace add` at this `connector` folder.
The plugin's MCP config reads the server path from `P4MCP_BIN` (set by `onboard.ps1`).

## Contents
| Path | What |
|---|---|
| `connector.config.json` | Server address, pinned fingerprint, depot layout, Authentication Service URL (`auth`), MCP download. Change this to point the kit at your live server |
| `scripts/onboard.ps1` | Developer onboarding |
| `scripts/check.ps1` | Developer health check (changes nothing) |
| `templates/` | `.p4config`, `.p4ignore`, `.mcp.json`, `CLAUDE.md` templates |
| `plugins/helix-connector/` | Plugin: `.mcp.json`, 7 skills, 7 agents (`p4-reader`, `p4-reviewer`, `p4-changelog`, `p4-guard`, `p4-submitter`, `p4-discoverer`), `/helix-status`, `/helix-connect`, `/helix-init`, and the `p4-guard` hook that blocks rule and permission changes |
| `.claude-plugin/marketplace.json` | Marketplace definition |
| `plugins/helix-connector/` codebase learning | `p4-codebase-learn` skill, `p4-codebase-analyst` agent and `/helix-learn`: read the existing code (read-only) and save `CODEBASE_NOTES.md` with the domain, conventions, best practices and reusable methods |
| `docs/` | Numbered guides |

## Documentation
1. [Overview and architecture](docs/01-overview-and-architecture.md)
2. [Google SSO with Helix Authentication](docs/03-google-sso-helix-auth.md)
3. [The MCP server, tool by tool](docs/04-mcp-server-tools.md)
4. [Using Claude Code day to day](docs/05-claude-code-workflow.md)
5. [Troubleshooting](docs/07-troubleshooting.md)

**Already have a Perforce user and workspace?** Start at [docs/existing-workspace/](docs/existing-workspace/README.md):
- [Complete guide](docs/existing-workspace/03-complete-guide.md)
- [System boundary and integration diagrams](docs/existing-workspace/01-system-boundary-and-integration.md)
- [Skills, agents, commands and hook: what, why, how, order](docs/existing-workspace/02-skills-and-agents-guide.md)

## Rules baked in
- Perforce only, never git. Prefer MCP tools.
- Developers write `dev/` and `features/`, read `main`.
- Shelve by default; submit only when asked in that turn.
- No passwords or tickets in files, chat, or the depot.
- Claude can read server rules and permissions but not edit or delete them (admin/super accounts are refused at onboarding; a `p4-guard` hook blocks the commands).
- The server certificate is pinned by fingerprint during onboarding.

## Tested
`onboard.ps1` (including refusal of a wrong fingerprint), `check.ps1`. Not yet tested end to end: Claude Code calling the MCP tools (needs a session restart), and `/plugin install` from a marketplace.
