# 02 - Skills, agents, commands and hook: what, why, how, and in what order

Everything here ships in the `helix-connector` plugin. **Skills** are instructions Claude follows when the situation matches. **Agents** are focused helpers that run on their own with limited tools. **Commands** are shortcuts you type. The **hook** runs automatically.

## 1. Order of use (existing workspace)

```mermaid
flowchart TB
    P0["A. Install the plugin<br/>/plugin marketplace add + install"] --> P1["B. Open the workspace folder<br/>in Claude Code"]
    P1 --> P2["C. Sign in yourself<br/>! p4 login (Google)"]
    P2 --> S0["D. /helix-connect<br/>skill p4-connect + connect.ps1"]
    S0 --> S1["E. Restart Claude Code once<br/>approve perforce-p4-mcp"]
    S1 --> S2["F. /helix-status<br/>check connection"]
    S2 --> S3["G. /helix-init<br/>skill p4-first-run + agent p4-discoverer"]
    S3 --> S4["H. /helix-learn<br/>skill p4-codebase-learn + agent p4-codebase-analyst"]
    S4 --> LOOP

    subgraph LOOP["Every task"]
        direction TB
        T1["Start: skill p4-helix<br/>(+ p4-feature-line if your layout uses lines)"] --> T2["Write code<br/>reuse CODEBASE_NOTES.md"]
        T2 --> T3["Agent p4-guard<br/>pre-flight check"]
        T3 --> T4["Agent p4-reviewer<br/>review the diff"]
        T4 --> T5["Skill p4-shelve-review<br/>+ agent p4-submitter shelves"]
        T5 --> T6["You ask to submit<br/>p4-submitter submits"]
    end

    LOOP -. "anytime" .-> X1["p4-reader: questions<br/>p4-changelog: standup<br/>p4-troubleshoot: errors"]
    HOOK["p4-guard hook<br/>runs automatically on every Bash command"] -.-> LOOP
```

| Step | Do | Why it comes here |
|---|---|---|
| A | `/plugin marketplace add ...` then `/plugin install helix-connector@mds-helix` | Gives you the commands, skills, agents and hook. Nothing else to clone |
| B | Open the workspace folder (the workspace Root) in Claude Code | `/helix-connect` works on the current folder and finds your workspace from it |
| C | `! p4 login` (only if not already signed in) | Claude never logs in for you; doing it first avoids a stop-and-retry |
| D | `/helix-connect` | Detects your user, server and workspace, checks trust, login and that you are not admin, writes the missing config files |
| E | Restart Claude Code in the folder, approve `perforce-p4-mcp` | The Perforce tools load only at session start (needed the first time) |
| F | `/helix-status` | Proves the connection works before anything else |
| G | `/helix-init` | Learns what the live server lets **you** do, so later rules match reality |
| H | `/helix-learn` | Learns the code before writing code, so new code reuses existing methods |
| then | Per task: implement, guard, review, shelve, submit | Safe path from edit to server |

Run G and H once per workspace, then again when the server rules or the code have changed a lot. If you prefer a script to `/helix-connect`, run `onboard.ps1 -ExistingWorkspace` from a clone of the kit in place of step D; everything else is the same.

## 2. Commands (you type these)

| Command | What it does | Use it when |
|---|---|---|
| `/helix-connect` | Runs `p4-connect`: detects your user, server and workspace, checks trust, login and that you are not admin, and writes the missing config files | Once per workspace, right after installing the plugin |
| `/helix-status` | Shows your user, server, workspace, ticket state and pending changes | First thing in a session, or when something looks wrong |
| `/helix-init` | Runs `p4-first-run`: reads the live server's rules and proposes updates to `CLAUDE.md`, `.claude/settings.json`, `.p4config`, `.p4ignore` | Once after onboarding, and after your permissions change |
| `/helix-learn` | Runs `p4-codebase-learn`: studies the code and saves `CODEBASE_NOTES.md` | Once after `/helix-init`, before building features in an unfamiliar area |

## 3. Skills (Claude applies these on its own, or you ask)

### p4-connect
- **What:** Runs the plugin's `connect.ps1` for the current folder. It detects your Perforce user, server and workspace (from `p4 set`, an existing `.p4config`, or by matching the folder to your workspace Root), checks the server is trusted and you are signed in, refuses `admin`/`super` accounts, and writes only the missing `.p4config`, `.p4ignore`, `CLAUDE.md` and `.claude/settings.json`.
- **Why:** The developer does not clone the kit or run a script, and Claude asks only for what it cannot detect.
- **How:** Open the workspace folder, run `! p4 login` if needed, then type `/helix-connect`. It may ask for the server, user or workspace, and whether to download the P4 MCP server. Restart Claude Code once if it tells you to.
- **Never:** logs in for you, trusts a certificate for you, overwrites a file, or changes the server.
- **If it stops:** not signed in, run `! p4 login`. Certificate not trusted, confirm the fingerprint with your admin and run `p4 trust`. Admin account, use a normal one.

