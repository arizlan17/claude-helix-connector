# 08 - From PoC to production

Everything below is a shortcut taken in the PoC and what replaces it in live.

| Area | PoC | Live |
|---|---|---|
| Helix Core | Background process, `localhost`, own data folder | Existing server or a service (systemd / Windows service), stable DNS name |
| TLS on Helix | Self-generated certificate | Certificate from your company CA; publish the fingerprint to developers |
| Authentication Service | `node` process on `localhost:3000`, own CA certificate | Service under a process manager, behind HTTPS with a company certificate, public/VPN address |
| Google OAuth | External + Testing, test users | **Internal** Workspace app; production redirect URI |
| Extension client certificate | Default shipped certificate | Own certificate pair; pin with `CLIENT_CERT_FP` / `CLIENT_CERT_CN` on the service |
| Extension account `svc-auth` | Super, unlimited ticket | Same, but test a narrower `admin` right; store its ticket file securely; monitor expiry |
| Secrets | Files in a locked folder | Secret manager or protected files; rotation schedule |
| Sessions store | In-memory | Redis if you run more than one service instance |
| Backups | None | Nightly checkpoint plus off-server copy; tested restore |
| Monitoring | Manual | Health checks on `p4d`, `/status`, ticket expiry of `svc-auth`, disk space |
| MCP binary | Downloaded ZIP | Approved internal copy or package with recorded SHA256 |
| Claude Code rollout | One workspace | Private plugin marketplace + managed settings (below) |

## Pointing the kit at a real server
Edit `connector.config.json` only:
```json
{ "p4port": "ssl:helix.company.com:1666",
  "serverFingerprint": "<from your admin>",
  "depotRoot": "//company/<project>" }
```
Then developers re-run `onboard.ps1`. The extension `Service-URL` is set once by `05-configure-extension.ps1` (or `p4 extension --configure`).

## Roll-out plan
1. **Pilot** with one team (5-10 people): measure ticket-expiry friction, denied writes, unclear errors.
2. **Publish the plugin** to a private marketplace repository so updates are versioned:
   - `.claude-plugin/marketplace.json` is included in the kit.
   - Developers add the marketplace once, then install `helix-connector`.
3. **Managed settings** (IT): pre-approve `perforce-p4-mcp`, and block unapproved MCP servers, so developers are not prompted and cannot add lookalikes.
4. **Support model**: name an owner for onboarding questions, the Authentication Service, and upgrades.
5. **Review** every quarter: MCP toolsets in use, `mcp.*` policy, group membership, secrets rotation.

## Licensing and ownership
The P4 MCP server, Helix Authentication Service and Extension are Perforce software. Check their licences and support terms before internal distribution; this kit packages and configures them and does not redistribute their binaries.

## Security review checklist
- [ ] Threat model: Claude acts as the developer; a stolen ticket is a stolen developer session (12h limit).
- [ ] `main` write access limited to the release group; verified with `p4 protects -m`.
- [ ] `svc-auth` scope reviewed and ticket protected.
- [ ] Google app Internal; no shared accounts.
- [ ] Audit log retention defined.
- [ ] Backup restore tested.
