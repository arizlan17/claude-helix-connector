---
name: p4-connect
description: Use when the user wants to connect Claude to their existing Perforce workspace, says "connect", or the folder has no .p4config yet. Runs the plugin's connect.ps1, which detects user, server and workspace, checks login, and writes the missing config files. Asks the user only for what cannot be detected.
---

# Connect this folder to Claude

The developer installed the plugin and typed `/helix-connect`. Do the whole connection for them; they should not have to clone anything or run a script.

## Hard rules
- Never run `p4 login`, never ask for or print a password or ticket. If they are not signed in, tell them to run `! p4 login` themselves (the `!` runs it in this session and Google opens in the browser).
- Never trust a server certificate. If it is not trusted, tell them to confirm the fingerprint with their Helix admin and run `p4 trust` themselves.
- Never overwrite an existing file (the script already refuses to) and never change anything on the Perforce server.
- Do not download anything without the user's yes.

## Steps
1. **Check the folder.** The current folder should be the workspace folder (the workspace Root). If it is clearly not, tell the user to open Claude Code in the workspace folder and try again.
2. **Find the script.** It is `${CLAUDE_PLUGIN_ROOT}/connect/connect.ps1`. If that text was not expanded to a real path, find it with Glob: `**/helix-connector/connect/connect.ps1` under the user's `.claude/plugins` folder.
3. **Run it in the current folder** (PowerShell tool):
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<path to connect.ps1>"`
4. **Read the result and act on the exit code:**

| Exit | Meaning | What you do |
|---|---|---|
| 0 | Connected | Report what was written. Tell them to restart Claude Code if asked to (the Perforce tools load at start), then suggest `/helix-status`, `/helix-init`, `/helix-learn` |
| 2 | Needs info (`NEED:` lines) | Ask the user in plain words for the missing server address, user name or workspace name, then re-run with `-P4Port`, `-User` or `-Workspace` |
| 3 | Not signed in | Tell them to run `! p4 login`, then re-run |
| 4 | Certificate not trusted | Tell them to confirm the fingerprint with their Helix admin and run `p4 trust` themselves, then re-run |
| 5 | Admin or super account | Explain that Claude acts as this user and could change server rules; ask them to use a normal account. Only if they explicitly accept the risk, re-run with `-AllowAdminAccount` |
| 6 | P4 MCP server missing | Ask: "Download the P4 MCP server from the address shown to your user folder?" If yes, re-run with `-InstallMcp` |
| 1 | Other error | Show the message and help fix it (see the `p4-troubleshoot` skill) |

5. **Finish.** Summarise in a few lines: user, server, workspace, files created, files left unchanged, and the next steps. Remind them that server rules stay read-only for Claude.
