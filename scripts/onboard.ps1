<#
.SYNOPSIS
  Developer onboarding: connect this PC and a workspace folder to Helix Core so Claude Code can use it.

.DESCRIPTION
  1. Finds the p4 CLI and the P4 MCP server (downloads the MCP server only if you approve).
  2. Pins the Helix server's TLS fingerprint from connector.config.json (never trusts blindly).
  3. Writes .p4config, .p4ignore, .mcp.json and CLAUDE.md into the workspace folder.
  4. Runs `p4 login` (Google SSO opens in the browser), creates your workspace, syncs.

.EXAMPLE
  .\onboard.ps1 -User arizlan -Root D:\work\mds

.EXAMPLE
  # Already have a Perforce user (Google SSO) and a workspace: connect Claude to it, change nothing else.
  .\onboard.ps1 -ExistingWorkspace -User arizlan -Workspace arizlan-myproj -P4Port ssl:helix.company.com:1666
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$User,            # your Perforce user name (admin gave it to you)
    [string]$Root,                                  # workspace folder to create/use (existing mode: defaults to the workspace's Root)
    [string]$Workspace,                             # defaults to <user>-mds
    [string]$GoogleEmail,                           # Google account email registered on your Perforce user (asked if omitted)
    [string]$P4Path,                                # explicit path to p4.exe if not on PATH
    [switch]$InstallMcp,                            # download the P4 MCP server without asking
    [switch]$SkipLogin,                             # for automation/tests: do not run p4 login
    [switch]$SkipSync,
    [switch]$AllowAdminAccount,                     # proceed even if your Perforce user has admin/super rights (not recommended)
    [switch]$ExistingWorkspace,                     # connect to a workspace you already have: no workspace creation, no sync, no overwrites
    [string]$P4Port                                 # server address for -ExistingWorkspace (defaults to p4port in connector.config.json)
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$cfg = Get-ConnectorConfig
if (-not $ExistingWorkspace) {
    if (-not $Root) { throw '-Root is required (or use -ExistingWorkspace).' }
    if (-not $Workspace) { $Workspace = "$User-mds" }
}
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

if ($ExistingWorkspace) {
    # Existing user + workspace: you already sign in with Google SSO, so skip the SSO prompts, the
    # Authentication Service check, certificate pinning, workspace creation and sync.
    if (-not $Workspace) { Write-Bad '-Workspace (the name of your existing workspace) is required with -ExistingWorkspace.'; exit 1 }
    $port = if ($P4Port) { $P4Port } else { $cfg.p4port }

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
    $vals = @{ P4PORT = $port; P4USER = $User; P4CLIENT = $Workspace; DEPOT_ROOT = $cfg.depotRoot
               P4MCP_BIN = ($mcp -replace '\\', '\\'); LOG_DIR = ($logDir -replace '\\', '\\') }
    $files = [ordered]@{ '.p4config' = 'p4config.template'; '.p4ignore' = 'p4ignore.template'; '.mcp.json' = 'mcp.json.template'; 'CLAUDE.md' = 'CLAUDE.md.existing.template' }
    foreach ($name in $files.Keys) {
        $target = Join-Path $Root $name
        if (Test-Path $target) { Write-Warn2 "$name exists - left unchanged"; continue }
        [IO.File]::WriteAllText($target, (Expand-Template (Join-Path $tpl $files[$name]) $vals))
        Write-Ok $name
    }
    if (-not (Test-Path (Join-Path $Root '.p4config'))) { Write-Bad '.p4config missing'; exit 1 }
    Install-ClaudeGuard $Root
    Write-Host "`nDone. Open '$Root' in Claude Code, approve the 'perforce-p4-mcp' server, and try /helix-status." -ForegroundColor Green
    exit 0
}

Write-Step 'Google SSO via Helix Authentication Service (required)'
Write-Host "    Sign-in uses $($cfg.auth.service) with Google as the OIDC provider. There is no password login."
Write-Host '    Your Google account email must exactly match the Email on your Perforce user (ask your Helix admin).'
if (-not $GoogleEmail -and -not $SkipLogin) {
    $GoogleEmail = Read-Host '    Google account email you will sign in with'
}
if (-not $SkipLogin -and $GoogleEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    Write-Bad 'A valid Google account email is required for SSO sign-in.'; exit 1
}
if (Test-HelixAuthService $cfg.auth.serviceUrl) { Write-Ok "Authentication service reachable: $($cfg.auth.serviceUrl)" }
else {
    Write-Bad "Cannot reach $($cfg.auth.serviceUrl). Google sign-in will fail until the Helix Authentication Service is running."
    Write-Host '    Check with your Helix admin (see docs/03-google-sso-helix-auth.md), then re-run.'
    exit 1
}

