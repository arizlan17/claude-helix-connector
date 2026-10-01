---
name: p4-first-run
description: Use on the first run in a Helix Core workspace (no helix-first-run block in CLAUDE.md yet), or when asked to refresh rules and permissions. Reads the live server's access rules, groups and workspace, then proposes updates to CLAUDE.md, .claude/settings.json (allow and deny rules), .p4config and .p4ignore. Read-only on the server; writes local files only after the user approves.
---

# First run: learn the live server, then set up this workspace

Goal: make Claude's local rules match what the live Perforce server actually allows this user, instead of assuming a fixed layout. Everything here is **read-only on the server**. Local files are changed only after the user approves the plan.

## Hard rules
- Never run `p4 login`, never ask for or print a password or ticket. If a call says the login is invalid or expired, stop and tell the user to run `p4 login`.
- Never change protections, groups, properties or any server data. Only read.
- Never touch files outside the workspace folder. Never put secrets in any file.
- Merge, do not overwrite. Existing content the user wrote must survive.
- If a discovery command is denied (some need admin rights, for example `p4 property -l`), note "not visible to this user" and continue.

## Step 1: Is this a first run?
Read `CLAUDE.md`. If it already has a `<!-- helix-first-run:start -->` block, say so and stop, unless the user asked to refresh. On refresh, replace only that block.

## Step 2: Discover (read-only)
Delegate this step to the `p4-discoverer` agent (read-only). If it cannot run a command, run that command yourself. Prefer the `perforce-p4-mcp` tools; use the `p4` CLI only for items the tools cannot show. Collect:

| Fact | How |
|---|---|
| User, server, case sensitivity, unicode | `query_server` (`current_user`, `server_info`) or `p4 info` |
| Workspace name, Root, view (depot to local mapping) | `query_workspaces` or `p4 client -o` |
| Groups you belong to, ticket timeout | `p4 groups -u <user>` then `p4 group -o <group>` (field `Timeout`) |
| Project layout under the view's depot roots | `p4 dirs <root>/*`. Streams depot? `p4 streams -m 5` (empty or error means classic paths) |
| Effective access per top-level folder | For each folder: `p4 protects -m -u <user> <folder>/x`. Result is one of `list`, `read`, `open`, `write`, `review`, `owner`, `admin`, `super`. Treat `write` and above as writable; anything lower as read-only |
| Lines you cannot see at all | `p4 protects -m` shows `none`/no result: treat as not accessible |
| MCP policy | `p4 property -l -A` and look for `mcp.*` (`mcp.enabled`, `mcp.toolsets.write`, `mcp.toolsets.allowed`). May be hidden; then say unknown |
| Existing local files | `.p4config`, `.p4ignore`, `CLAUDE.md`, `.claude/settings.json` if present |

Record the results in a short table for the user.

## Step 3: Propose changes (do not write yet)
Show exactly what would be added or changed in each file, as a diff-style list, then ask for approval.

### CLAUDE.md
Add or replace one managed block:
```
<!-- helix-first-run:start -->
## Helix Core rules for this workspace (generated <date> from <server>)
- User <user>, workspace <client>, server <port>. Ticket lasts <timeout>.
- Writable here: <local folders>. Read-only here: <local folders>. Not accessible: <folders>.
- Layout: <classic paths or streams>. <branching guidance derived from what is writable>
- MCP: <full | read-only | unknown>. <if read-only: do not attempt edits, shelves or submits>
- Edit files only after `edit`/`add` in a numbered changelist. Shelve by default. Submit only when asked in that turn.
<!-- helix-first-run:end -->
```
Derive the branching guidance from the facts. Do not copy `main`/`dev`/`features` unless those folders actually exist.

### .claude/settings.json (this is Claude Code's allow/deny list; there is no separate .claudeignore)
Merge into `permissions` without removing existing entries:
- `deny`: `Read`/`Edit`/`Write` on secrets (`.env`, `.env.*`, `secrets/**`, `*.pem`, `*.key`); `Edit`/`Write` on local folders that are **read-only** for this user; `Bash(git *)` (Perforce only).
- `allow`: the read-only MCP tools (`query_*`) of `perforce-p4-mcp`, and `Edit` on local folders that are writable.
- Leave `modify_files`, `modify_changelists`, `modify_shelves` out of `allow` so Claude asks before opening, shelving or submitting. If MCP is read-only, also put the `modify_*` tools in `deny`.
- Use the exact tool names this session shows (they differ when the server is loaded from the plugin vs a project `.mcp.json`).

### .p4config
Add only missing keys: `P4PORT`, `P4USER`, `P4CLIENT`, `P4IGNORE=.p4ignore`, and `P4CHARSET` if the server is unicode. Never change an existing value; if one disagrees with what the server reports, list it as a warning instead. Never add `P4PASSWD` or tickets.

### .p4ignore
Append missing lines only: `.p4config`, `.p4ignore`, `.env`, `.env.*`, `secrets/`, `*.pem`, `*.key`, `.claude/settings.local.json`, plus build output folders you actually see in the workspace (for example `target/`, `node_modules/`, `bin/`, `obj/`).

## Step 4: Apply after approval
- Write only what the user approved. Use read-then-edit so nothing is overwritten.
- Print a summary: files created, lines added, warnings left for the user.
- Tell the user to restart Claude Code if `.claude/settings.json` changed, and to run `/helix-status`.

## Step 5: Report what you could not learn
List any fact that was hidden (for example MCP policy) and what that means in practice, so the user can ask their Helix admin.
