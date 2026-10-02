# Shared helpers for the Claude + Helix connector kit. Dot-source: . "$PSScriptRoot\lib.ps1"
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

$script:KitRoot = Split-Path -Parent $PSScriptRoot

function Get-ConnectorConfig {
    $path = Join-Path $script:KitRoot 'connector.config.json'
    if (-not (Test-Path $path)) { throw "Missing $path" }
    Get-Content $path -Raw | ConvertFrom-Json
}

# Locate the p4 CLI: explicit path, PATH, or common install locations. Never downloads anything.
function Find-P4([string]$Hint) {
    $cands = @($Hint, (Get-Command p4 -ErrorAction SilentlyContinue).Source,
               'C:\Program Files\Perforce\p4.exe', "$env:LOCALAPPDATA\claude-helix\bin\p4.exe") | Where-Object { $_ }
    foreach ($c in $cands) { if (Test-Path $c) { return (Resolve-Path $c).Path } }
    return $null
}

# Locate the P4 MCP server executable (P4MCP_BIN, PATH, or the kit's per-user folder).
function Find-P4Mcp {
    $cands = @($env:P4MCP_BIN, (Get-Command p4-mcp-server -ErrorAction SilentlyContinue).Source) | Where-Object { $_ }
    $dir = Join-Path $env:LOCALAPPDATA 'claude-helix\p4mcp'
    if (Test-Path $dir) { $cands += (Get-ChildItem $dir -Recurse -Filter p4-mcp-server.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName) }
    foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
    return $null
}

# Send a Perforce form (or answers) to `p4 <cmd>` over stdin using exact bytes.
# PowerShell pipes add a BOM/CRLF that break p4 forms, so use a temp file and cmd redirection.
function Invoke-P4Form([string]$P4, [string]$Port, [string]$User, [string]$Text, [string]$Cmd) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, $Text)
        $line = '"{0}" -p {1} -u {2} {3} < "{4}"' -f $P4, $Port, $User, $Cmd, $tmp
        cmd /c $line 2>&1
    } finally { [IO.File]::Delete($tmp) }
}

# Run p4 quietly and return output lines. Errors on stderr are captured, not thrown.
function Invoke-P4([string]$P4, [string]$Port, [string]$User, [string[]]$P4Args) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $P4 -p $Port -u $User @P4Args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
}

# TCP-level reachability check for the Helix Authentication Service (avoids TLS trust prompts on its cert).
function Test-HelixAuthService([string]$Url) {
    try {
        $u = [Uri]$Url
        $c = New-Object Net.Sockets.TcpClient
        $iar = $c.BeginConnect($u.Host, $u.Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(3000) -and $c.Connected
        $c.Close()
        return [bool]$ok
    } catch { return $false }
}

# Highest permission this user has anywhere in the depot (list/read/open/write/review/owner/admin/super), or $null.
function Get-P4AccessLevel([string]$P4, [string]$Port, [string]$User) {
    $out = Invoke-P4 $P4 $Port $User @('protects', '-m', '-u', $User, '//...')
    $w = ("$out".Trim() -split '\s+')[0]
    if ($w -match '^(list|read|open|write|review|owner|admin|super)$') { return $w.ToLower() }
    return $null
}

# Claude acts as the signed-in user, so an account with admin/super could change server rules.
# Refuse unless the user explicitly accepts it.
function Assert-NotAdminAccount([string]$P4, [string]$Port, [string]$User, [bool]$Allow) {
    $lvl = Get-P4AccessLevel $P4 $Port $User
    if ($lvl -in 'admin', 'super') {
        if (-not $Allow) {
            Write-Bad "User '$User' has $lvl rights on the server. Claude acts as this user and could change permissions and rules."
            Write-Host '    Use a normal (non-admin) Perforce account for Claude, or re-run with -AllowAdminAccount to accept the risk.'
            exit 1
        }
        Write-Warn2 "Continuing with an $lvl account because -AllowAdminAccount was set. The p4-guard hook still blocks rule changes, but the server will not."
    } elseif ($lvl) { Write-Ok "server access level: $lvl (cannot change rules or permissions)" }
    else { Write-Warn2 'Could not determine your access level.' }
}

# Put the p4 guard hook and deny rules into the workspace so rule/permission edits are blocked even without the plugin.
function Install-ClaudeGuard([string]$Root) {
    $hookSrc = Join-Path $script:KitRoot 'plugins\helix-connector\hooks\p4-guard.ps1'
    $hookDir = Join-Path $Root '.claude\hooks'
    New-Item -ItemType Directory -Force $hookDir | Out-Null
    Copy-Item $hookSrc (Join-Path $hookDir 'p4-guard.ps1') -Force
    Write-Ok '.claude/hooks/p4-guard.ps1'
    $settings = Join-Path $Root '.claude\settings.json'
    if (Test-Path $settings) { Write-Warn2 '.claude/settings.json exists - left unchanged. Run /helix-init to merge the guard rules.' }
    else { Copy-Item (Join-Path $script:KitRoot 'templates\claude-settings.json.template') $settings; Write-Ok '.claude/settings.json' }
}

function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "    OK  $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text){ Write-Host "    !!  $Text" -ForegroundColor Yellow }
function Write-Bad([string]$Text)  { Write-Host "    XX  $Text" -ForegroundColor Red }

# Render a template file, replacing {{Key}} tokens.
function Expand-Template([string]$Path, [hashtable]$Values) {
    $t = Get-Content $Path -Raw
    foreach ($k in $Values.Keys) { $t = $t.Replace("{{$k}}", [string]$Values[$k]) }
    $t
}