Write-Step "Pinning Helix server certificate for $($cfg.p4port)"
if ($cfg.p4port -like 'ssl:*') {
    if (-not $cfg.serverFingerprint) { throw 'connector.config.json has no serverFingerprint. Get it from your Helix admin.' }
    $already = Invoke-P4 $p4 $cfg.p4port $User @('trust', '-l')
    if ($already -match [regex]::Escape($cfg.serverFingerprint)) { Write-Ok 'fingerprint already trusted' }
    else {
        $out = Invoke-P4 $p4 $cfg.p4port $User @('trust', '-i', $cfg.serverFingerprint)
        # `trust -i` only records the value. Prove it with a real connection before believing it.
        $probe = Invoke-P4 $p4 $cfg.p4port $User @('info')
        if (("$probe" -match 'IDENTIFICATION HAS CHANGED') -or ("$probe" -notmatch 'Server (address|version)|User name')) {
            Invoke-P4 $p4 $cfg.p4port $User @('trust', '-d') | Out-Null    # remove the unverified entry
            Write-Bad 'The server presented a different certificate than connector.config.json expects (or is unreachable).'
            Write-Host '    Do NOT trust it. Confirm the fingerprint with your Helix admin and check the server address.'
            exit 1
        }
        Write-Ok "pinned and verified $($cfg.serverFingerprint)" 
    }
}

Write-Step "Writing workspace files in $Root"
New-Item -ItemType Directory -Force $Root | Out-Null
$vals = @{ P4PORT = $cfg.p4port; P4USER = $User; P4CLIENT = $Workspace; DEPOT_ROOT = $cfg.depotRoot
           P4MCP_BIN = ($mcp -replace '\\', '\\'); LOG_DIR = ((Join-Path $env:LOCALAPPDATA 'claude-helix\logs') -replace '\\', '\\') }
$files = @{ '.p4config' = 'p4config.template'; '.p4ignore' = 'p4ignore.template'; '.mcp.json' = 'mcp.json.template'; 'CLAUDE.md' = 'CLAUDE.md.template' }
foreach ($name in $files.Keys) {
    $target = Join-Path $Root $name
    if ((Test-Path $target) -and $name -in 'CLAUDE.md', '.mcp.json') { Write-Warn2 "$name exists - left unchanged"; continue }
    [IO.File]::WriteAllText($target, (Expand-Template (Join-Path $tpl $files[$name]) $vals))
    Write-Ok $name
}
Install-ClaudeGuard $Root

if ($SkipLogin) { Write-Warn2 'SkipLogin set: stopping before login.'; exit 0 }

Write-Step 'Signing in (Google SSO opens in your browser)'
Push-Location $Root
try {
    & $p4 login
    if ($LASTEXITCODE -ne 0) { Write-Bad 'Login failed. Use the Google account whose email is registered for your Perforce user.'; exit 1 }
    Write-Ok ((Invoke-P4 $p4 $cfg.p4port $User @('login', '-s')) -join ' ')
    Assert-NotAdminAccount $p4 $cfg.p4port $User $AllowAdminAccount.IsPresent
    $reg = ((Invoke-P4 $p4 $cfg.p4port $User @('user', '-o', $User)) | Where-Object { $_ -match '^Email:' }) -replace '^Email:\s*', ''
    if ($reg -and $reg.Trim() -ieq $GoogleEmail.Trim()) { Write-Ok "Google identity matches Perforce user email ($reg)" }
    else { Write-Warn2 "Perforce user email is '$reg' but you entered '$GoogleEmail'. Ask your admin to align them." }

    Write-Step "Creating workspace $Workspace"
    $exists = Invoke-P4 $p4 $cfg.p4port $User @('clients', '-e', $Workspace)
    if ($exists) { Write-Ok 'workspace already exists' }
    else {
        $view = ($cfg.lines | ForEach-Object { "`t$($cfg.depotRoot)/$_/... //$Workspace/$_/..." }) -join "`n"
        $spec = "Client: $Workspace`nOwner: $User`nDescription:`n`tClaude Code + Helix Core workspace`nRoot: $Root`nOptions: noallwrite noclobber nocompress unlocked nomodtime normdir`nSubmitOptions: submitunchanged`nLineEnd: local`nView:`n$view`n"
        (Invoke-P4Form $p4 $cfg.p4port $User $spec 'client -i') | ForEach-Object { Write-Host "    $_" }
    }
    if (-not $SkipSync) {
        Write-Step 'Syncing'
        $n = (Invoke-P4 $p4 $cfg.p4port $User @('-c', $Workspace, 'sync')).Count
        Write-Ok "$n file operations"
    }
} finally { Pop-Location }

Write-Host "`nDone. Open '$Root' in Claude Code, approve the 'perforce-p4-mcp' server, and try /helix-status." -ForegroundColor Green
