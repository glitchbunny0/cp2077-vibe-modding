# Builds RED4ext and an archives-only RedHotTools for patch 2.5 from pinned, reviewed commits and stages
# them in the game's folder layout. Nothing is installed; tools/windows/install-stage.ps1 does that.
#
#   build-red4ext-rht.ps1 -Red4extCommit <sha> -Red4extTag <tag> -RhtCommit <sha> -SdkCommit <sha> -RhtPatch <file>
#
# Commits come from refs.lock.json (`red4ext`, `red-hot-tools`, `red4ext-sdk`). RedHotTools' own SDK
# submodule predates 2.5 (its ArchiveScope::Mod is 4, 2.5's is 6), so the SDK is checked out at -SdkCommit
# instead, and -RhtPatch (patches/red-hot-tools/) ports the archive hot reload and leaves the rest out.
# Runs at idle CPU priority (children inherit it) so a running game keeps the CPU. Writes only under -Work.
param(
    [Parameter(Mandatory)][string]$Red4extCommit,
    [Parameter(Mandatory)][string]$Red4extTag,
    [Parameter(Mandatory)][string]$RhtCommit,
    [Parameter(Mandatory)][string]$SdkCommit,
    [Parameter(Mandatory)][string]$RhtPatch,
    [string]$Work = (Join-Path $env:USERPROFILE 'cp77-build'),
    [switch]$ReuseRed4ext   # keep an earlier RED4ext build of the same commit (its configure alone takes minutes)
)
$ErrorActionPreference = 'Continue'
(Get-Process -Id $PID).PriorityClass = 'Idle'
$RhtPatch = (Resolve-Path $RhtPatch).Path
$src = Join-Path $Work 'src'
$logs = Join-Path $Work 'logs'
$stage = Join-Path $Work 'stage\red4ext-rht'
New-Item -ItemType Directory -Force -Path $src, $logs | Out-Null

function Fail($msg, $log) {
    "FAIL: $msg"
    if ($log -and (Test-Path $log)) { Get-Content $log -Tail 40 }
    exit 1
}

