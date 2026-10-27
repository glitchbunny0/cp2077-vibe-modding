# Source reviews

The frameworks and tools this kit builds or runs, each reviewed read-only at the exact commit before
its first build (see `AGENTS.md`). One row per repo and commit; a new pin needs a new row.

Checks: build-time actions (downloads, `execute_process`/custom build steps, committed binaries,
install scripts) and runtime capabilities (network, process spawn, persistence, file writes
outside the game directory, anything that phones home).

Method for the 2026-10-27 round: three read-only subagents (claude-haiku-5-5) took 13 repos with
the brief from the `unreal-game-modding` skill. Judy re-read in the source every SUSPICIOUS claim
and every claim the plan depends on before recording it here, and reviewed the rows marked
"Judy" herself.

| Repo | Commit | Verdict | Date | Notes |
|---|---|---|---|---|
| wopss/RED4ext | `9f135ac339` (v1.31.0) | CLEAN | 2026-10-27 | No network, process or registry code. Loads every DLL in `red4ext/plugins` (its purpose). Configure-time FetchContent at pinned commits: Detours, fmt, spdlog, simdjson, toml11, WIL, RED4ext.SDK `0f5eba42`, redscript `b413ba6a` (rows below). |
| wopss/RED4ext.SDK | `5246e659d7` | CLEAN | 2026-10-27 | Header-only; generated headers include only `<cstdint>` and SDK headers. `scripts/find_patterns.py` is an IDA script. Same commit CET, TweakXL, ArchiveXL and Codeware pin. |
| wopss/RED4ext.SDK | `0f5eba42a4` | CLEAN (Judy) | 2026-10-27 | Fetched by RED4ext's CMake. Parent of `5246e659d7`; the diff is the 2.5 type/layout update only: generated headers, the `ResourceDepot.hpp` enum value, the `CMesh.hpp` layout, CHANGELOG. |
| jac3km4/redscript | `b413ba6a40` | CLEAN (Judy) | 2026-10-27 | Fetched by RED4ext's CMake for `crates/scc/capi/include/scc.h` only: a C header with a `GetProcAddress` table for `scc_lib.dll`. No root `CMakeLists.txt`, so `FetchContent_MakeAvailable` runs nothing. |
| maximegmd/CyberEngineTweaks | `213151fa22` (v1.38.1) | SUSPICIOUS, not malicious | 2026-10-27 | No network, process, registry or telemetry code in CET itself. Two real issues, both verified: the Lua sandbox is not a boundary (Findings 1), and `vendor/asiloader/version.dll` is a committed binary CET needs at runtime (Findings 2). `xmake package` downloads two `.kark` files from WolvenKit's GitHub without a hash (`xmake.lua:138-139`): do not use `xmake package`; fetch and hash-pin them ourselves. |
| maximegmd/Ultimate-ASI-Loader | `dc37f026f1` | fork delta CLEAN (Judy), base PENDING | 2026-10-27 | Three commits on top of ThirteenAG `c30e6d3d`: `source/resolve.cpp` builds an address table from the game's `bin/x64/cyberpunk2077_addresses.json`, caches it in `bin/x64/plugins/address_library/`, exports `ResolveAddress`; premake renames the output to `version.dll`; simdjson and parallel-hashmap become submodules. No network or process code in the delta. The upstream UAL base (file-overload hooks, crash dumps) is not reviewed yet. The repo commits `premake5.exe` and `7za.exe`: take premake from its own release instead. |
| jac3km4/redscript | `f73003ac55` (v0.5.32) | CLEAN | 2026-10-27 | scc writes only under `r6/` (cache, logs). Git deps `hamt-sync`, `rust_sequence_trie` and crates.io sources not reviewed. |
| jac3km4/redscript-ide | `b37a3dc40f` (v0.2.25) | CLEAN | 2026-10-27 | stdio language server; reads only. Git deps (redscript-* v1.0.0-preview.22, `stable_deref_trait` patch) not reviewed. |
| jac3km4/redscript-dap | `3f5b4202ba` (v0.0.8) | SUSPICIOUS, not malicious | 2026-10-27 | Verified: `src/server.rs:51` binds `0.0.0.0` on a random port from game start, no auth. A client can read game memory and park the game thread; unchecked slice bounds abort the game (`panic=abort`). Never run as released: patch the bind to `127.0.0.1` first. `red4ext-rs` git dep not reviewed. |
| psiberx/cp2077-red-hot-tools | `de93c5696f` (v1.3.0-rc.3) | CLEAN | 2026-10-27 | Only process launch is the game's own `scc.exe` compile on reload. Watches `archive/pc/hot` and its plugin dir; moves hot files into `archive/pc/mod`. Clipboard write-only. |
| psiberx/cp2077-tweak-xl | `0d13bb9057` (v1.12.0) | CLEAN | 2026-10-27 | `lib/Red` identical to red-lib. Deletes its own legacy `r6/scripts/TweakXL` at startup. |
| psiberx/cp2077-archive-xl | `0984aa1c94` (v1.28.1) | CLEAN | 2026-10-27 | One in-memory code patch (widget limit), by design. |
| psiberx/cp2077-codeware | `b56f0f6674` (v1.21.1) | CLEAN | 2026-10-27 | Exposes clipboard get/set to every redscript mod (`scripts/UI/inkSystem.reds:8-9`); nothing reads it on its own. |
| psiberx/cp2077-red-lib | `398a7104a5` | CLEAN | 2026-10-27 | Header-only. |
| rayshader/cp2077-red-socket | `055420a731` (v0.5.0) | CLEAN | 2026-10-27 | Outbound TCP client only; scripts choose the host. Unbounded receive buffer. Its `after_build` runs whatever `red-cli` is first on PATH: disable that step or review red-cli first. |
| Y4rd13/cyber-engine-tweak-mcp | `4893237b5d` | SUSPICIOUS, by design | 2026-10-27 | TCP listener `127.0.0.1:27010`, no auth; the Lua mod runs whatever Lua it receives. Correction to the subagent: its file IPC goes through CET's wrapped `io.open`/`os.remove`/`os.rename`, which resolve relative paths inside the mod folder (`GetLuaPath` in CET's `LuaSandbox.cpp`), not the game's working directory. Prior art only; we do not run it. |

