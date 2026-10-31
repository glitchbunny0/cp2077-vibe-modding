---
name: cp2077-vibe-modding
description: Use when writing CET Lua, custom meshes, FX or HUD code for Cyberpunk 2077 patch 2.5. Measured facts and rules that keep the game from crashing or freezing.
license: MIT
---

# Cyberpunk 2077 vibe modding (patch 2.5, CET 1.38.1)

Measured facts for writing Cyber Engine Tweaks (CET) Lua against Cyberpunk 2077 patch 2.5 (game version 3.0.88.46235), and the rules that keep a running game alive. The tool that sends code to the game is `uvmod` with `UVMOD_CET` set. Its skill, `cet-vibe-modding` (`skills/cet-vibe-modding/` in [unreal-vibe-modding](https://github.com/glitchbunny0/unreal-vibe-modding)), covers how to send code and read answers. This skill covers what the code can safely do.

## When to use

- Writing or reviewing CET Lua for 2.5: player state, targeting, hooks, input, on-screen text, phone calls.
- Drawing a 2D overlay or HUD element, or spawning an effect or making a device react.
- Packaging a custom mesh or a skinned prop with the WolvenKit CLI.
- Not for general script or tweak packaging (redscript, TweakXL, ArchiveXL): see the kit's `docs/landscape.md`.

## How to read the claims

- **measured**: ran in the game on 2.5 with CET 1.38.1.
- **static**: read from the 2.5 scripts or the RTTI dump; not run in the game.
- **untested**: neither. Treat it as a hypothesis.
- A name in the RTTI dump proves the name is registered. It does not prove what the name does. Confirm behaviour with a trace.

## Rules that keep the game alive

1. **Bound every loop.** CET gives mods no debug library, so a running request cannot be interrupted. An unbounded loop freezes the game until the watchdog kills it, 120 s later.
2. **Call `EnumInt` only on enum values.** On a plain Lua number it crashed the game on CET 1.38.1, even with `SOL_ALL_SAFETIES_ON`. If a value might be either, test `type(x) == "userdata"` first.
3. **Never re-add work at or before the current clock from inside the scheduler step.** The new entry runs in the same frame, the clock never moves, and the main thread spins until the watchdog kills the game. Schedule at least the next frame (clock + 0.001), or walk a tracker list once per frame.
4. **Register each hook once.** `ObserveAfter`, `ObserveBefore` and `Override` cannot be removed until CET reloads its mods. Keep a global flag, and keep callbacks short: they run on every call of the hooked function.
5. **Check the player first.** `Game.GetPlayer()` is nil in menus and on loading screens.
6. **Ask before changing the save or the install.** Items, quest facts, stats and spawned props can reach the next save. Closing or restarting the game loses unsaved progress.
7. **Treat CET Lua as native code.** A mod can write any file and load a DLL. Review third-party code before it runs. A bridge that runs Lua it receives uses file IPC inside the game folder, or localhost with a shared secret. Never bind 0.0.0.0.
8. **Keep plugin folders to what you installed on purpose.** Native code runs from RED4ext's `red4ext/plugins` and from the ASI loader's folders (`bin/x64/scripts`, `plugins`, `update`). With the ASI loader CET ships, `update` and `CrashDumps` switch on extra behaviour; keep them absent unless you want it (`references/runtime-safety.md`).

## Where things are

- The kit ([cp2077-vibe-modding](https://github.com/glitchbunny0/cp2077-vibe-modding); paths below are relative to its root): `docs/landscape.md` (what each tool does, 2.5 status), `docs/where-to-look.md` (question to file), `docs/crash-probing.md` (freeze and crash triage), `docs/building.md` (toolchain and framework builds), `docs/reviews.md` (source verdicts), `AGENTS.md` (rules).
- The 2.5 scripts, RTTI dump and archive indexes are not in this repository. `references/engine-sources.md` says how to get them.
- Upstream sources are fetched into the gitignored `refs/` folder by `tools/fetch_refs.py sync`.
- CET's folder in the game is `<game>/bin/x64/plugins/cyber_engine_tweaks`. Mods live in its `mods/` folder.

## Routing table

| Task | Read |
|---|---|
| CET calls on 2.5: out parameters, names, TweakDB, eddies, district, wanted level, tracked quest, targets, stats | `references/cet-api-2.5.md` |
| Crash and hang rules in full; input; hooks; mod settings; CET trust model | `references/runtime-safety.md` |
| On-screen messages, holocalls, subtitles | `references/messages-and-calls.md` |
| Phone messages from a custom contact (journal, Phone Extension, CET toast) | `references/phone-messages.md` |
| 2D overlay, HUD root, ink widgets, ImGui drawing, camera projection | `references/hud-and-ink.md` |
| Raycasts, effects, traffic lights, screens | `references/world-fx-devices.md` |
| Screenshots and video of an HDR game | `references/screenshots-hdr.md` |
| WolvenKit CLI on Linux: limits, licences, running it boxed | `references/wolvenkit-cli-linux.md` |
| Custom meshes and entities in the scene; neon colours | `references/custom-mesh-props.md` |
| Skinned meshes, bones and animgraphs driven from CET | `references/skinned-mesh-rigs.md` |
| Where the 2.5 scripts, RTTI and archive indexes come from; is a subsystem native | `references/engine-sources.md` |

## If the game freezes or quits

1. Run the read-only probe before relaunching: `tools/windows/crash-probe.ps1 -Game "<game dir>"`. It takes about 2 s and ends with `probe-ok`. The kit's `docs/crash-probing.md` explains how to read it.
2. `Watchdog timeout! (120 seconds)` in RED4ext's crash report means the main thread did not finish a frame for 120 s: a hang, not a crash. The heartbeat file's last write dates the start of the hang.
3. Do not resend the request that got no answer. Isolate the cause one change per run (runtime-safety.md).

## Working in small steps

- Probe one thing per request, read the answer, then go on.
- Before you name a class or function, find it in the 2.5 dump or scripts (`references/engine-sources.md`). Tag claims as verified in source, documented or inferred.
- When the player is watching, you may announce each live step on screen (recipe in `references/messages-and-calls.md`).
- Screenshots work only while the game window is in front. Ask the player to switch windows; do not work around the check.

## Adding what you learn

This skill grows from what agents measure. When you confirm something in the game that is not here (a call that
works, one that crashes, a convention), or find a fact here wrong on your patch:

1. Tell the player, and ask whether they want to contribute it to the kit.
2. If yes: write it into the matching reference file as a rule with its reason, tagged measured, static or untested,
   with the game patch and CET version, plus the Lua that ran. Generic engine behaviour only; leave out the player's
   own mod design, machine details and story content.
3. Open the pull request from the player's fork of the kit (`CONTRIBUTING.md` there says what goes where). A new
   ready-made game call belongs in uvmod instead (its `CONTRIBUTING.md`).
