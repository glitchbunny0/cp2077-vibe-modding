# Read-only probe of the game box after the game froze, crashed or quit: what ended the last session, and when.
#
#   crash-probe.ps1 -Game <game dir> [-Minutes 60]
#
# Reads the game's and the frameworks' own logs plus the Windows event logs for the last -Minutes; writes nothing.
# How to read the output: docs/crash-probing.md. Ends with a 'probe-ok' line, so an empty section is provably empty.
param(
    [Parameter(Mandatory)][string]$Game,
    [int]$Minutes = 60
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$since = (Get-Date).AddMinutes(-$Minutes)
$cet = Join-Path $Game 'bin\x64\plugins\cyber_engine_tweaks'
function Stamp($t) { $t.ToString('yyyy-MM-dd HH:mm:ss') }
function Tail($path, $n) { if (Test-Path $path) { Get-Content $path -Tail $n } else { "(no $path)" } }
function Newest($dir, $filter) {
    if (Test-Path $dir) { Get-ChildItem $dir -Filter $filter -File | Sort-Object LastWriteTime | Select-Object -Last 1 }
}

"== now $(Stamp (Get-Date)), window since $(Stamp $since), last boot $(Stamp (Get-CimInstance Win32_OperatingSystem).LastBootUpTime)"

'== game processes'
Get-Process | Where-Object { $_.ProcessName -match '^(Cyberpunk2077|REDprelauncher|REDEngineErrorReporter|WerFault)$' } |
    ForEach-Object { '{0} pid {1} started {2} responding {3}' -f $_.ProcessName, $_.Id, (Stamp $_.StartTime), $_.Responding }

'== the game''s post-mortem (CrashInfo.json; timeCrash is UTC; quest and location left out: spoilers)'
$ci = Join-Path $env:LOCALAPPDATA 'CD Projekt Red\Cyberpunk 2077\CrashInfo.json'
if (Test-Path $ci) {
    $pm = (Get-Content $ci -Raw | ConvertFrom-Json).Data.postMortem
    'written {0}: timeCrash {1}, patch {2}, session {3} s, isOom {4}' -f (Stamp (Get-Item $ci).LastWriteTime),
        $pm.timeCrash, $pm.crashPatch, [int][double]$pm.sessionLength, $pm.isOom
} else { '(none)' }

'== RED4ext: crash reports in the newest log'
$r4 = Newest (Join-Path $Game 'red4ext\logs') 'red4ext-*.log'
if ($r4) {
    "$($r4.Name) (last write $(Stamp $r4.LastWriteTime))"
    $in = $false
    foreach ($line in Get-Content $r4.FullName) {           # a report: header, dashes, File/Line/Condition/Message, dashes
        if ($line -match 'Crash report') { $in = $true; $dashes = 0 }
        if ($in) { $line; if ($line -match '\] -{6,}\s*$') { $dashes++; if ($dashes -eq 2) { $in = $false } } }
    }
} else { '(no RED4ext log)' }

'== hang clock: last writes of files the game rewrites while its main thread runs'
$beat = Join-Path $cet 'mods\VibeBridge\LuaRepl\bridge.json'
if (Test-Path $beat) { 'VibeBridge heartbeat (every 1 s from onUpdate): {0}' -f (Stamp (Get-Item $beat).LastWriteTime) }
Get-ChildItem (Join-Path $cet 'mods') -Recurse -File -Include *.log -ErrorAction SilentlyContinue |
    ForEach-Object { '{0}  {1}' -f (Stamp $_.LastWriteTime), $_.FullName.Substring($Game.Length + 1) }

'== RedHotTools: newest log tail'
$rht = Newest (Join-Path $Game 'red4ext\plugins\RedHotTools') 'RedHotTools-*.log'   # RedHotTools.log is a symlink PowerShell refuses
if ($rht) { Tail $rht.FullName 6 } else { '(no RedHotTools log)' }

'== CET: scripting.log tail'
Tail (Join-Path $cet 'scripting.log') 10

'== Windows System log: display driver, GPU, hardware, bugcheck, power loss, OS start/shutdown'
Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $since } -ErrorAction SilentlyContinue |
    Where-Object { ($_.ProviderName -match 'nvlddmkm|amdkmdag|Display|dxgkrnl|WHEA|BugCheck' -and $_.Id -ne 4125) -or   # 4125: Auto HDR notices
                   ($_.ProviderName -match 'Kernel-Power' -and $_.Id -eq 41) -or
                   ($_.ProviderName -match 'Kernel-General' -and $_.Id -in 12, 13) } |
    Select-Object -First 20 | ForEach-Object { '{0} {1} {2}: {3}' -f (Stamp $_.TimeCreated), $_.ProviderName, $_.Id, (($_.Message -split "`n")[0]).Trim() }

'== Windows Error Reporting: kernel/GPU events and game crashes whose EVENT happened in the window (Report.wer
   EventTime; the Application log only shows when a report was logged, and WER re-logs old queued reports in bursts)'
$(foreach ($d in 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue', 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive',
               "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue", "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive") {
    if (-not (Test-Path $d)) { continue }
    Get-ChildItem $d -Directory | ForEach-Object {
        $w = Join-Path $_.FullName 'Report.wer'
        if (-not (Test-Path $w)) { return }
        $kv = @{}
        Get-Content $w -Encoding Unicode | Where-Object { $_ -match '^(EventTime|EventType|AppName|Sig\[0\]\.Value)=' } |
            ForEach-Object { $k, $v = $_ -split '=', 2; $kv[$k] = $v }
        if (-not $kv.EventTime) { return }
        $when = [DateTime]::FromFileTime([int64]$kv.EventTime)
        $what = if ($kv.AppName) { $kv.AppName } else { $kv['Sig[0].Value'] }
        $relevant = $kv.EventType -match 'BlueScreen|LiveKernelEvent' -or "$what $($kv['Sig[0].Value'])" -match 'Cyberpunk|REDEngine'
        if ($when -gt $since -and $relevant) { '{0}  {1} {2}  {3}' -f (Stamp $when), $kv.EventType, $what, $_.Name }
    }
}) | Sort-Object

'== dump files written in the window (targeted folders only: a recursive search of LOCALAPPDATA outlasts ssh)'
$dirs = @((Join-Path $Game 'bin\x64'), (Join-Path $Game 'red4ext'), "$env:LOCALAPPDATA\CrashDumps", "$env:LOCALAPPDATA\REDEngine",
          "$env:LOCALAPPDATA\CD Projekt Red", 'C:\ProgramData\Microsoft\Windows\WER')
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { continue }
    Get-ChildItem $d -Recurse -Depth 3 -File -ErrorAction SilentlyContinue -Include *.dmp, *.mdmp, *.hdmp |
        Where-Object { $_.LastWriteTime -gt $since } |
        Select-Object -First 10 | ForEach-Object { '{0}  {1,10}  {2}' -f (Stamp $_.LastWriteTime), $_.Length, $_.FullName }
}
'probe-ok'
