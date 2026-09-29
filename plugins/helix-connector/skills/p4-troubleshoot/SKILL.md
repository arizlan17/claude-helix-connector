---
name: p4-troubleshoot
description: Use when a Helix Core or MCP call fails - login invalid, connection refused, unknown host, trust/fingerprint warnings, or "no permission" errors.
---

# Troubleshooting

| Symptom | Cause | What to tell the user |
|---|---|---|
| `password (P4PASSWD) invalid or unset` or ticket expired | SSO ticket lifetime (12h) ended | Run `p4 login` in a terminal and finish Google sign-in |
| `Login invalid ... validation failed` after Google succeeded | Google account email does not match the Perforce user's Email | Sign in with the Google account registered for that Perforce user, or ask an admin to fix the user's email |
| `TCP connect to perforce:1666 failed` | `p4` ran where `.p4config` is not found, so it used the default host | Run inside the workspace folder, or run `p4 set P4PORT=<server>` once |
| `WARNING P4PORT IDENTIFICATION HAS CHANGED` | Server certificate changed | Do not trust blindly. Ask the admin for the expected fingerprint, then `p4 trust` |
| `no permission for operation` | Protections, for example writing `main` | Expected. Use a feature line, or ask a release manager |
| MCP tools missing | Server not approved or not started | Restart Claude Code in the workspace and approve `perforce-p4-mcp` |
| MCP tool "blocked" | Admin disabled it via `p4 property` (`mcp.*`) | Ask the Helix admin; do not work around it |

Never ask the user to paste a ticket or password. Check state with `query_server` (`current_user`).
