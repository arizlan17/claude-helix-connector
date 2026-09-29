<#
.SYNOPSIS
  ADMIN: add a developer to Helix Core so they can sign in with Google and use Claude Code.

.DESCRIPTION
  Creates the Perforce user (Email = the person's Google account address, which SSO matches on),
  adds them to a group, and prints what to tell them. Idempotent: safe to re-run.
  Run as a Helix admin who is already logged in (`p4 login`). The script never handles passwords.

.EXAMPLE
  .\add-developer.ps1 -User jsmith -Email john.smith@mitrai.com -FullName "John Smith"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$User,
    [Parameter(Mandatory)][ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')][string]$Email,
    [Parameter(Mandatory)][string]$FullName,
    [string]$Group,
    [string]$AdminUser = $env:P4USER,
    [string]$P4Path
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$cfg = Get-ConnectorConfig
if (-not $Group) { $Group = $cfg.defaultGroup }
$p4 = Find-P4 $P4Path
if (-not $p4) { throw 'p4 not found (use -P4Path).' }
if (-not $AdminUser) { throw 'Pass -AdminUser (a Helix super user who is logged in).' }

Write-Step "Checking admin session for $AdminUser"
$s = Invoke-P4 $p4 $cfg.p4port $AdminUser @('login', '-s')
if ("$s" -notmatch 'ticket expires') { Write-Bad "Not logged in as $AdminUser. Run: p4 -u $AdminUser login"; exit 1 }
Write-Ok ($s -join ' ')

Write-Step "Email uniqueness"
$clash = Invoke-P4 $p4 $cfg.p4port $AdminUser @('users') | Where-Object { $_ -match "<$([regex]::Escape($Email))>" -and $_ -notmatch "^$([regex]::Escape($User)) " }
if ($clash) { Write-Bad "Email already used by: $clash"; exit 1 }
Write-Ok 'no clash'

Write-Step "Creating/updating user $User"
$spec = "User: $User`nEmail: $Email`nFullName: $FullName`n"
Invoke-P4Form $p4 $cfg.p4port $AdminUser $spec 'user -f -i' | ForEach-Object { Write-Host "    $_" }

Write-Step "Adding $User to group $Group"
$g = (Invoke-P4 $p4 $cfg.p4port $AdminUser @('group', '-o', $Group)) -join "`n"
if ($g -match "(?m)^\t$([regex]::Escape($User))\s*$") { Write-Ok 'already a member' }
else {
    $g = [regex]::Replace($g, '(?m)^Users:\s*$', "Users:`n`t$User")
    if ($g -notmatch "(?m)^\t$([regex]::Escape($User))\s*$") { $g = $g.TrimEnd() + "`nUsers:`n`t$User`n" }
    Invoke-P4Form $p4 $cfg.p4port $AdminUser ($g + "`n") 'group -i' | ForEach-Object { Write-Host "    $_" }
}

Write-Step 'Verify permissions (expect: write on features, read on main)'
$pm = Invoke-P4 $p4 $cfg.p4port $AdminUser @('protects', '-m', '-u', $User, "$($cfg.depotRoot)/main/x")
$pf = Invoke-P4 $p4 $cfg.p4port $AdminUser @('protects', '-m', '-u', $User, "$($cfg.depotRoot)/features/x")
Write-Host "    main    : $(($pm | Where-Object { $_ }) -join ' ')"; Write-Host "    features: $(($pf | Where-Object { $_ }) -join ' ')"

Write-Host @"

Send to $FullName :
  1. If Google is in Testing mode, an admin must add $Email as a Google 'Test user' (not needed for an Internal Workspace app).
  2. Run:  .\onboard.ps1 -User $User -Root <their workspace folder>
  3. In the browser, sign in with $Email (the Google account must match exactly).
"@ -ForegroundColor Green
