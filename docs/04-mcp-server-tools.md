# 04 - The P4 MCP server, tool by tool

## What MCP is, and why we use it
**MCP (Model Context Protocol)** is the standard way for Claude Code to call external tools. The **P4 MCP server** is Perforce's official MCP server. Claude Code starts it as a local process; it talks to Helix Core using **your** `.p4config` and **your** ticket.

Why not just let Claude run `p4` commands in a shell?
| MCP tools | Raw shell `p4` |
|---|---|
| Structured, typed calls with clear parameters | Free-form text Claude must compose and parse |
| Admin can allow/deny per toolset and make it read-only on the server | No server-side way to limit what a shell can run |
| Ownership checks and confirmation prompts on risky actions (e.g. deleting a changelist) | None |
| Results are capped (`--max-results`) | Unbounded output |

The rule in this kit: **prefer MCP tools; use the `p4` CLI only if MCP is not connected.**

## How it is wired
```json
{
  "mcpServers": {
    "perforce-p4-mcp": {
      "command": "<path to p4-mcp-server.exe>",
      "args": ["--log-dir", "<log folder>"],
      "env": { "P4CONFIG": ".p4config" }
    }
  }
}
```
| Piece | Why |
|---|---|
| `command` | Absolute path to the server binary (`P4MCP_BIN`); the plugin reads it from the environment |
| `--log-dir` | Keeps MCP logs outside the workspace, so they are never versioned |
| `P4CONFIG=.p4config` | The server reads user/workspace/server from the workspace's `.p4config`, so no credentials appear in MCP config |
| Ticket | Read from the normal Perforce ticket file created by `p4 login`. No password is ever in the config. |
| `P4USER` must be a **standard** user | A `service` user cannot run `p4 describe`/`p4 changes` |

Useful options: `--readonly` (client-side read-only), `--toolsets a b c` (limit toolsets), `--max-results N`, `--max-scan-rows N`.

## Two kinds of tools
- **`query_*`**: read-only. Safe to allow widely.
- **`modify_*`**: change files, changelists, shelves, workspaces. Governed by policy (below).

## Read tools (enabled)
### `query_server`
- **Actions:** `server_info`, `current_user`.
- **Why:** First call in any session. Proves the connection works and shows who Claude is acting as. `/helix-status` uses it.
- **Example:** "Who am I on Helix Core?"

### `query_workspaces`
- **Actions:** `list`, `get`, `type`, `status`.
- **Why:** Confirms the workspace mapping (which depot paths are local) and whether it is in sync.
- **Example:** "Is my workspace up to date?"

### `query_changelists`
- **Actions:** `get`, `list` (filter by status pending/submitted, workspace).
- **Why:** Review what changed, see what is pending, and read descriptions.
- **Example:** "What did the last three submitted changes touch?"

### `query_files`
- **Actions:** `content`, `history`, `info`, `metadata`, `diff`, `annotations` (blame), `search` (by name), `grep` (by content).
- **Why:** Claude's main way to understand code that is not yet on disk, or to see past versions. `content` supports line `ranges` so large files do not flood the context.
- **Examples:** "Show `CustomerProcessor.java` at revision 1", "Who last changed this method?", "Find files that mention `JobBuilder`."

### `query_shelves`
- **Actions:** `list`, `diff`, `files`.
- **Why:** Code review without submitting: inspect a colleague's shelved work.
- **Example:** "Show the diff of shelved change 12."

### `query_jobs`
- **Actions:** `list_jobs`, `get_job`.
- **Why:** Link changes to defects/requirements where Perforce jobs are used.

## Write tools (enabled, governed)
### `modify_files`
- **Actions:** `add`, `edit`, `delete`, `move`, `revert`, `reconcile`, `resolve`, `sync`.
- **Why:** The core write path. In Helix Core a file is **read-only on disk until opened**; `edit` opens it (and creates the record the server needs). `sync` gets the latest. `reconcile` finds changes made outside Perforce. `resolve` (start with mode `preview`) merges conflicts.
- **Safety:** Protections still apply. A write to `main` is denied by the server, so Claude works on `features/`.

### `modify_changelists`
- **Actions:** `create`, `update`, `submit`, `delete`, `move_files`.
- **Why:** Group related files with a clear description. `submit` publishes to the depot.
- **Safety:** Ownership checks; delete asks for confirmation. Kit rule: **submit only when the developer explicitly asks in that turn.**

### `modify_shelves`
- **Actions:** `shelve`, `unshelve`, `update`, `delete`, `unshelve_to_changelist`.
- **Why:** The default hand-off. A shelf stores work on the server without touching `dev` or `main`, so a human can review first.

### `modify_workspaces`
- **Why:** Create or adjust workspaces. Usually left to `onboard.ps1`; Claude rarely needs it.

### `modify_jobs`
- **Why:** Attach jobs to changelists where jobs are used.

## Tools that exist but are disabled by our policy
| Toolset | Why off in the PoC |
|---|---|
| `streams` (`query_streams`, `modify_streams`) | This depot uses classic paths, not streams. Enable if you adopt streams. |
| `reviews` (`query_reviews`, `modify_reviews`) | Needs a Swarm/P4 Code Review server. Enable when connected. |
| `p4dam_*` | P4 DAM asset management; not part of this workflow. |

The server allowlist is set with:
```
p4 property -a -n mcp.toolsets.allowed -v server,changelists,files,shelves,workspaces,jobs
```

## Governance: controlling MCP from the server
All from an admin session, no change on developer PCs. The wrapper script is `scripts/set-mcp-policy.ps1`.

| Goal | Command |
|---|---|
| Show settings | `set-mcp-policy.ps1 -Show` |
| Make a group read-only | `set-mcp-policy.ps1 -Mode ReadOnly -Group mds-interns` (blocks every `modify_*` tool) |
| Turn MCP off for one person | `set-mcp-policy.ps1 -Mode Off -TargetUser jsmith` |
| Remove a group/user override | `set-mcp-policy.ps1 -Mode Reset -Group mds-interns` |
| Global kill switch | `p4 property -a -n mcp.enabled -v false` (undo with `p4 property -d -n mcp.enabled`) |

Precedence: highest sequence number wins; at equal sequence a **user** setting beats a **group** setting, which beats **global**. Only the literal value `false` blocks.

## Logs and troubleshooting
- MCP logs: the `--log-dir` folder.
- "Login invalid": ticket expired; run `p4 login`.
- Tools missing in Claude Code: restart Claude Code in the workspace and approve `perforce-p4-mcp`.
- A tool says it is blocked: an admin policy applies; do not work around it.

Next: [05 - Using Claude Code day to day](05-claude-code-workflow.md)
