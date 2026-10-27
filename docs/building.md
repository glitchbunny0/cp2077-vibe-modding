# Building

The scripts here build the frameworks from reviewed source (`docs/reviews.md`) on the Windows
machine that runs the game. Windows is the build host because the upstream projects build there: CET's ASI loader is
a premake project that generates a Visual Studio solution, RED4ext's CMake sets MSVC-only flags,
and every project's CI runs on Windows with VS 2022.

## Toolchain

Installed and checked on 2026-10-27; `tools/windows/toolchain-smoke.ps1` builds a hello world with
each and prints one line per toolchain.

| Tool | Version | Source and check |
|---|---|---|
| VS 2022 Build Tools, VCTools workload + recommended | 17.14 (MSVC 19.44, Windows SDK, CMake 3.31.6, Ninja 1.12.1, MSBuild 17.14) | `aka.ms/vs/17/release/vs_buildtools.exe`, Authenticode signer Microsoft Corporation; `--quiet --wait --norestart --nocache` |
| xmake | 3.1.2 | winget `Xmake-io.Xmake` (installer hash verified by winget) |
| premake | 5.0.0 | `premake-core` release zip, sha256 matched the GitHub release digest |
| Rust | stable 1.99.1, `x86_64-pc-windows-msvc`, minimal profile | `rustup-init.exe` from static.rust-lang.org, sha256 matched its `.sha256` |

Inside a script, enter the VS developer shell with `Microsoft.VisualStudio.DevShell.dll`
(`Enter-VsDevShell -VsInstallPath <vswhere result> -DevCmdArguments '-arch=x64 -host_arch=x64'`).

## Per project

| Project | Build system | Notes |
|---|---|---|
| RED4ext | CMake >= 3.26 | Configure fetches its pinned dependencies (rows in `docs/reviews.md`). |
| CET | xmake >= 3.1 | `xmake build` only. Never `xmake package`: it downloads two `.kark` files unhashed. |
| CET's ASI loader (`asi-loader`) | premake 5 -> `vs2022` -> MSBuild | Use our premake 5.0.0, not the repo's committed `premake5.exe`. The x64 target is `version.dll`. |
| TweakXL, ArchiveXL, Codeware, RedHotTools | xmake | xmake-repo packages float: lock them on the first build. |
| RedSocket | xmake | Its `after_build` runs `red-cli` from PATH; disable it. |
| redscript | cargo | `--locked`. |
