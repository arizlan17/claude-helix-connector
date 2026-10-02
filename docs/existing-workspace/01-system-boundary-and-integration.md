# 01 - System boundary and integration diagrams

Applies to the **existing workspace** setup (`onboard.ps1 -ExistingWorkspace`): you already have a Perforce user and workspace, and sign in with Google SSO. Diagrams are Mermaid, so GitHub renders them.

## 1. System boundary

What is inside the developer's PC, what is inside the company network, and what is external.

```mermaid
flowchart TB
    subgraph PC["Developer PC (Windows)"]
        direction TB
        DEV(["Developer"])
        BR["Browser<br/>Google sign-in only"]
        subgraph CC["Claude Code"]
            direction TB
            PLUG["helix-connector plugin<br/>6 skills, 7 agents, 3 commands"]
            HOOK["p4-guard hook<br/>blocks rule/permission edits"]
        end
        MCP["P4 MCP server<br/>(p4-mcp-server.exe)"]
        CLI["p4 command line"]
        WS[("Workspace folder<br/>.p4config, .p4ignore, .mcp.json<br/>CLAUDE.md, CODEBASE_NOTES.md<br/>.claude/settings.json + hooks")]
    end

    subgraph NET["Company network"]
        direction TB
        P4D[("Helix Core server p4d<br/>depot, protections, groups")]
        EXT["Helix Authentication Extension<br/>(inside p4d)"]
        HAS["Helix Authentication Service<br/>OIDC client"]
    end

    subgraph EXTN["External"]
        direction TB
        GOOG["Google identity<br/>OIDC provider"]
        ANTH["Claude model service<br/>(Anthropic)"]
    end

    DEV --> CC
    CC <-->|"prompts, tool results"| ANTH
    CC -->|"stdio tool calls"| MCP
    CC -->|"fallback commands"| CLI
    CC --> WS
    HOOK -.->|"inspects every Bash command"| CLI
    MCP -->|"P4 protocol over TLS"| P4D
    CLI -->|"P4 protocol over TLS"| P4D
    P4D --- EXT
    EXT -->|"HTTPS"| HAS
    HAS -->|"OIDC"| GOOG
    BR -->|"sign in"| HAS
    DEV --> BR
```

Boundaries to know about:

| Boundary | What crosses it | Control |
|---|---|---|
| PC to Helix Core | P4 protocol over TLS; your ticket | Server certificate pinned by fingerprint (`p4 trust`); server enforces protections as **you** |
| PC to Google / Authentication Service | Browser sign-in only | Google email must equal the Perforce user's Email; Claude never sees the password |
| Claude Code to the Claude model service | Prompts, file contents Claude reads, tool results | Do not point Claude at secrets; deny rules and `.p4ignore` keep them out; ask your security team if depot code is restricted |
| Claude to Helix Core | Read, edit, shelve, submit as the signed-in user | Server permissions, MCP policy, `p4-guard` hook (see section 3) |

## 2. Integration: how the pieces work together

### 2.1 Sign-in (done by you, not Claude)

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant CLI as p4 login
    participant P4D as Helix Core + Auth Extension
    participant HAS as Authentication Service
    participant BR as Browser
    participant G as Google

    Dev->>CLI: p4 login (or onboard.ps1 runs it if ticket expired)
    CLI->>P4D: login request
    P4D->>HAS: start SSO for this user
    HAS-->>BR: open sign-in page
    BR->>G: Google sign-in (OIDC, PKCE)
    G-->>HAS: verified profile (email)
    HAS-->>P4D: identity
    P4D->>P4D: Google email equals Perforce user Email?
    P4D-->>CLI: ticket (limited lifetime)
```

### 2.2 First run, learn, work

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant CC as Claude Code + plugin
    participant AG as Read-only agents
    participant MCP as P4 MCP server
    participant P4D as Helix Core
    participant WS as Workspace files

    Note over Dev,WS: A. First run (/helix-init)
    Dev->>CC: /helix-init
    CC->>AG: p4-discoverer
    AG->>MCP: query_server, query_workspaces
    AG->>P4D: p4 protects, groups, dirs, property -l (read only)
    AG-->>CC: access levels, layout, MCP policy
    CC-->>Dev: proposed changes, no writes yet
    Dev->>CC: approve
    CC->>WS: CLAUDE.md block, .claude/settings.json, .p4config, .p4ignore

    Note over Dev,WS: B. Learn the code (/helix-learn)
    Dev->>CC: /helix-learn
    CC->>AG: p4-codebase-analyst
    AG->>WS: read build files and code (no secrets)
    AG->>MCP: query_files, query_changelists (history)
    AG-->>CC: domain, conventions, reusable methods
    CC-->>Dev: draft notes
    Dev->>CC: approve
    CC->>WS: CODEBASE_NOTES.md

    Note over Dev,WS: C. Build a change
    Dev->>CC: describe the task
    CC->>WS: read CODEBASE_NOTES.md, reuse existing methods
    CC->>MCP: sync, edit (open files), then write code locally
    CC->>AG: p4-guard (pre-flight), p4-reviewer
    CC->>MCP: shelve
    CC-->>Dev: changelist number
    Dev->>CC: "submit it" (explicit, same turn)
    CC->>MCP: submit
    MCP->>P4D: as you, within your permissions
```

## 3. Layers that keep server rules read-only

Claude may **read** protections, groups, users and MCP policy. It cannot edit or delete them.

```mermaid
flowchart TB
    REQ["Claude wants to run a command"] --> L1
    L1{"Layer 1<br/>p4-guard hook<br/>p4 protect, group -i or -d,<br/>property -a, admin, obliterate,<br/>login, p4d?"}
    L1 -- "yes" --> BLOCK1["Blocked with a reason"]
    L1 -- "no" --> L2
    L2{"Layer 2<br/>Claude Code deny rules<br/>and permission prompts"}
    L2 -- "denied or user says no" --> BLOCK2["Blocked"]
    L2 -- "allowed" --> L3
    L3{"Layer 3<br/>MCP policy on the server<br/>enabled, read-only, allowed toolsets"}
    L3 -- "tool not allowed" --> BLOCK3["Refused by MCP server"]
    L3 -- "allowed" --> L4
    L4{"Layer 4 (the real guarantee)<br/>Helix protections for your user<br/>no admin or super rights"}
    L4 -- "no permission" --> BLOCK4["Refused by Helix Core"]
    L4 -- "permitted" --> OK["Runs, attributed to you in the audit log"]
```

Layers 1 and 2 inspect command text, so they are safety nets. Layer 4 is the guarantee, which is why `onboard.ps1` refuses an `admin` or `super` account unless you pass `-AllowAdminAccount`.

## 4. Files created in the workspace

```mermaid
flowchart LR
    ONB["onboard.ps1 -ExistingWorkspace"] --> A[".p4config<br/>server, user, workspace"]
    ONB --> B[".p4ignore"]
    ONB --> C[".mcp.json<br/>MCP server + log dir"]
    ONB --> D["CLAUDE.md<br/>generic Perforce rules"]
    ONB --> E[".claude/hooks/p4-guard.ps1<br/>.claude/settings.json"]
    INIT["/helix-init"] -. "merges" .-> D
    INIT -. "merges" .-> E
    INIT -. "adds missing keys" .-> A
    INIT -. "appends" .-> B
    LEARN["/helix-learn"] --> F["CODEBASE_NOTES.md"]
    LEARN -. "adds one line" .-> D
```

Solid arrows create a file; dotted arrows merge into one that exists. Existing files are never overwritten.

Next: [02 - Skills and agents guide](02-skills-and-agents-guide.md)
