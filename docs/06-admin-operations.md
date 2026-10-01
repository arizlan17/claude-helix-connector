# 06 - Admin operations

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
