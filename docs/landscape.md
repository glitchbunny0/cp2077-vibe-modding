# Landscape

What exists for modding Cyberpunk 2077 at patch 2.5, sorted by what an agent would use it for.
Versions are the pins in `refs.toml`; exact commits are in `refs.lock.json`. Checked 2026-10-27.

## The game, as a modding target

REDengine 4. Four surfaces carry nearly all mods:

| Surface | Where it lives in the game | Changed with |
|---|---|---|
| Game scripts (gameplay, UI, quests glue) | compiled into `r6/cache/final.redscripts` | redscript (compile-time), CET (runtime hooks) |
| TweakDB (items, stats, AI, records) | `r6/cache/tweakdb.bin` | TweakXL files, CET `TweakDB` API at runtime |
| Resources (meshes, textures, entities, world) | `.archive` files, CR2W format | WolvenKit, ArchiveXL |
| Native engine | `bin/x64/Cyberpunk2077.exe` | RED4ext plugins (C++) |

The script layer is the reason this game is friendlier to an agent than an Unreal title: the
game's own scripts are readable, typed source (`refs/game-scripts`, 2,077 `.script` files as
REDmod ships them), and every script class and native function is in the RTTI, which is dumped
for patch 2.5 (`refs/nativedb/src/assets/reddump`: 16,141 class entries, 823 globals, 1,555 enums).

## Layers and tools

| Layer | Tool (pin) | What an agent does with it | Runs on | 2.5 |
|---|---|---|---|---|
| Native loader | RED4ext (v1.31.0) | Loads the RED4ext plugins below (`red4ext/plugins`) through a `winmm.dll` proxy | game machine | yes |
| Native loader | CET's ASI loader (Ultimate ASI Loader fork) | `bin/x64/version.dll`: loads `bin/x64/plugins/*.asi` (CET) and exports `ResolveAddress` from the game's own `cyberpunk2077_addresses.json`. CET has no runtime reference to RED4ext.dll; its README still says to install RED4ext first (unverified) | game machine | yes |
| Lua runtime | Cyber Engine Tweaks (v1.38.1) | Run Lua against the live game: call any script class or global, `Observe`/`Override` script functions, read and write TweakDB, ImGui windows, console | game machine | yes |
| Script compiler | redscript (v0.5.32) | Compile `.reds` mods into the game's script cache at launch; decompile and disassemble `final.redscripts` | either (Rust; no Linux release binary, builds from source) | yes |
| Script tooling | redscript-ide (v0.2.25), redscript-dap (v0.0.8) | Language server for diagnostics without the game; debug adapter for breakpoints in a running game | IDE: either (Linux binary exists); DAP: game machine | unverified |
| Script library | Codeware (v1.21.1) | Reflection, entity spawning, UI, events from redscript and CET | game machine | yes |
| Data | TweakXL (v1.12.0) | Load YAML/`.tweak` record edits that don't collide with other mods | game machine | yes |
| Assets | ArchiveXL (v1.28.1), WolvenKit (9.1.0) | Load new items/appearances/world edits; unpack, convert (CR2W to JSON), repack archives | ArchiveXL: game machine. WolvenKit CLI: 9.1.0 also ships a `ConsoleLinux` build (untested here) | yes |
| Dev loop | RedHotTools (v1.3.0-rc.3), red-cli (v0.5.1) | Hot reload scripts, tweaks and archives; world/entity/UI inspector. red-cli bundles and installs a mod project | RHT: game machine. red-cli: either (Dart, Linux build) | RHT unconfirmed (RC3 is from 2026-10-20) |
| Transport | RedSocket (v0.5.0), RedFileSystem (v0.16.0) | TCP client for CET/redscript; sandboxed file IO | game machine | RedSocket unconfirmed (2025-09) |
| Reverse engineering | RTTIDumper, RedMemoryDump (v0.9.1), RED4ext.SDK, NativeDB | Dump the RTTI; diff a live object's memory; generated C++ type layouts; browsable class reference | game machine (dumpers), anywhere (data) | SDK + NativeDB dump: yes. RedMemoryDump: unconfirmed |

