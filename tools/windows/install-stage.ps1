# Installs a staged build (a folder mirroring the game layout) into the game, or removes it again.
#
#   install-stage.ps1 -Stage <stage dir> -Game <game dir> -Record <record file>
#   install-stage.ps1 -Uninstall -Game <game dir> -Record <record file>
#
# The record lists every file written (with sha256), every directory created and every file that
# was overwritten (backed up beside the record), so -Uninstall restores the game folder exactly.
# Refuses while the game or its launcher is running, unless -AllowRunning (only for stages of
# CET Lua mods, which CET reads when mods are (re)loaded, never for DLLs or archives).
param(
    [string]$Stage,
    [Parameter(Mandatory)][string]$Game,
    [Parameter(Mandatory)][string]$Record,
    [switch]$Uninstall,
    [switch]$AllowRunning
)
$ErrorActionPreference = 'Stop'
if ($AllowRunning -and $Stage -and (Get-ChildItem -Recurse -File $Stage | Where-Object { $_.Extension -notin '.lua', '.json', '.md' })) {
    'REFUSED: -AllowRunning is only for Lua mod stages'; exit 1
}
if (-not $AllowRunning -and (Get-Process | Where-Object { $_.ProcessName -match '^(Cyberpunk2077|REDprelauncher)$' })) {
    'REFUSED: the game or its launcher is running'; exit 1
}
$Game = (Resolve-Path $Game).Path
$backup = "$Record.backup"

if ($Uninstall) {
    if (-not (Test-Path $Record)) { "REFUSED: no record at $Record"; exit 1 }
    $rec = Get-Content $Record -Raw | ConvertFrom-Json
    $removed = 0; $changed = @()
    foreach ($f in $rec.files) {
        $p = Join-Path $Game $f.path
        if (Test-Path $p) {
            if ((Get-FileHash $p -Algorithm SHA256).Hash.ToLower() -ne $f.sha256) { $changed += $f.path }
            Remove-Item -Force $p; $removed++
        }
    }
    foreach ($f in $rec.overwritten) { Copy-Item (Join-Path $backup $f) (Join-Path $Game $f) -Force }
    foreach ($d in ($rec.dirs | Sort-Object { $_.Length } -Descending)) {
        $p = Join-Path $Game $d
        if ((Test-Path $p) -and -not (Get-ChildItem -Force $p)) { Remove-Item -Force $p }
    }
    $left = @($rec.dirs | Where-Object { Test-Path (Join-Path $Game $_) })
    "removed $removed files, restored $(@($rec.overwritten).Count), dirs left (not empty): $($left -join ', ')"
    if ($changed) { "note: changed since install (removed anyway): $($changed -join ', ')" }
    Move-Item $Record "$Record.uninstalled-$(Get-Date -Format yyyyMMdd-HHmmss)"
    exit 0
}

if (-not $Stage -or -not (Test-Path $Stage)) { "REFUSED: no stage at $Stage"; exit 1 }
if (Test-Path $Record) { "REFUSED: $Record exists; uninstall first"; exit 1 }
$Stage = (Resolve-Path $Stage).Path
$files = @(); $dirs = @(); $overwritten = @()
foreach ($d in Get-ChildItem -Recurse -Directory $Stage) {
    $rel = $d.FullName.Substring($Stage.Length + 1)
    if (-not (Test-Path (Join-Path $Game $rel))) { $dirs += $rel }
}
foreach ($f in Get-ChildItem -Recurse -File $Stage) {
    $rel = $f.FullName.Substring($Stage.Length + 1)
    $dst = Join-Path $Game $rel
    if (Test-Path $dst) {
        New-Item -ItemType Directory -Force -Path (Split-Path (Join-Path $backup $rel)) | Out-Null
        Copy-Item $dst (Join-Path $backup $rel)
        $overwritten += $rel
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item $f.FullName $dst -Force
    $files += [pscustomobject]@{ path = $rel; sha256 = (Get-FileHash $dst -Algorithm SHA256).Hash.ToLower() }
}
[pscustomobject]@{ stage = $Stage; game = $Game; installed = (Get-Date -Format o); files = $files; dirs = $dirs; overwritten = $overwritten } |
    ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $Record
"installed $($files.Count) files, created $($dirs.Count) dirs, overwrote $($overwritten.Count)"
