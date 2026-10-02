# 01 - Overview and architecture

## What this is
A connector that lets **Claude Code** work with **Perforce Helix Core** the way a developer does: read code and history, check files out, edit, shelve for review, and submit when asked. Sign-in is **Google SSO** through Helix Authentication, so there are no shared or stored passwords.

## Why it is built this way
| Design choice | Reason |
|---|---|
| Claude acts **as the signed-in developer** (their ticket, their permissions) | Least privilege. Every change in the audit trail is attributed to a real person. No shared bot account. |
| Google SSO via Helix Authentication Service + Extension | Uses the company identity provider; access ends when the person's account does. |
| Official **P4 MCP server** | Vendor-supported way to expose Helix Core to MCP clients. We add policy and guardrails, we do not re-implement it. |
| Server-side MCP policy (`p4 property`) | Admins can switch MCP off or read-only per user or group without touching developer PCs. |
| Protections: read all, write only `dev/` and `features/` | Nothing reaches `main` without a human on the release side. |
| Plugin + skills + `CLAUDE.md` | Every developer gets the same safe behaviour: shelve by default, submit only on request. |

## Components
```
 Developer PC                                   Server side
+-------------------------------+      +-------------------------------------------+
| Claude Code                   |      | Helix Core (p4d)  ssl:1666                |
|   |  (MCP, stdio)             |      |   - protections, groups, audit log        |
|   v                           | TLS  |   - Helix Authentication Extension        |
| P4 MCP server  ---------------+----->|        |                                  |
|   uses .p4config + ticket     |      |        v  HTTPS (client cert)             |
|                               |      | Helix Authentication Service  :3000       |
| p4 CLI / P4V (p4 login) ------+----->|        |  OIDC                            |
+-------------------------------+      |        v                                  |
                                       | Google (accounts.google.com)              |
                                       +-------------------------------------------+
```

## The two flows
**Sign in (about once every 12 hours, by the developer)**
1. `p4 login` -> Helix Core asks the Authentication Extension.
2. The extension opens the browser at the Authentication Service, which redirects to Google.
3. The developer signs in with Google. Google returns the account **email**.
4. The extension compares that email with the **Email** field of the Perforce user. Match: Helix Core issues a **ticket** (12 hours). Mismatch: refused.

**Use (automatic)**
Claude Code -> P4 MCP server (local process) -> reads the ticket -> Helix Core. When the ticket expires, calls fail with "login invalid" and Claude tells the developer to run `p4 login`.

## Security properties
- Passwords never pass through Claude, the MCP server, or configuration files.
- The Helix server certificate must already be trusted (`p4 trust`, after you confirm the fingerprint with your admin); connecting never trusts it for you and a changed certificate is refused.
- Helix Core runs at security level 4 with users created only by super users.
- Developers cannot write `main`; the extension service account is a separate, audited identity.
- MCP capability can be limited per group or user on the server.

## What is in this kit
| Path | Purpose |
|---|---|
| `plugins/helix-connector/` | Claude Code plugin: MCP config, skills, agents, `/helix-status` command |
| `scripts/onboard.ps1` | Developer: connect an existing workspace (script alternative to `/helix-connect`) |
| `scripts/check.ps1` | Developer: health check |
| `templates/`, `connector.config.json` | Files the scripts generate from; one place to point at a server |
| `docs/` | These guides |

Next: [04 - The MCP server, tool by tool](04-mcp-server-tools.md)
