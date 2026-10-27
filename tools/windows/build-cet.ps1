# Builds CET and its ASI loader from pinned, reviewed commits and stages them in the game's
# folder layout. Nothing is installed; tools/windows/install-stage.ps1 does that.
#
#   build-cet.ps1 -UalCommit <sha> -CetCommit <sha> -CetTag <tag> -KarkDir <dir with usedhashes.kark, tweakdbstr.kark>
#
# Commits and CET's tag come from refs.lock.json (`asi-loader`, `cet`). Writes only under -Work.
param(
    [Parameter(Mandatory)][string]$UalCommit,
    [Parameter(Mandatory)][string]$CetCommit,
    [Parameter(Mandatory)][string]$CetTag,
    [Parameter(Mandatory)][string]$KarkDir,
    [string]$Work = (Join-Path $env:USERPROFILE 'cp77-build'),
    [string]$Premake = (Join-Path $env:USERPROFILE 'tools\premake\premake5.exe')
)
$ErrorActionPreference = 'Continue'
$KarkDir = (Resolve-Path $KarkDir).Path
$src = Join-Path $Work 'src'
$logs = Join-Path $Work 'logs'
$stage = Join-Path $Work 'stage\cet'
New-Item -ItemType Directory -Force -Path $src, $logs | Out-Null

function Fail($msg, $log) {
    "FAIL: $msg"
    if ($log -and (Test-Path $log)) { Get-Content $log -Tail 25 }
    exit 1
}

function Get-Pinned($url, $commit, $dest, $tag) {
    if ((Test-Path (Join-Path $dest '.git')) -and ((cmd /c "git -C `"$dest`" rev-parse HEAD 2>nul") -eq $commit)) {
        "$dest already at $($commit.Substring(0,10))"
    } else {
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        New-Item -ItemType Directory -Path $dest | Out-Null
        $log = Join-Path $logs ("fetch-" + (Split-Path $dest -Leaf) + ".log")
        cmd /c "git -C `"$dest`" init -q && git -C `"$dest`" remote add origin $url && git -C `"$dest`" fetch -q --depth 1 --no-tags origin $commit && git -C `"$dest`" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD > `"$log`" 2>&1"
        if ($LASTEXITCODE -ne 0) { Fail "fetch $url@$commit" $log }
    }
    if ($tag) {
        # Some builds read their version from `git describe` (CET's on_load), so bring the release tag along.
        $log = Join-Path $logs ("tag-" + (Split-Path $dest -Leaf) + ".log")
        cmd /c "git -C `"$dest`" fetch -q --depth 1 origin refs/tags/${tag}:refs/tags/${tag} > `"$log`" 2>&1"
        if ($LASTEXITCODE -ne 0) { Fail "fetch tag $tag" $log }
        $tagged = cmd /c "git -C `"$dest`" rev-parse ${tag}^^{commit}"
        if ($tagged -ne $commit) { Fail "tag $tag is $tagged, expected $commit" }
    }
    $log = Join-Path $logs ("submodules-" + (Split-Path $dest -Leaf) + ".log")
    cmd /c "git -C `"$dest`" -c url.https://github.com/.insteadOf=git@github.com: -c protocol.file.allow=never submodule update --init --recursive --depth 1 > `"$log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Fail "submodules of $url" $log }
    $head = cmd /c "git -C `"$dest`" rev-parse HEAD"
    if ($head -ne $commit) { Fail "$dest is at $head, expected $commit" }
    "fetched $(Split-Path $dest -Leaf) @ $($commit.Substring(0,10))"
}

# Developer shell for MSVC, MSBuild, CMake.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vs) { Fail 'VS 2022 with x64 C++ tools not found' }
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null

# 1. CET's ASI loader -> version.dll
$ual = Join-Path $src 'asi-loader'
Get-Pinned 'https://github.com/maximegmd/Ultimate-ASI-Loader' $UalCommit $ual
Push-Location $ual
cmd /c "`"$Premake`" vs2022 > `"$logs\ual-premake.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'premake' "$logs\ual-premake.log" }
cmd /c "msbuild build\Ultimate-ASI-Loader-x64.sln /t:Ultimate-ASI-Loader-x64 /p:Configuration=Release /p:Platform=x64 /m /nologo /verbosity:minimal > `"$logs\ual-msbuild.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'msbuild Ultimate-ASI-Loader-x64' "$logs\ual-msbuild.log" }
$versionDll = Join-Path $ual 'bin\x64\Release\version.dll'
if (-not (Test-Path $versionDll)) { Fail "no $versionDll" }
Pop-Location
"built version.dll"

# 2. CET -> cyber_engine_tweaks.asi
$cet = Join-Path $src 'cet'
Get-Pinned 'https://github.com/maximegmd/CyberEngineTweaks' $CetCommit $cet $CetTag
Push-Location $cet
cmd /c "xmake f -y -p windows -a x64 -m release --vs=2022 --policies=package.requires_lock > `"$logs\cet-configure.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'xmake configure (CET)' "$logs\cet-configure.log" }
cmd /c "xmake build -y cyber_engine_tweaks > `"$logs\cet-build.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'xmake build (CET)' "$logs\cet-build.log" }
$asi = Get-ChildItem -Recurse -Filter 'cyber_engine_tweaks.asi' (Join-Path $cet 'build') | Select-Object -First 1
if (-not $asi) { Fail 'no cyber_engine_tweaks.asi' }
Pop-Location
"built $($asi.Name)"

# 3. Stage in game layout (what CET's `xmake package` would assemble, minus its unhashed downloads)
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
$x64 = Join-Path $stage 'bin\x64'
$cetDir = Join-Path $x64 'plugins\cyber_engine_tweaks'
New-Item -ItemType Directory -Force -Path (Join-Path $cetDir 'tweakdb') | Out-Null
Copy-Item $versionDll $x64
Copy-Item (Join-Path $cet 'vendor\asiloader\global.ini') $x64
Copy-Item $asi.FullName (Join-Path $x64 'plugins')
Copy-Item -Recurse (Join-Path $cet 'scripts') (Join-Path $cetDir 'scripts')
Copy-Item -Recurse (Join-Path $cet 'fonts') (Join-Path $cetDir 'fonts')
Copy-Item (Join-Path $cet 'ThirdParty_LICENSES') $cetDir
Copy-Item (Join-Path $KarkDir 'usedhashes.kark'), (Join-Path $KarkDir 'tweakdbstr.kark') (Join-Path $cetDir 'tweakdb')
$lock = Join-Path $cet 'xmake-requires.lock'
if (Test-Path $lock) { Copy-Item $lock (Join-Path $Work 'cet-xmake-requires.lock') }

$manifest = Get-ChildItem -Recurse -File $stage | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.FullName.Substring($stage.Length + 1)
}
$manifest | Set-Content -Encoding UTF8 (Join-Path $Work 'stage-cet.sha256')
"staged $($manifest.Count) files in $stage"
$manifest | Where-Object { $_ -match 'version\.dll|\.asi|global\.ini|\.kark' }
