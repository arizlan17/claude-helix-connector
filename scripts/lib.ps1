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
