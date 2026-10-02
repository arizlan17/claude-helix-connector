# PreToolUse hook for the Bash and PowerShell tools. Blocks p4 commands that could change or delete the
# Helix server's rules and permissions (protections, groups, users, properties, depots, triggers, ...).
# Reading them is allowed. Exit code 2 = block, with the reason on stderr. Any parse problem fails open
# (the server's own permissions are still the real enforcement; this hook is an extra layer).
$ErrorActionPreference = 'Stop'
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$in.tool_input.command
if (-not $cmd) { exit 0 }

# p4 commands with an edit form: only the read form (-o) is allowed; -i / -d (write / delete) are blocked.
$formCmds = 'protect', 'group', 'user', 'depot', 'triggers', 'typemap', 'server', 'serverid', 'spec', 'remote', 'ldap', 'repo', 'stream'
# Never allowed from Claude.
$blocked = 'admin', 'obliterate', 'passwd', 'license', 'unload', 'reload', 'archive', 'restore', 'renameuser',
           'grant-permission', 'revoke-permission', 'extension', 'counter', 'key', 'monitor'
# Global p4 options that take a separate value.
$valued = 'c', 'C', 'd', 'H', 'L', 'p', 'P', 'r', 'u', 'v', 'x', 'Q', 'E'
# Words that put the next token in command position (so "Start-Process p4d" is a command, "Get-Process p4d" is not).
$launchers = '&', '.', 'start-process', 'start', 'call', 'sudo', 'exec', 'nohup', 'time', 'command', 'invoke-expression', 'iex'

function Get-Tokens([string]$s) {
    [regex]::Matches($s, '"[^"]*"|''[^'']*''|\S+') | ForEach-Object { $_.Value.Trim('"', "'") }
}
function Get-Leaf([string]$t) { ($t -split '[\\/]')[-1] -replace '\.exe$', '' }

function Find-Violation([string]$text, [int]$depth) {
    if ($depth -gt 3) { return $null }
    foreach ($seg in ($text -split '\|\||&&|;|\||\r?\n')) {
        $tok = @(Get-Tokens $seg)
        for ($i = 0; $i -lt $tok.Count; $i++) {
            $leaf = Get-Leaf $tok[$i]
            $isP4 = $leaf -ieq 'p4'
            $atStart = ($i -eq 0) -or ($launchers -contains $tok[$i - 1].ToLower())
            if ($leaf -ieq 'p4d' -and $atStart) { return 'p4d (server administration) is not allowed' }
            # a quoted path with spaces, such as "C:\Program Files\Perforce\p4.exe", is still the p4 program
            if ($tok[$i] -match '\s' -and -not $isP4) {
                # only look inside a quoted string when it is handed to a shell (powershell -Command "...", bash -c '...', cmd /c "...")
                $prev = if ($i -gt 0) { $tok[$i - 1].ToLower() } else { '' }
                if ($prev -in '-command', '-c', '-lc', '-ic', '/c', '/k', '-encodedcommand' -or $launchers -contains $prev) {
                    $r = Find-Violation $tok[$i] ($depth + 1); if ($r) { return $r }
                }
                continue
            }
            if (-not $isP4) { continue }
            # skip global options to reach the subcommand
            $j = $i + 1
            while ($j -lt $tok.Count -and $tok[$j].StartsWith('-')) {
                if ($tok[$j].Length -eq 2 -and $valued -ccontains $tok[$j].Substring(1)) { $j += 2 } else { $j++ }
            }
            if ($j -ge $tok.Count) { continue }
            $sub = $tok[$j].ToLower()
            $rest = @($tok[($j + 1)..($tok.Count - 1)] | Where-Object { $_ })
            if ($sub -in $blocked) { return "p4 $sub can change server rules or data" }
            if ($sub -eq 'login' -and -not ($rest -contains '-s')) { return 'p4 login is done by the user, not Claude' }
            if ($sub -eq 'property' -and -not ($rest -contains '-l')) { return 'p4 property can only be listed (-l)' }
            if ($sub -eq 'configure' -and $rest[0] -notin 'show', 'help') { return 'p4 configure can only use show/help' }
            if ($sub -in $formCmds) {
                $write = $rest | Where-Object { $_ -match '^-[A-Za-z]*[id][A-Za-z]*$' }
                $read = $rest | Where-Object { $_ -match '^-[A-Za-z]*o[A-Za-z]*$' }
                if ($write -or -not $read) { return "p4 $sub can only be read (-o), not changed or deleted" }
            }
        }
    }
    return $null
}

$why = Find-Violation $cmd 0
if ($why) {
    [Console]::Error.WriteLine("Blocked by helix-connector: $why. Claude may read Helix rules and permissions but never edit or delete them. Ask your Helix admin.")
    exit 2
}
exit 0