### p4-first-run
- **What:** Discovers your access level, groups, workspace view, layout and MCP policy (read-only), then proposes file changes and writes them only after you approve.
- **Why:** Rules written for another project do not fit yours. This makes `CLAUDE.md` and the allow/deny list match what the server actually permits.
- **How:** Type `/helix-init`, read the proposed changes, approve. It stops if your account has `admin` or `super` rights. It merges into existing files and never overwrites your own content.
- **Writes:** `CLAUDE.md` (managed block), `.claude/settings.json`, `.p4config` (missing keys), `.p4ignore` (missing lines).

### p4-codebase-learn
- **What:** Has the analyst agent read the code and produce notes on stack, structure, domain terms, conventions, best practices and reusable methods.
- **Why:** Stops duplicate helpers and style drift. Later work reads the notes first.
- **How:** Type `/helix-learn`, name the scope (a module or the whole workspace), review the draft, approve.
- **Writes:** `CODEBASE_NOTES.md` in the workspace root, a line in `CLAUDE.md`, and an entry in `.p4ignore` unless you want it in the depot.

### p4-helix
- **What:** The everyday Perforce method: sync, `edit` before changing a file, numbered changelists, `reconcile`, shelve, then wait for you to ask for a submit. Includes a table of which MCP tool does what.
- **Why:** Perforce files are read-only until opened and this is not Git. This keeps Claude from fighting the tool.
- **How:** Automatic whenever Claude works on files in the workspace. Ask: "use the Perforce workflow for this change".

### p4-feature-line
- **What:** Explains the `main` / `dev` / `features/<name>` layout and how to start a feature line.
- **Why:** Developers write feature lines and cannot write `main`.
- **How:** Use it only if your project uses that layout. If yours differs, `/helix-init` records the real writable folders in `CLAUDE.md`, and you should tell Claude to follow those instead.

### p4-shelve-review
- **What:** Shelve, unshelve, update a shelf, share work in progress.
- **Why:** Shelving is the default hand-over, so a human reviews before anything is submitted.
- **How:** Say "shelve this" or "update my shelf".

### p4-troubleshoot
- **What:** Fixes for login invalid, connection refused, unknown host, trust/fingerprint warnings and "no permission".
- **Why:** The common failures have known causes; this avoids guessing.
- **How:** Automatic when a call fails. Never works around a permission error, never asks for your password.

## 4. Agents (focused helpers)

| Agent | Can it change anything? | What it does | Why | How to use |
|---|---|---|---|---|
| `p4-discoverer` | No | Reads your access level per folder, groups, ticket timeout, layout, streams, `mcp.*` policy | Feeds `/helix-init` with facts | Runs inside `/helix-init` |
| `p4-codebase-analyst` | No | Reads code, returns a sectioned report with `path:line` evidence | Feeds `/helix-learn`; also answers "how does this code base do X" | Runs inside `/helix-learn`, or ask directly |
| `p4-reader` | No | Answers questions: file contents, history, blame, diffs, who changed what | A hard guarantee that nothing changes while you investigate | "Use p4-reader to show who last changed X" |
| `p4-changelog` | No | Summarises recent submitted changes by theme with authors and changelist numbers | Standups and release notes | "Summarise last week on `<line>` for standup" |
| `p4-reviewer` | No | Reviews a shelved, pending or submitted changelist for bugs, security and style | A first review before a human reviews | "Review shelved change 12345" |
| `p4-guard` | No | Pre-flight before shelve or submit: no `.p4config`, keys or secrets in opened files, nothing targeting `main` | Stops credentials and wrong-line writes before they leave your PC | "Run p4-guard on change 12345" |
| `p4-submitter` | **Yes** | Opens files, manages changelists, shelves; submits only on your explicit request in that turn | The only agent allowed to write to the server, so it is tightly rules-bound | "Shelve my work" / "Submit change 12345" |

> Two things are named `p4-guard`. The **agent** is the pre-flight check on your opened files. The **hook** is the automatic command filter in section 5.

## 5. The p4-guard hook (automatic)

- **What:** A `PreToolUse` hook that checks every Bash command Claude is about to run. It blocks commands that would edit or delete server rules and permissions, such as `p4 protect`, `p4 group -i/-d`, `p4 user -i/-d`, `p4 property -a/-d`, `p4 admin`, `p4 obliterate`, `p4 login`, `p4d`, and the admin scripts.
- **Allows:** Reading rules, for example `p4 protects`, `p4 group -o`, `p4 property -l`.
- **Why:** Claude can read the rules to follow them but must never change them.
- **How:** Nothing to do. It ships in the plugin, and `onboard.ps1` also copies it to `.claude/hooks/`. If it blocks something, the message says why; ask your Helix admin for rule changes.
- **Limit:** It reads command text, so a determined workaround is stopped only by the server (your account has no admin rights).

## 6. Typical session

1. Open the workspace folder in Claude Code. `/helix-status`.
2. Ask: "Add email validation to the customer import." Claude reads `CODEBASE_NOTES.md`, finds the existing validator, and reuses it.
3. Claude uses `p4-helix` to sync, `edit`, change code, and run your build and tests.
4. "Run the guard and a review." You get PASS or BLOCKED, then findings.
5. "Shelve it." `p4-submitter` shelves and gives you the changelist number.
6. A human reviews. When you are ready: "Submit change 12345."

Previous: [01 - System boundary and integration](01-system-boundary-and-integration.md) | Next: [03 - Complete guide](03-complete-guide.md)