## Findings that shape the work

1. **CET Lua is full-trust code.** In CET's `src/scripting/LuaSandbox.cpp`, `io.input` and
   `io.output` are copied unwrapped (around line 536), so `io.output("C:/any/path")` plus
   `io.write` writes any file; and every mod's `db` object carries lsqlite3's
   `db:load_extension(path)` (`src/lsqlite3/lsqlite3.cpp:1302-1326`, registered at `:2362`), which
   loads a native DLL. Any CET mod, and any bridge that executes Lua it receives, can run native
   code as the game user. Consequences: review CET Lua mods like native code; a bridge transport
   must be local-only and authenticated; consider a local CET patch that drops `load_extension`
   and wraps `io.input`/`io.output` (a candidate upstream fix).
2. **CET cannot run without its own `version.dll`.** `src/reverse/Relocation.h` loads
   `<exe dir>/version.dll` and calls `ResolveAddress`, an export the CET fork of Ultimate ASI
   Loader adds. Build that fork from source; never copy the committed binary.
3. **Unpinned build inputs.** xmake-repo packages in CET, TweakXL, ArchiveXL, Codeware and
   RedHotTools float. Generate an xmake requires lock on the first build and keep it with our
   build recipe so rebuilds are reproducible.
4. **Not yet reviewed:** the upstream UAL base, xmake-repo packages, crates.io and git
   dependencies of the Rust tools, red-cli, RedFileSystem, RedMemoryDump.
