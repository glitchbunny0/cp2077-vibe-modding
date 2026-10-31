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
| CET's ASI loader (`asi-loader`) | premake 5 -> `vs2022` -> MSBuild | Use our premake 5.0.0, not the repo's committed `premake5.exe`. Build only the `Ultimate-ASI-Loader-x64` project (the workspace also builds four demo `.asi` plugins); its Release output is `bin/x64/Release/version.dll`. Ship CET's `global.ini` with it. |
| TweakXL, ArchiveXL, Codeware, RedHotTools | xmake | xmake-repo packages float: lock them on the first build. Configure with `--policies=package.requires_lock,package.precompiled:n`: without the second policy xmake fetches some packages (tiltedcore) as prebuilt binaries from its build-artifacts mirror. |
| RedHotTools for 2.5 | xmake | rc.3 plus `patches/red-hot-tools/` and the SDK submodule at `5246e659d7` (why: `docs/reviews.md`); builds the archive hot reload only. |
| RedSocket | xmake | Its `after_build` runs `red-cli` from PATH; disable it. |
| redscript | cargo | `--locked`. |

## Builds

`tools/windows/build-cet.ps1` fetches the pinned commits (CET plus its release tag, because CET's
`xmake.lua` reads its version from `git describe`), builds `version.dll` and
`cyber_engine_tweaks.asi`, and stages them with CET's scripts, fonts, license file and the two
TweakDB name tables from `refs/wolvenkit` (`WolvenKit.Common/Resources`, tag 9.1.0) in the game
layout. `tools/windows/install-stage.ps1` copies a stage into the game and writes a record that
`-Uninstall` uses to restore the folder exactly (install is exercised; `-Uninstall` not yet). The
xmake package versions and the xmake-repo commit of each build are kept in `locks/`.

| Date | What | Commits | Outputs (sha256) | Result |
|---|---|---|---|---|
| 2026-10-27 | CET v1.38.1 + ASI loader | cet `213151fa22`, asi-loader `dc37f026f1`, xmake-repo `747ff46a40` (`locks/cet-213151fa22.xmake-requires.lock`) | `cyber_engine_tweaks.asi` `2d77bcf2…`, `version.dll` `eb93226d…`, `usedhashes.kark` `5d27963e…`, `tweakdbstr.kark` `1eff27ba…` | Loads on patch 2.5 (log: `CET version v1.38.1`, `Game version 3.0.88.46235`, every hook complete, address table built); title screen shows CET's first-time setup. |
| 2026-10-29 | RED4ext v1.31.0 + RedHotTools archives-only (`tools/windows/build-red4ext-rht.ps1`, idle CPU priority while the game ran) | red4ext `9f135ac339`, red-hot-tools `de93c5696f` + patch, RED4ext.SDK `5246e659d7`, xmake-repo `747ff46a40` (`locks/rht-de93c5696f.xmake-requires.lock`) | `winmm.dll` `81863242…`, `RED4ext.dll` `8667041c…`, `RedHotTools.dll` `8547aaac…` | Installed 10-29 02:00 by `install-stage.ps1` (record `installed-red4ext-rht.json`, 6 files, nothing overwritten). Loads on patch 2.5: RED4ext log `Product version: 2.50`, 1,032,136 game addresses, RedHotTools loaded, watcher on `archive\pc\hot`; `RedHotTools.Version()` answers from CET. First hot swap of a mounted mod archive (one mesh changed) in a running game: `Archives reload completed.`, game kept running, a respawned entity showed the new mesh. |
