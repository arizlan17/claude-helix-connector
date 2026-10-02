# Claude + Helix Core: existing workspace kit

Lets Claude Code work with a Perforce Helix Core workspace you **already have** (Google SSO user, existing workspace): read, edit, shelve, and submit on request. Developer-facing only: no server setup, no admin tools. Windows only for now. Version 0.1.0.

## What you need
- A Perforce user whose **Email** is your Google account address (exact match), and an existing workspace. Your Helix admin sets these up.
- A normal (non-admin) account. Connecting refuses `admin`/`super` accounts.
- The `p4` command line client and Claude Code.
- The server certificate already trusted (`p4 trust`, after confirming the fingerprint with your admin).

## Connect (order)
1. Install the plugin:
   ```
   /plugin marketplace add <path-or-git-url-of-this-repo>
   /plugin install helix-connector@mds-helix
   ```
2. Open your **workspace folder** in Claude Code.
3. If you are not signed in, run `! p4 login` yourself (Google opens). Claude never logs in for you.
4. Type `/helix-connect`. It detects your Perforce user, server and workspace, checks trust and login, refuses admin accounts, and writes only the missing `.p4config`, `.p4ignore`, `CLAUDE.md` and `.claude/settings.json`. It asks only for what it cannot detect and offers to download the P4 MCP server only if you say yes.
5. Restart Claude Code once and approve `perforce-p4-mcp`.
6. Run `/helix-status`, then `/helix-init` (learn the server's rules for your user), then `/helix-learn` (learn the code).
7. Work: code, `p4-guard` check, review, shelve, and submit when you ask.

Full walkthrough with diagrams: [docs/existing-workspace](docs/existing-workspace/README.md).

### Script alternative
If you prefer a script to `/helix-connect`, clone this repo and run:
```powershell
.\scripts\onboard.ps1 -User jsmith -Workspace jsmith-myproj -P4Port ssl:helix.company.com:1666
.\scripts\check.ps1 -Root D:\work\myproj
```
It does the same checks and also writes `.mcp.json` and copies the guard hook into the workspace. It never creates a workspace, syncs, trusts a certificate, or overwrites a file.

## What is in the plugin
| Piece | What it gives you |
|---|---|
| `/helix-connect` (skill `p4-connect`) | Connect this folder to Claude |
| `/helix-status` | Who you are, workspace, ticket, pending changes |
| `/helix-init` (skill `p4-first-run`, agent `p4-discoverer`) | Reads the live server's rules for you and updates `CLAUDE.md`, `.claude/settings.json`, `.p4config`, `.p4ignore` |
| `/helix-learn` (skill `p4-codebase-learn`, agent `p4-codebase-analyst`) | Learns the code and saves `CODEBASE_NOTES.md` |
| Skills `p4-helix`, `p4-feature-line`, `p4-shelve-review`, `p4-troubleshoot` | The Perforce workflow, shelving, and fixes |
| Agents `p4-reader`, `p4-reviewer`, `p4-changelog`, `p4-guard`, `p4-submitter` | Read-only questions, review, standup summary, pre-flight check, and the only agent that writes |
| `p4-guard` hook | Blocks any command that would edit or delete server rules and permissions |

## Contents
| Path | What |
|---|---|
| `plugins/helix-connector/` | The plugin (skills, agents, commands, hook, `connect/connect.ps1`) |
| `.claude-plugin/marketplace.json` | Marketplace definition |
| `connector.config.json` | Defaults for the `onboard.ps1` script (server address, MCP download) |
| `plugins/helix-connector/connect/connect.config.json` | Defaults for `/helix-connect` (an admin may pre-set the server address before sharing) |
| `scripts/` | `onboard.ps1`, `check.ps1`, `lib.ps1` |
| `templates/` | `.p4config`, `.p4ignore`, `.mcp.json`, `CLAUDE.md`, `.claude/settings.json` templates |
| `docs/` | Guides |

## Documentation
- [docs/existing-workspace/](docs/existing-workspace/README.md): start here (complete guide, diagrams, skills and agents)
- [Overview and architecture](docs/01-overview-and-architecture.md)
- [The MCP server, tool by tool](docs/04-mcp-server-tools.md)
- [Using Claude Code day to day](docs/05-claude-code-workflow.md)
- [Troubleshooting](docs/07-troubleshooting.md)

## Rules baked in
- Perforce only, never git. Prefer MCP tools.
- Shelve by default; submit only when asked in that turn.
- No passwords or tickets in files, chat, or the depot.
- Claude can read server rules and permissions but not edit or delete them (admin/super accounts are refused; the `p4-guard` hook blocks the commands).
- Follow your project's own branching rules (`/helix-init` records what your account can write).

## Tested
`/helix-connect`'s script, `onboard.ps1` and the guard hook, against a fake `p4` stand-in. Not yet tested: a real Helix server, Claude Code loading the plugin, command and hook, and `/plugin install` from a marketplace.
