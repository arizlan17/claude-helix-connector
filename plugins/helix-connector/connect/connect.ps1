<#
.SYNOPSIS
  Connect the current folder (an existing Perforce workspace) to Claude Code. Run by the /helix-connect command.

.DESCRIPTION
  Self-contained: ships inside the plugin, needs no clone of the kit.
  Detects user, server and workspace from your own Perforce settings, checks the server and your login,
  refuses admin/super accounts, and writes ONLY missing files: .p4config, .p4ignore, CLAUDE.md and
  .claude/settings.json (deny rules). The MCP server and guard hook come from the plugin itself.
  Never logs in, never trusts a certificate, never overwrites a file, never changes the server.

  Exit codes: 0 ok | 2 need more info (NEED: lines) | 3 not signed in | 4 certificate not trusted
              5 admin/super account refused | 6 P4 MCP server missing | 1 other error
#>
[CmdletBinding()]
param(
    [string]$User, [string]$Workspace, [string]$P4Port,
    [string]$Root = (Get-Location).Path,
    [string]$P4Path,
    [switch]$InstallMcp,          # download the P4 MCP server (only after the user agreed)
    [switch]$AllowAdminAccount
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Get-Content (Join-Path $here 'connect.config.json') -Raw | ConvertFrom-Json

function Say([string]$tag, [string]$text, [string]$color = 'White') { Write-Host ("{0,-5} {1}" -f $tag, $text) -ForegroundColor $color }
function Ok([string]$t)   { Say 'OK' $t Green }
function Warn([string]$t) { Say '!!' $t Yellow }
function Bad([string]$t)  { Say 'XX' $t Red }
function Need([string]$t) { Say 'NEED' $t Cyan }

function P4 {   # run p4 quietly, return output lines (stderr merged, never throws)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $script:p4 @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
}
function P4Conn([string[]]$a) { P4 -p $script:port -u $script:user @a }

function Find-P4Exe([string]$Hint) {
    $c = @(@($Hint, (Get-Command p4 -ErrorAction SilentlyContinue).Source, 'C:\Program Files\Perforce\p4.exe') | Where-Object { $_ })
    foreach ($x in $c) { if (Test-Path $x) { return (Resolve-Path $x).Path } }
    $null
}
function Find-Mcp {
    $c = @(@($env:P4MCP_BIN, (Get-Command p4-mcp-server -ErrorAction SilentlyContinue).Source) | Where-Object { $_ })
    $dir = Join-Path $env:LOCALAPPDATA 'claude-helix\p4mcp'
    if (Test-Path $dir) { $c += (Get-ChildItem $dir -Recurse -Filter p4-mcp-server.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName) }
    foreach ($x in $c) { if ($x -and (Test-Path $x)) { return (Resolve-Path $x).Path } }
    $null
}
function Norm([string]$p) { ($p.Trim().TrimEnd('\', '/') -replace '/', '\').ToLower() }

# ---------------------------------------------------------------- 1. tools
Say '==>' "Checking tools"
$script:p4 = Find-P4Exe $P4Path
if (-not $script:p4) {
    Bad 'p4 command line client not found.'
    Write-Host '      Install it from https://www.perforce.com/downloads/helix-command-line-client-p4 and run /helix-connect again.'
    exit 1
}
Ok "p4: $script:p4"

$mcp = Find-Mcp
if (-not $mcp) {
    if (-not $InstallMcp) {
        Warn 'P4 MCP server not found.'
        Need "Ask the user: download $($cfg.p4mcp.winZipUrl) to $env:LOCALAPPDATA\claude-helix\p4mcp ? If yes, run again with -InstallMcp."
        exit 6
    }
    $dest = Join-Path $env:LOCALAPPDATA 'claude-helix\p4mcp'
    New-Item -ItemType Directory -Force $dest | Out-Null
    $zip = Join-Path $dest 'p4-mcp-server-win.zip'
    Invoke-WebRequest -Uri $cfg.p4mcp.winZipUrl -OutFile $zip -UseBasicParsing
    Say 'INFO' "SHA256 $((Get-FileHash $zip -Algorithm SHA256).Hash) (record it in your change log)"
    Expand-Archive $zip $dest -Force
    $mcp = Find-Mcp
    if (-not $mcp) { Bad 'Downloaded archive did not contain p4-mcp-server.exe'; exit 1 }
}
Ok "MCP server: $mcp"
$envChanged = $false
if ($env:P4MCP_BIN -ne $mcp -or -not [Environment]::GetEnvironmentVariable('P4MCP_BIN', 'User')) {
    [Environment]::SetEnvironmentVariable('P4MCP_BIN', $mcp, 'User'); $envChanged = $true
}

# ---------------------------------------------------------------- 2. detect user / server / workspace
Say '==>' "Detecting your Perforce settings"
$existing = @{}
$cfgFile = Join-Path $Root '.p4config'
if (Test-Path $cfgFile) {
    Get-Content $cfgFile | Where-Object { $_ -match '^\w+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $existing[$k] = $v.Trim() }
}
function P4Set([string]$name) {
    $l = P4 set $name | Where-Object { $_ -match "^$name=" } | Select-Object -First 1
    if ($l) { return (($l -replace "^$name=", '') -replace '\s+\((set|config|env)[^)]*\)\s*$', '').Trim() }
}
$script:user = if ($User) { $User } elseif ($existing.P4USER) { $existing.P4USER } elseif ($env:P4USER) { $env:P4USER } else { P4Set 'P4USER' }
$script:port = if ($P4Port) { $P4Port } elseif ($existing.P4PORT) { $existing.P4PORT } elseif ($env:P4PORT) { $env:P4PORT } elseif ($cfg.p4port) { $cfg.p4port } else { P4Set 'P4PORT' }
$ws = if ($Workspace) { $Workspace } elseif ($existing.P4CLIENT) { $existing.P4CLIENT } elseif ($env:P4CLIENT) { $env:P4CLIENT } else { P4Set 'P4CLIENT' }

$missing = $false
if (-not $script:port) { Need 'Ask the user for the Perforce server address (for example ssl:helix.company.com:1666), then run with -P4Port.'; $missing = $true }
if (-not $script:user) { Need 'Ask the user for their Perforce user name, then run with -User.'; $missing = $true }
if ($missing) { exit 2 }
Ok "server: $($script:port)   user: $($script:user)"

# ---------------------------------------------------------------- 3. server, trust, login
Say '==>' "Checking the server"
$info = P4Conn @('info')
if ("$info" -match 'authenticity|fingerprint|IDENTIFICATION HAS CHANGED|not trusted') {
    Bad "The server certificate is not trusted (or has changed)."
    Need "Tell the user to confirm the fingerprint with their Helix admin, then run themselves: p4 -p $($script:port) trust"
    exit 4
}
if ("$info" -notmatch 'Server (address|version)|User name') {
    Bad "Cannot reach $($script:port). Check the address and VPN."
    exit 1
}
Ok 'server reachable and trusted'

$ticket = P4Conn @('login', '-s')
if ("$ticket" -notmatch 'ticket expires') {
    Bad 'You are not signed in.'
    Need 'Tell the user to run this themselves (Google opens in the browser): ! p4 login   then run /helix-connect again. Claude must not log in for them.'
    exit 3
}
Ok 'signed in'

# ---------------------------------------------------------------- 4. never run as admin
$first = (((P4Conn @('protects', '-m', '//...')) -join ' ').Trim() -split '\s+' | Select-Object -First 1)
$lvl = if ($first -match '^(list|read|open|write|review|owner|admin|super)$') { $first.ToLower() } else { $null }
if ($lvl -in 'admin', 'super') {
    if (-not $AllowAdminAccount) {
        Bad "User '$($script:user)' has $lvl rights. Claude acts as this user and could change server rules."
        Need 'Tell the user to use a normal (non-admin) Perforce account, or explicitly accept the risk and run with -AllowAdminAccount.'
        exit 5
    }
    Warn "Continuing with an $lvl account (-AllowAdminAccount). The guard hook blocks rule changes, but the server will not."
} elseif ($lvl) { Ok "access level: $lvl (cannot change server rules)" }
else { Warn 'Could not determine your access level; continuing. Make sure this is not an admin account.' }

# ---------------------------------------------------------------- 5. workspace
Say '==>' "Finding your workspace"
if (-not $ws) {
    $mine = P4Conn @('clients', '-u', $script:user)
    $hits = @()
    foreach ($l in $mine) {
        if ($l -match "^Client (\S+) \S+ root (.+?) '") {
            $r = Norm $Matches[2]; $here2 = Norm $Root
            if ($here2 -eq $r -or $here2.StartsWith($r + '\')) { $hits += $Matches[1] }
        }
    }
    if ($hits.Count -eq 1) { $ws = $hits[0]; Ok "workspace matched to this folder: $ws" }
    elseif ($hits.Count -gt 1) { Need "Several workspaces match this folder: $($hits -join ', '). Ask the user which one, then run with -Workspace."; exit 2 }
    else { Need "No workspace of yours has this folder as its Root ($Root). Ask the user for the workspace name (p4 clients -u $($script:user)), then run with -Workspace."; exit 2 }
}
if (-not (P4Conn @('clients', '-e', $ws))) { Bad "Workspace '$ws' not found on the server."; exit 1 }
$clientRoot = (((P4Conn @('client', '-o', $ws)) | Where-Object { $_ -match '^Root:' }) -replace '^Root:\s*', '').Trim()
if ($clientRoot -and (Norm $Root) -ne (Norm $clientRoot) -and -not (Norm $Root).StartsWith((Norm $clientRoot) + '\')) {
    Warn "This folder ($Root) is outside the workspace Root ($clientRoot). Open Claude Code in the workspace folder."
}
Ok "workspace: $ws"

# ---------------------------------------------------------------- 6. write missing files (never overwrite)
Say '==>' "Writing missing files in $Root"
function Put([string]$rel, [string]$content) {
    $t = Join-Path $Root $rel
    if (Test-Path $t) { Warn "$rel exists - left unchanged"; return }
    New-Item -ItemType Directory -Force (Split-Path -Parent $t) | Out-Null
    [IO.File]::WriteAllText($t, $content); Ok $rel
}
Put '.p4config' "# Perforce connection for this workspace. Keep OUT of the depot.`nP4PORT=$($script:port)`nP4USER=$($script:user)`nP4CLIENT=$ws`nP4IGNORE=.p4ignore`n"
Put '.p4ignore' ".p4config`n.p4ignore`n.env`n.env.*`nsecrets/`n*.pem`n*.key`n.claude/settings.local.json`n"
Put 'CLAUDE.md' @'
# Claude Code on Helix Core (Perforce)

This folder is a Perforce workspace. Connection details live in `.p4config`, which is never versioned. It is not a Git repository.

## Version control rules
- Use Perforce only. No git commands, no pull requests.
- Prefer the `perforce-p4-mcp` MCP tools; use the `p4` CLI only as a fallback.
- Depot files are read-only until opened: `modify_files` action `edit`. New files: `add`. Renames: `move`.
- Follow this project's own branching and submit rules. When unsure where a change belongs, ask before writing.
- Put work in a numbered changelist with a clear description. Shelve by default.
- Submit only when the user explicitly asks for it in that turn.
- Never ask for, print, or store a password or ticket. Never put `.p4config` in the depot.
- Claude may read server rules and permissions but must never edit or delete them.
- If a command reports the login is invalid or expired, stop and tell the user to run `p4 login` (it opens Google SSO in the browser).

## Project
If `CODEBASE_NOTES.md` exists, read it before writing code and reuse the methods it lists (create it with `/helix-learn`).
Describe this project's stack, conventions, and build/test commands here so Claude matches them.
'@
Put '.claude/settings.json' @'
{
  "permissions": {
    "deny": [
      "Bash(p4d*)"
    ]
  }
}
'@

# ---------------------------------------------------------------- done
Write-Host ''
Say 'DONE' "Connected. Folder: $Root" Green
if ($envChanged) { Need 'P4MCP_BIN was set for your user. Tell the user to restart Claude Code once so the Perforce tools load.' }
else { Need 'If the Perforce tools (perforce-p4-mcp) are not available yet, tell the user to restart Claude Code in this folder and approve the server.' }
Need 'Suggest next steps: /helix-status, then /helix-init, then /helix-learn.'
exit 0
