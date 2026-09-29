<#
.SYNOPSIS
  Health check for a developer machine: prints what works and what to fix. Changes nothing.
.EXAMPLE
  .\check.ps1 -Root D:\work\mds
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Root, [string]$P4Path)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
$cfg = Get-ConnectorConfig
$fail = 0
function Check([string]$name, [bool]$ok, [string]$fix) {
    if ($ok) { Write-Ok $name } else { Write-Bad "$name  -> $fix"; $script:fail++ }
}

Write-Step 'Tools'
$p4 = Find-P4 $P4Path
Check 'p4 CLI found' ([bool]$p4) 'install the P4 CLI or pass -P4Path'
$mcp = Find-P4Mcp
Check 'P4 MCP server found' ([bool]$mcp) 'run onboard.ps1 -InstallMcp'

Write-Step 'Workspace files'
foreach ($f in '.p4config', '.mcp.json', 'CLAUDE.md', '.p4ignore') { Check $f (Test-Path (Join-Path $Root $f)) 'run onboard.ps1' }
if (-not $p4) { exit 1 }

$conf = @{}
if (Test-Path (Join-Path $Root '.p4config')) {
    Get-Content (Join-Path $Root '.p4config') | Where-Object { $_ -match '^\w+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $conf[$k] = $v }
}
Check '.p4config has P4PORT/P4USER/P4CLIENT' ($conf.P4PORT -and $conf.P4USER -and $conf.P4CLIENT) 'run onboard.ps1'
Check '.p4config has no password' ((Get-Content (Join-Path $Root '.p4config') -Raw -ErrorAction SilentlyContinue) -notmatch 'P4PASSWD') 'remove P4PASSWD; use p4 login'

Write-Step 'Server'
Push-Location $Root
try {
    $info = Invoke-P4 $p4 $conf.P4PORT $conf.P4USER @('info')
    Check 'server reachable' ("$info" -match 'Server address|Server version') "cannot reach $($conf.P4PORT): check VPN/hostname"
    $t = Invoke-P4 $p4 $conf.P4PORT $conf.P4USER @('login', '-s')
    Check 'signed in (ticket valid)' ("$t" -match 'ticket expires') 'run: p4 login'
    if ("$t" -match 'ticket expires') { Write-Host "    $($t -join ' ')" }
    $c = Invoke-P4 $p4 $conf.P4PORT $conf.P4USER @('clients', '-e', $conf.P4CLIENT)
    Check "workspace $($conf.P4CLIENT) exists" ("$c" -match '^Client ') 'run onboard.ps1'
    $h = Invoke-P4 $p4 $conf.P4PORT $conf.P4USER @('-c', $conf.P4CLIENT, 'have', '//...')
    Check 'files synced' ("$h" -match '#\d+ - ') 'run: p4 sync'
} finally { Pop-Location }

if ($fail -eq 0) { Write-Host "`nAll checks passed." -ForegroundColor Green } else { Write-Host "`n$fail check(s) need attention." -ForegroundColor Yellow; exit 1 }
