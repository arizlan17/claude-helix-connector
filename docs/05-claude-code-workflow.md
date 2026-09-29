# 05 - Using Claude Code with Helix Core, day to day

## One-time setup (developer)
1. Ask an admin to add you (they run `add-developer.ps1` with your Google email).
2. Run `scripts\onboard.ps1 -User <your.user> -Root <your workspace folder>`. It pins the server fingerprint, writes `.p4config`, `.mcp.json`, `CLAUDE.md`, opens Google sign-in, creates your workspace and syncs.
3. Install the Claude Code plugin from the kit (see README), then open the workspace folder in Claude Code.
4. Approve the `perforce-p4-mcp` server when asked.
5. Run `/helix-status`. You should see your user, workspace, and pending changes.

## Every morning
Tickets last 12 hours. If Claude says the login is invalid or expired:
```
p4 login
```
Sign in with the Google account registered for your Perforce user.

## What the plugin gives you
| Item | Purpose |
|---|---|
| Skill `p4-helix` | Rules and a tool-by-tool cheat sheet: sync -> edit -> change -> shelve |
| Skill `p4-feature-line` | The `main` / `dev` / `features/<name>` layout |
| Skill `p4-shelve-review` | How to hand work over without submitting |
| Skill `p4-troubleshoot` | What each error means and what to tell you |
| Agent `p4-reader` | Read-only questions; cannot modify anything |
| Agent `p4-submitter` | Write operations; works on feature lines, shelves by default |
| `/helix-status` | Connection and workspace summary |

## Typical tasks and what to say
**Understand code and history**
- "Show the history of `CustomerProcessor.java` and summarise the last change."
- "Who last changed `application.yml` and why?"

**Make a change safely (recommended flow)**
1. "Start a feature line `features/<my-name>-<topic>` from dev." (Claude uses the `p4-feature-line` skill.)
2. "Add email validation to `CustomerProcessor` on that line, with a test."
3. Claude syncs, `edit`s files into a numbered changelist, changes the code, runs `mvn verify`.
4. "Shelve it." Claude reports the changelist number.
5. A reviewer inspects the shelf (`query_shelves`). Promotion to `dev`/`main` is done by a reviewer or the release manager.

**Only when you say so:** "Submit changelist 12." Claude states the files and description first.

## Guardrails you will notice
- Claude will not write `main`; the server denies it and Claude explains instead of working around it.
- Claude will not ask for or print your password or ticket.
- Claude uses `p4`, not git, and does not open pull requests.
- If an admin has made your group read-only, Claude can read and explain but not change anything.

## Good habits
- Give changelists a real description (what and why).
- One topic per feature line.
- Ask Claude to run `mvn verify` before shelving.
- Use `p4-reader` for questions when you want a hard guarantee that nothing changes.

Next: [06 - Admin operations](06-admin-operations.md)
