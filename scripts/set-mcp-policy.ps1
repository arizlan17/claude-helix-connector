<#
.SYNOPSIS
  ADMIN: control what the P4 MCP server may do, from the Helix server (no change on developer PCs).

.DESCRIPTION
  Uses the server-side `mcp.*` properties documented by the P4 MCP server.
    Standard   : all allowed toolsets, reads and writes                (default for developers)
    ReadOnly   : query_* tools only; every modify_* tool is blocked
    Off        : MCP disabled
    Reset      : remove this group's/user's overrides (falls back to the global setting)
  Apply globally, or to one group (-Group) or user (-TargetUser). Use -Show to list current settings.

.EXAMPLE
  .\set-mcp-policy.ps1 -Mode ReadOnly -Group mds-interns
  .\set-mcp-policy.ps1 -Mode Off -TargetUser jsmith
  .\set-mcp-policy.ps1 -Show
#>
[CmdletBinding()]
param(
    [ValidateSet('Standard', 'ReadOnly', 'Off', 'Reset')][string]$Mode,
    [string]$Group,
    [string]$TargetUser,
    [string]$AllowedToolsets = 'server,changelists,files,shelves,workspaces,jobs',
    [switch]$Show,
    [string]$AdminUser = $env:P4USER,
    [string]$P4Path
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$cfg = Get-ConnectorConfig
$p4 = Find-P4 $P4Path
if (-not $p4) { throw 'p4 not found (use -P4Path).' }
if (-not $AdminUser) { throw 'Pass -AdminUser.' }

if ($Show -or -not $Mode) {
    Write-Step 'Current mcp.* properties'
    Invoke-P4 $p4 $cfg.p4port $AdminUser @('property', '-l', '-A') | Where-Object { $_ -match 'mcp\.' } | ForEach-Object { Write-Host "    $_" }
    return
}

$scope = @()
if ($Group)      { $scope = @('-g', $Group) }
elseif ($TargetUser) { $scope = @('-u', $TargetUser) }
$label = if ($Group) { "group $Group" } elseif ($TargetUser) { "user $TargetUser" } else { 'everyone' }

function Set-Prop([string]$name, [string]$value) {
    $out = Invoke-P4 $p4 $cfg.p4port $AdminUser (@('property', '-a', '-n', $name, '-v', $value) + $scope)
    Write-Host "    $name = $value  [$label]  $($out -join ' ')"
}

Write-Step "Applying $Mode policy for $label"
function Remove-Prop([string]$name) {
    $out = Invoke-P4 $p4 $cfg.p4port $AdminUser (@('property', '-d', '-n', $name) + $scope)
    Write-Host "    removed $name  [$label]  $($out -join ' ')"
}

switch ($Mode) {
    'Reset'    { if (-not $scope.Count) { throw 'Reset needs -Group or -TargetUser (refusing to wipe global policy).' }
                 Remove-Prop 'mcp.enabled'; Remove-Prop 'mcp.toolsets.write' }
    'Standard' {
        if (-not $Group -and -not $TargetUser) { Set-Prop 'mcp.toolsets.allowed' $AllowedToolsets }
        Set-Prop 'mcp.enabled' 'true'
        Set-Prop 'mcp.toolsets.write' 'true'
    }
    'ReadOnly' { Set-Prop 'mcp.enabled' 'true'; Set-Prop 'mcp.toolsets.write' 'false' }
    'Off'      { Set-Prop 'mcp.enabled' 'false' }
}
Write-Host "`nNote: at equal priority, a user setting beats a group setting, which beats the global one." -ForegroundColor Yellow
