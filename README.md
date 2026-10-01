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
| `plugins/helix-connector/` | Plugin: `.mcp.json`, 4 skills, 5 agents (`p4-reader`, `p4-reviewer`, `p4-changelog`, `p4-guard`, `p4-submitter`), `/helix-status` |
| `.claude-plugin/marketplace.json` | Marketplace definition |
| `docs/` | Numbered guides |

## Documentation
1. [Overview and architecture](docs/01-overview-and-architecture.md)
2. [Google SSO with Helix Authentication](docs/03-google-sso-helix-auth.md)
3. [The MCP server, tool by tool](docs/04-mcp-server-tools.md)
4. [Using Claude Code day to day](docs/05-claude-code-workflow.md)
5. [Troubleshooting](docs/07-troubleshooting.md)

## Rules baked in
- Perforce only, never git. Prefer MCP tools.
- Developers write `dev/` and `features/`, read `main`.
- Shelve by default; submit only when asked in that turn.
- No passwords or tickets in files, chat, or the depot.
- The server certificate is pinned by fingerprint during onboarding.

## Tested
`onboard.ps1` (including refusal of a wrong fingerprint), `check.ps1`. Not yet tested end to end: Claude Code calling the MCP tools (needs a session restart), and `/plugin install` from a marketplace.
