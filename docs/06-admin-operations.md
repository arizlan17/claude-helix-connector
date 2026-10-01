# 06 - Admin operations

## Roles and what each can do
| Role | Sign-in | Group | Depot access | Can change server config? |
|---|---|---|---|---|
| **Developer** | Google SSO | `mds-developers` (12h ticket) | Read everything; write `dev/` and `features/` only | No |
| **Release manager** | Google SSO | `mds-release` | Write everywhere, including `main` | No |
| **Admin** (`p4admin`) | Local password (break-glass, not SSO) | none (super user) | Everything | Yes: users, groups, protections, `mcp.*` policy |
| **Service account** (`svc-auth`) | Local ticket, never expires (not SSO) | `svc-accounts` | Super, used only by the Authentication Service extension | Not used by people |

What developers cannot do: add users or groups, change protections, change MCP policy (`p4 property`), write `main`, or sign in with a Google account that does not match their Perforce Email. These need a super user and are enforced by the server, so editing local files (`.mcp.json`, `CLAUDE.md`, `.p4config`) does not raise a developer's access.

Notes:
- `add-developer.ps1` adds people to `mds-developers` only. Add release managers by hand: `p4 group mds-release`.
- Claude acts as the signed-in person with that person's permissions, never more.
- To stop developers adding unapproved MCP servers on their own PC, use the managed settings step in [08](08-going-live.md).

## Add a developer
```
scripts\add-developer.ps1 -User jsmith -Email john.smith@mitrai.com -FullName "John Smith" -AdminUser p4admin
```
What it does: checks your admin ticket, refuses an email already used by someone else, creates or updates the user, adds them to `mds-developers`, and prints the effective permission on `main` (expect `read`) and `features` (expect `write`).
Then tell the developer to run `onboard.ps1`. If Google is in Testing mode, add their email under **Audience -> Test users**.

**The Email field must equal the Google account address exactly.** That is what SSO matches on.

## Change what Claude may do
See `scripts\set-mcp-policy.ps1` and [04](04-mcp-server-tools.md#governance-controlling-mcp-from-the-server).
| Situation | Action |
|---|---|
| Contractors or interns: read only | `-Mode ReadOnly -Group <group>` |
| Investigate a suspected problem | `-Mode Off -TargetUser <user>` |
| Everyone stop | `p4 property -a -n mcp.enabled -v false` |

## Offboarding
1. Disable the Google account (SSO stops working immediately for new logins).
2. Remove the user from groups: `p4 group <group>`.
3. Optional: `p4 user -d -f <user>` after reassigning or reverting their pending work.
Existing tickets last at most 12 hours; `p4 logout -a -u <user>` ends them now.

## Promote to `main` (release manager)
Developers cannot write `main`. A release manager (group `mds-release`) reviews the shelf, integrates the reviewed change into `dev`, then into `main`, and submits.

## Audit
- Every Perforce action is tied to a user; Claude's actions appear under the developer who ran it.
- Server audit log: started with `-A <file>` (`audit.log`).
- Extension log: see [03](03-google-sso-helix-auth.md#where-to-look-when-it-fails).
- Useful queries: `p4 changes -m 20`, `p4 changes -u <user>`, `p4 describe -s <change>`, `p4 -ztag logger`.

## Rotate secrets
| Secret | How |
|---|---|
| Google client secret | Create a new one in Google Cloud Console, update the secrets file, restart the Authentication Service |
| `svc-auth` password | Set a new one as an admin, log in as `svc-auth`, keep the ticket unlimited |
| `p4admin` password | `p4 passwd` as `p4admin` |

## Backups (required for live)
Not configured in the reference setup. For live: nightly checkpoint (`p4d -jc`), journal rotation, and copy of the depot files and the extension data directory off the server. Test a restore.

## Upgrades
Upgrade `p4d`, the Authentication Service and Extension together (they share a release train, for example 2026.1). After upgrading: restart, run `p4 extension --run loginhook-a1 test-all`, log in as a test user.

Next: [07 - Troubleshooting](07-troubleshooting.md)
