---
name: p4-feature-line
description: Use when starting a new feature or fix in Helix Core, creating a features/<name> line from dev, or when a write to main is denied. Explains the main/dev/features layout.
---

# Feature lines: main / dev / features

Depot layout per project, for example `//mds/springbatch-demo/`:

| Line | Who writes | Purpose |
|---|---|---|
| `main` | release group only | Released, stable code |
| `dev` | developers | Integration line for reviewed work |
| `features/<name>` | developers | Your isolated work |

## Start a feature
1. Pick a short kebab-case name, for example `rizlan-email-validation`.
2. Create the line from `dev`. The workspace already maps `features/...`. If the MCP tools have no branch action, copy with the CLI:
   `p4 populate -d "Start feature <name>" //mds/<project>/dev/... //mds/<project>/features/<name>/...`
3. `sync` `features/<name>/...`, then `edit` files there. Never edit `dev/` or `main/` directly for feature work.
4. Hand work over with `shelve`, not `submit`, until a human has reviewed it.

## Bring it back
Do not integrate to `dev` or `main` yourself. Shelve, give the user the changelist number, and let a reviewer or the release manager promote it.

## If a write is denied
A "no permission" error on `main` is expected and correct. Explain that developers cannot write to `main` and continue on a feature line. Never try to change protections.
