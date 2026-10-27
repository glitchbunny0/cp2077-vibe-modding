# Builds a C++20 hello world with every toolchain this project's sources need (cl, CMake+Ninja,
# xmake, premake+MSBuild) plus a Rust hello world, and prints one line per toolchain.
# Override tool locations with $env:PREMAKE and $env:CARGO. Writes only under $env:USERPROFILE\cp77-build\smoke.
$ErrorActionPreference = 'Continue'
$root = Join-Path $env:USERPROFILE 'cp77-build\smoke'
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory -Path $root | Out-Null
Set-Location $root
$out = @()
function Check($label, $log) {
    if ($LASTEXITCODE -ne 0) {
        $script:out += "FAIL $label (exit $LASTEXITCODE)"
        if ($log -and (Test-Path $log)) { $script:out += (Get-Content $log -Tail 12) }
        return $false
    }
    return $true
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vs) { 'VS 2022 with the x64 C++ tools not found'; return }
$out += "vs2022: $vs"
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
Set-Location $root
$out += "cl: " + ((cmd /c 'cl 2>&1' | Select-Object -First 1) -join '')
$out += "cmake: " + ((& cmake --version | Select-Object -First 1) -join '')
$out += "ninja: " + ((& ninja --version) -join '')
$out += "msbuild: " + ((& msbuild -version -nologo | Select-Object -Last 1) -join '')

# 1. cl, C++20
'#include <format>
#include <cstdio>
int main() { std::puts(std::format("cl c++20 ok {}", 42).c_str()); }' | Set-Content hello.cpp
cmd /c 'cl /nologo /std:c++20 /EHsc hello.cpp > cl.log 2>&1'
if (Check 'cl' 'cl.log') { $out += (& .\hello.exe) }

# 2. cmake + ninja
New-Item -ItemType Directory cm | Out-Null
'cmake_minimum_required(VERSION 3.26)
project(hello CXX)
set(CMAKE_CXX_STANDARD 20)
add_executable(hello ../hello.cpp)' | Set-Content cm\CMakeLists.txt
cmd /c 'cmake -S cm -B cm\build -G Ninja -DCMAKE_BUILD_TYPE=Release > cm\configure.log 2>&1'
if (Check 'cmake configure' 'cm\configure.log') {
    cmd /c 'cmake --build cm\build > cm\build.log 2>&1'
    if (Check 'cmake build' 'cm\build.log') { $out += "cmake+ninja: " + (& .\cm\build\hello.exe) }
}

# 3. xmake (no packages, so nothing is downloaded)
New-Item -ItemType Directory xm | Out-Null
'set_xmakever("3.1")
set_languages("cxx20")
set_arch("x64")
target("hello")
    set_kind("binary")
    add_files("../hello.cpp")' | Set-Content xm\xmake.lua
Push-Location xm
cmd /c 'xmake f -y -p windows -a x64 -m release --vs=2022 > configure.log 2>&1'
if (Check 'xmake configure' 'configure.log') {
    cmd /c 'xmake -y > build.log 2>&1'
    if (Check 'xmake build' 'build.log') {
        $exe = Get-ChildItem -Recurse -Filter hello.exe build | Select-Object -First 1
        $out += "xmake " + ((& xmake --version | Select-Object -First 1) -join '') + ": " + (& $exe.FullName)
    }
}
Pop-Location

# 4. premake -> vs2022 solution -> msbuild
New-Item -ItemType Directory pm | Out-Null
'workspace "hello"
   configurations { "Release" }
   architecture "x86_64"
   location "build"
project "hello"
   kind "ConsoleApp"
   language "C++"
   cppdialect "C++20"
   files { "../hello.cpp" }' | Set-Content pm\premake5.lua
Push-Location pm
$premake = if ($env:PREMAKE) { $env:PREMAKE } else { Join-Path $env:USERPROFILE 'tools\premake\premake5.exe' }
cmd /c "`"$premake`" vs2022 > premake.log 2>&1"
if (Check 'premake' 'premake.log') {
    cmd /c 'msbuild build\hello.sln /p:Configuration=Release /p:Platform=x64 /nologo /verbosity:minimal > msbuild.log 2>&1'
    if (Check 'msbuild' 'msbuild.log') {
        $exe = Get-ChildItem -Recurse -Filter hello.exe . | Select-Object -First 1
        $out += "premake+msbuild: " + (& $exe.FullName)
    }
}
Pop-Location

# 5. cargo (no dependencies, offline)
$cargo = if ($env:CARGO) { $env:CARGO } else { Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe' }
cmd /c "`"$cargo`" new --quiet --vcs none rs > cargo-new.log 2>&1"
Push-Location rs
cmd /c "`"$cargo`" build --release --offline > build.log 2>&1"
if (Check 'cargo build' 'build.log') { $out += "cargo: " + (& .\target\release\rs.exe) }
Pop-Location

$out -join "`n"
