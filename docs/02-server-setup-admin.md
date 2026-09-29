# 02 - Server setup (admin)

These steps are how the PoC server was built on a single machine (paths such as `D:\helix` are the PoC's). The build scripts are kept with the PoC and are not part of this repository. In live, your existing Helix Core replaces steps 1-2; steps 3-5 still apply.

## Step 1 - Create and harden the server (`01-bootstrap-server.ps1`)
| Action | Why |
|---|---|
| TLS certificate, server on `ssl:1666` | Encrypts tickets and file content; lets clients pin a fingerprint |
| `security=4` | Every command needs authentication; no unauthenticated data leaks |
| `dm.user.noautocreate=2` | Only super users create users; nobody self-registers by connecting |
| `dm.user.setinitialpasswd=0`, `dm.user.resetpassword=1`, `dm.password.minlength=10` | Admin-set passwords must be changed by the owner; strong minimum |
| `run.users.authorize=1`, `dm.info.hide=1`, `dm.keys.hide=2` | Reveal less to callers who lack access |
| `server.allowpush=0`, `server.commandlimits=2` | Disable push; enforce group limits |
| Local admin `p4admin` with a random password kept in a locked folder | Break-glass account that does not depend on SSO |

Gotcha found while building: a fresh `p4d` needs user auto-create temporarily enabled to create the first user, then it must be turned off (the script does both).

## Step 2 - Depot, groups, protections (`02-depot-and-access.ps1`)
- Depot `mds`, project layout `//mds/<project>/{main,dev,features}`.
- Groups: `mds-developers` (12h ticket), `mds-release` (promotes to `main`).
- Protections use **additive rules only**:
  ```
  super user p4admin * //...
  super user svc-auth * //...
  read  group mds-developers * //mds/...
  write group mds-developers * //mds/*/dev/...
  write group mds-developers * //mds/*/features/...
  write group mds-release    * //mds/...
  ```
  A first version used an exclusion line to block `main`; the server still reported `write`. Additive rules are easier to reason about and verified with `p4 protects -m -u <user> <path>` (expect `read` on main, `write` on dev/features).
- `typemap` marks jars, zips and images as binary.
- The script creates groups only if missing, so re-running it never removes members added later.

## Step 3 - Authentication Service (`03-configure-auth-service.ps1`)
Installs and configures the Helix Authentication Service for Google OIDC. See [03 - Google SSO](03-google-sso-helix-auth.md).

## Step 4 - Extension service account (`04-extension-account.ps1`)
The extension acts through a dedicated user, `svc-auth`:
- Needs **super** rights (documented requirement) and a ticket that **never expires** (group `svc-accounts`, `Timeout: unlimited`). If this ticket expired nobody could sign in.
- Separate account so its actions are distinguishable in the audit log and it can be rotated or disabled without touching the human admin.

## Step 5 - Extension (`05-configure-extension.ps1`)
Installs `Auth::loginhook`, sets global config (service URL, CA, verify host/peer) and the instance config `loginhook-a1`. `non-sso-users` lists `p4admin` and `svc-auth` so they keep working if Google is unreachable. Restart `p4d` afterwards, then verify with:
```
p4 extension --run loginhook-a1 test-all
```
Expected: `Request start: OK`, `Request status: OK`, `Command invoke: OK`.

## Starting and stopping the PoC
`D:\helix\scripts\start-all.ps1` starts `p4d` and the Authentication Service. In live run both as services (Windows service or systemd) so they survive reboots.

Next: [03 - Google SSO](03-google-sso-helix-auth.md)
