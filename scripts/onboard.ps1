<#
.SYNOPSIS
  Connect Claude Code to a Perforce workspace you already have (Google SSO user + existing workspace).

.DESCRIPTION
  Script alternative to the /helix-connect command (which needs no clone):
  1. Finds the p4 CLI and the P4 MCP server (downloads the MCP server only if you approve).
  2. Checks the server is reachable and its certificate already trusted, and that you are signed in
     (runs `p4 login` only if your ticket expired; Google SSO opens in the browser).
  3. Refuses admin/super accounts unless you pass -AllowAdminAccount.
  4. Confirms your workspace exists, then writes ONLY missing files: .p4config, .p4ignore, .mcp.json,
     CLAUDE.md, .claude/settings.json and the guard hook. Existing files are never overwritten.
  It never creates a workspace, never syncs, never trusts a certificate, and never changes the server.

.EXAMPLE
  .\onboard.ps1 -User arizlan -Workspace arizlan-myproj -P4Port ssl:helix.company.com:1666
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$User,            # your Perforce user name
    [Parameter(Mandatory)][string]$Workspace,       # name of your existing workspace
    [string]$P4Port,                                # server address (defaults to p4port in connector.config.json)
    [string]$Root,                                  # workspace folder (defaults to the workspace's Root)
    [string]$P4Path,                                # explicit path to p4.exe if not on PATH
    [switch]$InstallMcp,                            # download the P4 MCP server without asking
    [switch]$SkipLogin,                             # for automation/tests: do not run p4 login
    [switch]$AllowAdminAccount,                     # proceed even if your Perforce user has admin/super rights (not recommended)
    [switch]$ExistingWorkspace                      # accepted for compatibility; this script is always existing-workspace only
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$cfg = Get-ConnectorConfig
$tpl = Join-Path $script:KitRoot 'templates'

Write-Step 'Checking prerequisites'
$p4 = Find-P4 $P4Path
if (-not $p4) {
    Write-Bad 'p4 command line not found.'
    Write-Host '    Install the P4 CLI from https://www.perforce.com/downloads/helix-command-line-client-p4 (or pass -P4Path), then re-run.'
    exit 1
}
Write-Ok "p4: $p4"

$mcp = Find-P4Mcp
if (-not $mcp) {
    Write-Warn2 'P4 MCP server not found.'
    $dest = Join-Path $env:LOCALAPPDATA 'claude-helix\p4mcp'
    $ok = $InstallMcp
    if (-not $ok) {
        $ans = Read-Host "    Download $($cfg.p4mcp.winZipUrl) to $dest ? (y/N)"
        $ok = ($ans -match '^(y|yes)$')
    }
    if (-not $ok) { Write-Bad 'MCP server is required. Re-run with -InstallMcp or set P4MCP_BIN.'; exit 1 }
    New-Item -ItemType Directory -Force $dest | Out-Null
    $zip = Join-Path $dest 'p4-mcp-server-win.zip'
    Invoke-WebRequest -Uri $cfg.p4mcp.winZipUrl -OutFile $zip -UseBasicParsing
    Write-Host "    SHA256: $((Get-FileHash $zip -Algorithm SHA256).Hash)  (record this in your change log)"
    Expand-Archive $zip $dest -Force
    $mcp = Find-P4Mcp
    if (-not $mcp) { throw 'Downloaded archive did not contain p4-mcp-server.exe' }
}
Write-Ok "MCP server: $mcp"
[Environment]::SetEnvironmentVariable('P4MCP_BIN', $mcp, 'User')   # used by the Claude Code plugin

$port = if ($P4Port) { $P4Port } else { $cfg.p4port }
if (-not $port) { Write-Bad 'No server address. Pass -P4Port (for example ssl:helix.company.com:1666).'; exit 1 }

Write-Step "Connecting to $port as $User"
$info = Invoke-P4 $p4 $port $User @('info')
if ("$info" -notmatch 'Server (address|version)|User name') {
    Write-Bad "Cannot reach $port, or its certificate is not trusted yet."
    Write-Host "    Check the address/VPN. If the certificate is new, confirm its fingerprint with your admin, then run: p4 -p $port trust"
    exit 1
}
Write-Ok 'server reachable and trusted'

$ticket = Invoke-P4 $p4 $port $User @('login', '-s')
if ("$ticket" -match 'ticket expires') { Write-Ok 'already signed in' }
elseif ($SkipLogin) { Write-Warn2 'Not signed in (SkipLogin set). Run p4 login before using Claude.' }
else {
    Write-Step 'Signing in (Google SSO opens in your browser)'
    & $p4 -p $port -u $User login
    if ($LASTEXITCODE -ne 0) { Write-Bad 'Login failed. Use the Google account registered for your Perforce user.'; exit 1 }
    Write-Ok 'signed in'
}

if (-not $SkipLogin) { Assert-NotAdminAccount $p4 $port $User $AllowAdminAccount.IsPresent }

Write-Step "Checking workspace $Workspace"
if (-not (Invoke-P4 $p4 $port $User @('clients', '-e', $Workspace))) {
    Write-Bad "Workspace '$Workspace' not found on $port. Check the name with: p4 -u $User clients -u $User"
    exit 1
}
$clientRoot = (((Invoke-P4 $p4 $port $User @('client', '-o', $Workspace)) | Where-Object { $_ -match '^Root:' }) -replace '^Root:\s*', '').Trim()
if (-not $Root) { $Root = $clientRoot }
if (-not $Root) { Write-Bad 'Could not determine the workspace folder. Pass -Root.'; exit 1 }
if ($clientRoot -and (($Root.TrimEnd('\', '/') -replace '/', '\') -ine ($clientRoot.TrimEnd('\', '/') -replace '/', '\'))) {
    Write-Warn2 "Root $Root differs from the workspace's Root ($clientRoot)."
}
Write-Ok "workspace root: $Root"

Write-Step "Writing missing files in $Root (existing files are never overwritten)"
New-Item -ItemType Directory -Force $Root | Out-Null
$logDir = Join-Path $env:LOCALAPPDATA 'claude-helix\logs'
$vals = @{ P4PORT = $port; P4USER = $User; P4CLIENT = $Workspace
           P4MCP_BIN = ($mcp -replace '\\', '\\'); LOG_DIR = ($logDir -replace '\\', '\\') }
$files = [ordered]@{ '.p4config' = 'p4config.template'; '.p4ignore' = 'p4ignore.template'; '.mcp.json' = 'mcp.json.template'; 'CLAUDE.md' = 'CLAUDE.md.template' }
foreach ($name in $files.Keys) {
    $target = Join-Path $Root $name
    if (Test-Path $target) { Write-Warn2 "$name exists - left unchanged"; continue }
    [IO.File]::WriteAllText($target, (Expand-Template (Join-Path $tpl $files[$name]) $vals))
    Write-Ok $name
}
Install-ClaudeGuard $Root
Write-Host "`nDone. Open '$Root' in Claude Code, approve the 'perforce-p4-mcp' server, and try /helix-status." -ForegroundColor Green
