---
name: p4-helix
description: Use for any Perforce Helix Core work in a workspace with a .p4config - reading files, history, blame, checking out (edit), adding, moving, syncing, reverting, or resolving. Use before editing any file that is already in the depot.
---

# Working in Helix Core with Claude Code

Helix Core is not Git. Depot files are **read-only on disk until opened**. Follow this order.

## Rules
1. Prefer the `perforce-p4-mcp` tools. Use the `p4` CLI only if the MCP server is not connected.
2. Never run git commands. Never open a pull request.
3. Never ask for, print, or store a password or ticket. If a call says the login is invalid or expired, stop and tell the user to run `p4 login` (it opens Google SSO in the browser).
4. Submit only when the user explicitly asks for it in that message. Shelving is the default way to hand work over.

## Which tool for what
| Goal | Tool and action |
|---|---|
| Who am I, is the server reachable | `query_server` `current_user` / `server_info` |
| Read a file at a revision | `query_files` `content` (use `ranges` for big files) |
| History, blame, diff | `query_files` `history` / `annotations` / `diff` |
| Find files or text | `query_files` `search` (name) / `grep` (content) |
| Get latest files | `modify_files` `sync` |
| Open a file for change | `modify_files` `edit` **before** writing to it |
| New file / delete / rename | `modify_files` `add` / `delete` / `move` |
| Detect edits made outside Perforce | `modify_files` `reconcile` |
| Conflicts after sync/unshelve | `modify_files` `resolve` (start with `preview`) |
| Group files into a change | `modify_changelists` `create` / `update` / `move_files` |
| Share work without submitting | `modify_shelves` `shelve` |

## Editing workflow
0. If `CODEBASE_NOTES.md` exists, read it first. Reuse the methods in its "Reuse before you write" table and follow its conventions and glossary. If it does not exist and the area is unfamiliar, suggest `/helix-learn`.
1. `sync` the paths you will touch.
2. `edit` each file (or `add` new ones) into a **numbered** changelist with a clear description.
3. Make the change; run the build and tests locally (`mvn verify` for the Java project).
4. `reconcile` if you created or removed files by other means.
5. Shelve, then report the changelist number. Wait for the user to ask to submit.

## Safety
- Developers cannot write to `main`. If a write is denied there, do not look for a workaround; use a `features/` line (see the p4-feature-line skill).
- Do not `revert` or `delete` a changelist that holds work you did not create in this session without asking.
- Large results are capped; narrow the path or use `max_results` instead of asking for everything.