# Fresh shallow checkout of one commit (LF line endings, so the patch applies), plus an optional release tag
# (RED4ext reads its version from git tags) and https submodules.
function Get-Fresh($url, $commit, $dest, $tag) {
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Path $dest | Out-Null
    $name = Split-Path $dest -Leaf
    $log = Join-Path $logs "fetch-$name.log"
    cmd /c "git -C `"$dest`" init -q && git -C `"$dest`" config core.autocrlf false && git -C `"$dest`" remote add origin $url && git -C `"$dest`" fetch -q --depth 1 --no-tags origin $commit && git -C `"$dest`" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD > `"$log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail "fetch $url@$commit" $log }
    if ($tag) {
        cmd /c "git -C `"$dest`" fetch -q --depth 1 origin refs/tags/${tag}:refs/tags/${tag} >> `"$log`" 2>&1"
        if ($LASTEXITCODE -ne 0) { Fail "fetch tag $tag" $log }
        $tagged = cmd /c "git -C `"$dest`" rev-parse ${tag}^^{commit}"
        if ($tagged -ne $commit) { Fail "tag $tag is $tagged, expected $commit" }
    }
    $log = Join-Path $logs "submodules-$name.log"
    cmd /c "git -C `"$dest`" -c core.autocrlf=false -c url.https://github.com/.insteadOf=git@github.com: -c protocol.file.allow=never submodule update --init --recursive --depth 1 > `"$log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail "submodules of $url" $log }
    $head = cmd /c "git -C `"$dest`" rev-parse HEAD"
    if ($head -ne $commit) { Fail "$dest is at $head, expected $commit" }
    "fetched $name @ $($commit.Substring(0,10))"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vs) { Fail 'VS 2022 with x64 C++ tools not found' }
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null

# 1. RED4ext (CMake; configure fetches its pinned dependencies, rows in docs/reviews.md)
$r4 = Join-Path $src 'red4ext'
$r4build = Join-Path $r4 'build'
$r4inst = Join-Path $r4 'install'
$reuse = $ReuseRed4ext -and (Test-Path (Join-Path $r4inst 'red4ext\RED4ext.dll')) -and
    ((cmd /c "git -C `"$r4`" rev-parse HEAD 2>nul") -eq $Red4extCommit)
if ($reuse) {
    "reusing RED4ext @ $($Red4extCommit.Substring(0,10))"
} else {
    Get-Fresh 'https://github.com/wopss/RED4ext' $Red4extCommit $r4 $Red4extTag
    cmd /c "cmake -S `"$r4`" -B `"$r4build`" -G `"Visual Studio 17 2022`" -A x64 -DRED4EXT_GIT_METADATA=OFF > `"$logs\red4ext-configure.log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail 'cmake configure (RED4ext)' "$logs\red4ext-configure.log" }
    cmd /c "cmake --build `"$r4build`" --config Release -- /m /nologo /verbosity:minimal > `"$logs\red4ext-build.log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail 'cmake build (RED4ext)' "$logs\red4ext-build.log" }
    cmd /c "cmake --install `"$r4build`" --prefix `"$r4inst`" --config Release > `"$logs\red4ext-install.log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail 'cmake install (RED4ext)' "$logs\red4ext-install.log" }
    "built RED4ext"
}

# 2. RedHotTools at the pinned commit, SDK at 2.5, our patch on top (xmake)
$rht = Join-Path $src 'red-hot-tools'
Get-Fresh 'https://github.com/psiberx/cp2077-red-hot-tools' $RhtCommit $rht
$sdk = Join-Path $rht 'vendor\RED4ext.SDK'
$log = Join-Path $logs 'rht-sdk.log'
cmd /c "git -C `"$sdk`" fetch -q --depth 1 https://github.com/wopss/RED4ext.SDK $SdkCommit && git -C `"$sdk`" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD > `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail "SDK $SdkCommit" $log }
if ((cmd /c "git -C `"$sdk`" rev-parse HEAD") -ne $SdkCommit) { Fail "SDK is not at $SdkCommit" }
$log = Join-Path $logs 'rht-patch.log'
cmd /c "git -C `"$rht`" apply --whitespace=nowarn `"$RhtPatch`" > `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'apply RedHotTools patch' $log }
"patched red-hot-tools, SDK @ $($SdkCommit.Substring(0,10))"
Push-Location $rht
# Packages are built from their source archives (precompiled:n): xmake-repo otherwise pulls prebuilt binaries
# from its build-artifacts mirror.
cmd /c "xmake f -y -p windows -a x64 -m release --vs=2022 --policies=package.requires_lock,package.precompiled:n > `"$logs\rht-configure.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail 'xmake configure (RedHotTools)' "$logs\rht-configure.log" }
cmd /c "xmake build -y RedHotTools > `"$logs\rht-build.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail 'xmake build (RedHotTools)' "$logs\rht-build.log" }
$dll = Get-ChildItem -Recurse -Filter 'RedHotTools.dll' (Join-Path $rht 'build') | Select-Object -First 1
if (-not $dll) { Pop-Location; Fail 'no RedHotTools.dll' }
$lock = Join-Path $rht 'xmake-requires.lock'
if (Test-Path $lock) { Copy-Item $lock (Join-Path $Work 'rht-xmake-requires.lock') }
Pop-Location
"built $($dll.Name)"

# 3. Stage in game layout: RED4ext's install tree without debug symbols, the plugin in its own folder
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Get-ChildItem -Recurse -File $r4inst | Where-Object { $_.Extension -in '.dll', '.txt' } | ForEach-Object {
    $rel = $_.FullName.Substring($r4inst.Length + 1)
    New-Item -ItemType Directory -Force -Path (Split-Path (Join-Path $stage $rel)) | Out-Null
    Copy-Item $_.FullName (Join-Path $stage $rel)
}
$plugin = Join-Path $stage 'red4ext\plugins\RedHotTools'
New-Item -ItemType Directory -Force -Path $plugin | Out-Null
Copy-Item $dll.FullName $plugin
Copy-Item (Join-Path $rht 'LICENSE') (Join-Path $plugin 'LICENSE.txt')

$manifest = Get-ChildItem -Recurse -File $stage | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.FullName.Substring($stage.Length + 1)
}
$manifest | Set-Content -Encoding UTF8 (Join-Path $Work 'stage-red4ext-rht.sha256')
"staged $($manifest.Count) files in $stage"
$manifest
