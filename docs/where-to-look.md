# Where to look

A map from question to file. Paths are relative to `refs/` (run `tools/fetch_refs.py sync` first).
Search the mirrors with ripgrep; every GitBook space also has its `llms.txt` page index.

## How do I ... at runtime (CET, Lua)

| Question | Look in |
|---|---|
| CET events (`onInit`, `onUpdate`, `onDraw`, `onShutdown`), hotkeys | `docs/wiki-scripting/cyber-engine-tweaks/cet-functions/events/`, `.../hotkeys/` |
| Hook a script function (`ObserveBefore/After`, `Override`, `NewProxy`) | `docs/wiki-scripting/cyber-engine-tweaks/cet-functions/observers/` |
| Mod layout, logging, debugging a CET mod | `docs/wiki-scripting/cyber-engine-tweaks/first-steps/` |
| Translate redscript calls into CET Lua | `docs/wiki-scripting/scripting/redscript-to-cet.md` |
| Game systems from script: TweakDB, journal, events and callbacks, UI | `docs/wiki-scripting/scripting/game-systems/` |
| Worked snippets (player, camera, entities, effects, menus, UI) | `docs/wiki-scripting/scripting/snippets-and-examples/` |
| CET helper modules (game state, timers, per-save storage) | `cet-kit/` |
| How a working bridge does command polling and serialization | `cet-mcp/cet-mod/CETBridge/`, `cet-mcp/docs/architecture.md` |

## What does the game itself do

| Question | Look in |
|---|---|
| The source of a game script class or function (patch 2.31) | `game-scripts/scripts/` (`core/`, `cyberpunk/` by system: `player`, `NPC`, `UI`, `vehicles`, `quest`, ...) |
| A TweakDB record and its fields (patch 2.31) | `game-tweaks/tweaks/base/`, `game-tweaks/tweaks/ep1/` (Phantom Liberty) |
| Every class, field, function and enum in RTTI (patch 2.5) | `nativedb/src/assets/reddump/*.json` (compact keys; decoder in `nativedb/src/`) |
| Usage notes for tricky native classes | `wiki-nativedb/classes/`, `wiki-nativedb/globals.md` |
| Native type layouts for C++ | `red4ext-sdk/include/RED4ext/Scripting/Natives/Generated/` |
| Tweak IDs, quest IDs, world sectors, inkWidgets, equipment lists | `docs/wiki-modding/for-mod-creators-theory/references-lists-and-overviews/` |

## How do I change it (compile-time)

| Question | Look in |
|---|---|
| redscript language: hook annotations (`@wrapMethod`, `@replaceMethod`, `@addField`), modules, intrinsics | `docs/wiki-scripting/redscript/language-reference/` (`hook-annotations.md` first), `docs/wiki-scripting/redscript/common-patterns/` |
| redscript compiler internals, decompiler, CLI flags | `redscript/` (README; `compiler/`, `decompiler/`, `cli/`, `scc/`) |
| TweakXL YAML format and scripting API | `wiki-tweakxl/`, `docs/wiki-modding/for-mod-creators-theory/tweaks/`, `docs/wiki-modding/for-mod-creators-theory/core-mods-explained/tweakxl/` |
| ArchiveXL `.xl` manifests, resource patching | `docs/wiki-modding/for-mod-creators-theory/core-mods-explained/archivexl/`, `wiki-archivexl/` |
| File formats (CR2W resources, components, effects, lights) | `docs/wiki-modding/for-mod-creators-theory/files-and-what-they-do/` |
| WolvenKit CLI commands | `docs/wiki-wolvenkit/wolvenkit-cli/` |
| Codeware APIs | `docs/wiki-scripting/scripting-cyberpunk/codeware/`, `wiki-codeware/` |
| RED4ext plugins: create one, add a native function or class, game states, logging | `docs/docs-red4ext/mod-developers/` |
| Mod project bundling and install | `red-cli/README.md` |

## When something breaks

| Question | Look in |
|---|---|
| General mod debugging, log locations | `docs/wiki-modding/debug-guide/` |
| The game froze, crashed or quit: what happened and when | this repo: `docs/crash-probing.md` (run `tools/windows/crash-probe.ps1` first) |
| User-side troubleshooting (load order, broken frameworks after a patch) | `docs/wiki-modding/for-mod-users/user-guide-troubleshooting/` |
| What changed for plugins in the latest patch | framework release notes (`gh release view <tag> -R <repo>`) and the commits between pins in `refs.lock.json` |

## Stale sources

`wiki-cet` (2020) and `wiki-redscript` (2021) are the projects' old GitHub wikis. The GitBook
"Scripting Cyberpunk" space (`docs/wiki-scripting`) replaced both. `cet-examples` (2021) uses
old API spellings in places.
