# Crash probing: the game froze, crashed or quit

Run the probe on the game box first, before relaunching. It only reads, and the game and Windows overwrite some of
what it reads on the next start:

```
powershell -NoProfile -ExecutionPolicy Bypass -File crash-probe.ps1 -Game "<game dir>" [-Minutes 60]
```

`tools/windows/crash-probe.ps1` takes about 2 s and ends with a `probe-ok` line, so a section with nothing under it is
really empty and not cut off.

## Reading the output

| Section | What it tells you |
|---|---|
| game processes | Whether the game, its launcher, `REDEngineErrorReporter` or `WerFault` still run, and since when. |
| post-mortem (`%LOCALAPPDATA%\CD Projekt Red\Cyberpunk 2077\CrashInfo.json`) | The game writes this on every crash, watchdog kills included. `timeCrash` is UTC, plus session length and `isOom`. The file also names the tracked quest and the location, which the probe leaves out because they are spoilers. |
| RED4ext crash reports (`<game>\red4ext\logs\red4ext-*.log`) | RED4ext logs the engine's own crash report: source file, line and message. `engineWatchdog.cpp` with `Watchdog timeout! (120 seconds)` means the main thread did not finish a frame for 120 s and the engine ended itself. That is a hang, not a crash, and the hang began about 120 s before this line. |
| hang clock | VibeBridge rewrites `mods\VibeBridge\LuaRepl\bridge.json` once a second from CET's `onUpdate`, which runs on the main thread. Its last write time is the last frame Lua saw, so it dates the start of a hang. CET mods' own `.log` files flush only on warnings, so their timestamps lag. |
| RedHotTools log | When the last archive hot reload ran. The probe reads the dated `RedHotTools-*.log` because `RedHotTools.log` is a symlink PowerShell refuses to read. |
| CET `scripting.log` | Mod loads, "Reload all mods" and Lua errors. |
| System log | Display driver resets (`nvlddmkm`, `Display` 4101, `dxgkrnl`), `WHEA` hardware errors, `Kernel-Power` 41 (power lost), OS start and shutdown (`Kernel-General` 12/13). `Display` 4125 is an Auto HDR notice and is filtered out. |
| Windows Error Reporting | Kernel/GPU events (`BlueScreen`, `LiveKernelEvent`) and game crashes, dated by the `EventTime` inside each `Report.wer`. |
| dump files | `.dmp`/`.mdmp`/`.hdmp` in the folders where the game, RED4ext, Windows and WER put them. |

## Pitfalls

- **Date Windows Error Reporting events by `Report.wer` `EventTime`, not by the Application log.** WER logs old queued
  reports again in bursts. On 2026-10-29, 42 reports dated 2025-08 to 2026-10-05 were logged within three seconds,
  and in the Application log they looked like a fresh run of GPU crashes and bluescreens on the night of the hang.
- **A watchdog kill leaves no minidump** (none on 2026-10-29). Our ASI loader can write local minidumps, but only while a
  `bin/x64/CrashDumps` folder exists, and that folder is kept absent on purpose (`docs/reviews.md`). Nobody has tested
  whether a watchdog exit would produce a dump through that path.
- **Never search `%LOCALAPPDATA%` or `%TEMP%` recursively over ssh.** It ran past a 170 s timeout and cut the probe off.
  Search named folders only, as the probe does.
- **Don't let PowerShell format numbers with the box's locale.** `{0:N0}` printed 1999 s as `1.999` on a German locale.
- **`uvmod shot` on CET doesn't touch the game.** It copies the screen, and only while the game window is in front.
  It can't be the cause of a hang.

## Isolating a hang

A hang leaves no stack, so isolate it by its conditions, one per run:

1. Change one thing at a time, for example the same scene with and without an archive hot swap. Keep everything else
   the same, and leave the game running for a fixed time, also in the background, which is where the 2026-10-29 hang
   happened.
2. Bracket each risky call on the Lua side: write a line to a small trace file before it and another after it. The
   last line without a matching "after" line is the call that never returned. The trace is temporary, because a file
   write per call costs time.
3. Run the probe after every hang and record it below.

## Incidents

| When | What the probe showed | Conditions | Status |
|---|---|---|---|
| 2026-10-29 20:19 | Crash, not a hang: heartbeat 20:19:14, `timeCrash` 20:19:15, session 1962 s, `isOom` false. No RED4ext crash block, no dump. `uvmod crash`: the last exec got no answer. | That exec was one line: `tostring(EnumInt(PlayerPuppet.GetSceneTier(Game.GetPlayer())))` plus `IsInCombat()`. On 2.5 `GetSceneTier` returns a plain `Uint8`, not an enum, so `EnumInt` got a number. The exec before it (journal contact lookup, function definitions) had answered. Earlier the same session: other requests, all answered. | Cause found 20:25 the same evening: `PlayerPuppet.GetSceneTier(Game.GetPlayer())` on its own answers `1` (a Lua number; 1 = free roam) and the game kept running. That leaves `EnumInt` given a plain number as the crash, despite `SOL_ALL_SAFETIES_ON`. Rule: call `EnumInt` only on enum values. Only check with `type(x) == "userdata"` first if a value could be either. |
| 2026-10-29 | Main thread hung from 02:31:46 (heartbeat). Watchdog kill at 02:33:47. No dump. Nothing in the System log. `isOom` false. | 4 min after the second RedHotTools hot swap of a mod archive (02:27:25) and a CET "Reload all mods". A CET mod was switching full-body mesh components of one spawned entity on and off up to 12 times a second, with the game in the background. The first hot swap that night ran 20 min without trouble. | Open. Suspects: the 2.5 port's reload call (`LoadArchives(..., 0, 2)`, its mode values taken from ArchiveXL rather than verified), or turning full-body components on and off, which may load and unload meshes at that rate. Next run: no hot swap, the component switching running with a Lua trace, about 15 min. If that run stays clean, repeat it after one hot swap. |
