# 07 - Troubleshooting

Run the health check first: `scripts\check.ps1 -Root <workspace folder>`.

| Symptom | Likely cause | Fix |
|---|---|---|
| `TCP connect to perforce:1666 failed. No such host` | `p4` ran where `.p4config` is not found, so it used the default host `perforce` | Run in the workspace folder, or once: `p4 set P4PORT=<server>` |
| `Perforce password (P4PASSWD) invalid or unset` | No ticket or ticket expired (12h) | `p4 login` |
| Google succeeds, then `Login invalid ... validation failed` | Google email differs from the Perforce user's Email | Sign in with the registered Google account, or admin corrects the Email. Check extension log for `identifiers do not match` |
| Google shows "Access blocked" | App in Testing and your account is not a test user | Add the email under Audience -> Test users, or use an Internal app |
| Google shows `redirect_uri_mismatch` | Redirect URI in the OAuth client differs from the service URL | Set it to exactly `<service base URL>/oidc/callback` |
| Browser does not open on `p4 login` | Old client or headless shell | Copy the printed URL into a browser; use P4 client 2019.1 or newer |
| `WARNING P4PORT IDENTIFICATION HAS CHANGED` | Server certificate changed | Do not trust blindly. Get the fingerprint from the admin, then `p4 trust` |
| `no permission for operation` on `main` | Protections (expected) | Work on `features/<name>` |
| Claude has no Perforce tools | MCP not approved or Claude Code not restarted in the workspace | Restart Claude Code in the workspace; approve `perforce-p4-mcp` |
| A tool reports it is blocked | Admin MCP policy | Ask the Helix admin; do not work around |
| `p4 extension --run loginhook-a1 test-all` fails | Service down, wrong `Service-URL`, or TLS mismatch | Check `https://<service>/status`, extension log, `Verify-Peer` and CA path |
| Everyone suddenly cannot log in | `svc-auth` ticket lost or Authentication Service down | Check service; log in as `svc-auth` (non-SSO) to renew; break-glass `p4admin` still works |
| `Initial passwords can only be set by a super-user` | `dm.user.setinitialpasswd=0` by design | Admin sets the first password; user changes it |

## Read the logs in this order
1. `p4 login` output and the browser page.
2. Extension log (`log.json`): what Google returned and how identities compared.
3. Authentication Service log.
4. `p4d.log`.

## Things to never do
- Paste a password, ticket, or Google secret into chat, tickets, or the depot.
- Turn `security` down or `dm.user.noautocreate` off to "make it work".
- Trust a changed certificate fingerprint without confirming it out of band.