Two framework families matter for maintenance: psiberx (TweakXL, ArchiveXL, Codeware, RedHotTools,
red-lib) and rayshader (RedSocket, RedFileSystem, red-cli, NativeDB, RedMemoryDump). Most of
their tools shipped 2.5 updates within three days of the patch. Released before 2.5 and not yet
confirmed on it: RedHotTools (RC3, 2026-10-20), RedSocket (2025-09), RedMemoryDump (2025-11),
redscript-dap (2025-08) and redscript-ide (2025-09).

## Driving a running game

CET is this engine's UE4SS. Its Lua state reaches every script class through RTTI (`Game.*`,
`GetSingleton`, `NewObject`, `Game.GetScriptableSystemsContainer():Get(...)`), hooks script
functions with `ObserveBefore`/`ObserveAfter` (`Observe` is the before alias) and `Override`
(replace, with the original passed in), builds script callback objects with `NewProxy`, and runs
a per-frame `onUpdate` event that a bridge can poll from. The scripting wiki's
`cyber-engine-tweaks/cet-functions` section documents all of it.

CET's Lua is not a security boundary: mods can write any file (`io.output`) and load native DLLs
(`db:load_extension`). A bridge that executes Lua it receives is remote native code execution, so
its transport has to be local-only and authenticated. Details in `docs/reviews.md`.

Existing bridges, prior art for ours:

- **cet-mcp** (Y4rd13, MIT, 3 stars, last push 2026-03): a TypeScript MCP server plus the
  `CETBridge` Lua mod. The mod polls one `command.json` in its own folder every frame, runs
  `exec` (Lua via `loadstring` + `pcall`, `print` captured), `eval` (serialized return value) or a
  named `query` handler, and writes `response.json` atomically; a `heartbeat.json` marks it alive.
  With RedSocket installed it talks TCP to the MCP server on localhost instead. One command slot,
  so concurrent clients race; an infinite loop freezes the game. Same design as our VibeBridge.
- **WkMCP** (Guikingone, MIT server + GPL daemon, v2.1.0): a .NET MCP server over WolvenKit
  libraries (archives, CR2W/JSON, TweakDB, redscript and TweakXL linting, mod diagnostics) plus a
  fork of CETBridge for live tools. Windows only, built against WolvenKit 8.18.
- **wolvenkit-mcp** (Y4rd13): TypeScript MCP server over the WolvenKit CLI.

**Ours: `uvmod` with `UVMOD_CET`** (unreal-vibe-modding, branch `cet`). A CET build of VibeBridge
answers uvmod's LuaRepl protocol from `mods/VibeBridge/LuaRepl`, so the Unreal tooling's SSH
transport, crash triage, journal and MCP server carry over; CETBridge's 34 game handlers ride
along unmodified (WkMCP's fixed copy, reviewed in `docs/reviews.md`) behind `uvmod cet` and the
MCP tool `cet`. Live on 2.5: about 0.9 s per call over SSH. CET gives mods no debug library, so
a request cannot be interrupted; screenshots copy the game window and refuse while another
window is in front.

## Static knowledge an agent can mine offline

- `refs/game-scripts`: the game's script source (patch 2.31). For 2.5, take `tools/redmod/scripts`
  from an updated install or decompile `r6/cache/final.redscripts` with redscript.
- `refs/game-tweaks`: 2,684 `.tweak` files, the TweakDB source (patch 2.31).
- `refs/nativedb/src/assets/reddump`: RTTI dump for 2.5 as JSON (compact keys; the NativeDB app
  in the same repo decodes them).
- `refs/red4ext-sdk/include/RED4ext/Scripting/Natives/Generated`: C++ layouts of native types.
- Docs: see `docs/where-to-look.md`.

## Gaps found while gathering

- **No current CET Lua typedefs.** The last public set covers CET 1.27 / patch 2.01 and lives on
  Discord. The 2.5 RTTI dump is enough to generate fresh LuaLS definitions.
- **Game sources lag one patch.** Both CDPR source mirrors stop at 2.31.
- **Three dev tools predate 2.5**: RedHotTools RC3, RedSocket 0.5.0, redscript-dap 0.0.8.
  Each needs a live check before anything depends on it.
- **The GitHub wikis of CET (2020) and redscript (2021) are stale.** The GitBook "Scripting
  Cyberpunk" space replaced them; prefer it.
- **The bridges are small and young**, like their Unreal counterparts: an open niche, not a solved one.
