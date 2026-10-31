# Runtime safety: crash and hang rules (2.5, CET 1.38.1)

Each rule carries its measured reason. The short form is in SKILL.md.

## What a freeze and a crash look like

- **Watchdog.** RED4ext's crash report (`<game>/red4ext/logs/red4ext-*.log`) shows `Watchdog timeout! (120 seconds)` from `engineWatchdog.cpp` when the main thread does not finish a frame for 120 s. The engine ends itself. This is a hang, not a crash. No minidump is written, and the hang began about 120 s before that line.
- **Crash record.** The game writes `CrashInfo.json` in `%LOCALAPPDATA%\CD Projekt Red\Cyberpunk 2077` on every crash, watchdog exits included. It holds the UTC crash time, the session length and an out-of-memory flag.
- **Hang clock.** A mod that rewrites a heartbeat file from `onUpdate` dates a hang. uvmod's VibeBridge rewrites its heartbeat (`mods/VibeBridge/LuaRepl/bridge.json`) about once a second. Its last write time is the last frame Lua saw.
- **Mod logs lag.** CET writes `scripting.log` and a mod's own log only when a warning flushes them. Recent info lines can be missing. Read the heartbeat instead.
- **No dump on a watchdog kill.** The ASI loader writes local minidumps only while `bin/x64/CrashDumps` exists. Whether a watchdog exit would dump through that path is untested.
- **Windows Error Reporting** re-logs old queued reports in bursts. Date its events by the `EventTime` inside each `Report.wer`, not by the Application log.
- **A screenshot cannot hang the game.** `uvmod shot` only copies the screen.

## Crash rules (measured)

1. **`EnumInt` on a plain number crashes the game.** On 2.5, `PlayerPuppet.GetSceneTier(p)` returns a plain Lua number (1 means free roam), not an enum. `EnumInt(PlayerPuppet.GetSceneTier(p))` crashed the game on CET 1.38.1 with `SOL_ALL_SAFETIES_ON` set. The call on its own, `PlayerPuppet.GetSceneTier(p)`, is safe.
2. **When a value might be a number or an enum, test first:** `type(x) == "userdata"`.
3. **Quiet state checks** that ran safely: `PlayerPuppet.GetSceneTier(p)` on its own, and `p:IsInCombat()`.
4. **`EnumInt` on the enum returned by the wanted-level call is the working pattern** (`cet-api-2.5.md`).

## Hang rules (measured)

1. **Scheduler re-add.** In an `onUpdate` scheduler, a step that adds a new step with a time at or before the current clock causes that step to run in the same frame. The clock never moves, and the thread spins. The watchdog kills the game 120 s later. Schedule at least the next frame (clock + 0.001), or add a tracker that walks its list once per frame. Clamp every delay to at least 1 ms.
2. **Bound every loop.** CET cannot stop a running request. A loop with no bound freezes the game until the watchdog ends it.
3. **Keep callbacks short.** Code inside `Observe` or `Override` runs on every call of the hooked function.
4. **Isolate a hang by bracketing.** A hang leaves no stack trace. Write a trace line before and after each risky call, to a small file, and only while isolating. The last "before" line with no matching "after" is the call that never returned.
5. **Open and not isolated.** About four minutes after an archive hot swap and a CET "Reload all mods", a hang followed. A CET mod had been switching full-body mesh components of one spawned entity on and off up to 12 times a second, with the game in the background. Suspects: the archive reload call, and the toggle rate. Until the cause is found, keep the toggle rate low and change one thing per run.

## Triage order after a freeze or crash

1. Run the read-only probe first: `tools/windows/crash-probe.ps1 -Game "<game dir>"` (about 2 s; ends with `probe-ok`). `docs/crash-probing.md` in the kit explains each section and keeps the incident table.
2. Read the RED4ext crash block, the heartbeat time and `CrashInfo.json`.
3. Do not resend the request that got no answer.
4. Relaunch only after the probe has been read.

## Input

- **`registerHotkey`** fires on key release. CET's input code (`VKBindings.cpp`) fires it only when no other key was down at the press. A press made while another key is held, for example while walking, is dropped.
- **`registerInput`** fires on the press itself. Use it when you need the press: act on "down" and debounce in your own code.
- **Raw mouse.** CET's raw-mouse handler switches on the whole `usButtonFlags` field. A packet that carries two transitions (for example a wheel button and a wheel tick) is dropped, and the key can stick. Prefer keyboard keys or mouse buttons 4 and 5. An upstream fix is possible; untested.

## Hooks

- `ObserveBefore` (alias `Observe`), `ObserveAfter` and `Override` cannot be removed until CET reloads its mods. Register each one once, behind a global flag.
- `Override` replaces the function. It receives the original as an argument.

## Trust model (CET)

- `io.open`, `os.remove` and `os.rename` are wrapped by CET so that relative paths resolve inside the mod's folder.
- `io.input` and `io.output` are copied unwrapped. `io.output("<any path>")` plus `io.write` can write any file.
- Every mod's `db` object carries lsqlite3's `db:load_extension`, which loads a native DLL.
- So review CET mods like native code, and do not rely on the Lua sandbox as a security boundary.
- A bridge that runs Lua it receives needs local-only transport with a shared secret, or file IPC inside the game folder. Never bind 0.0.0.0.
- Review third-party code at a pinned commit before you build or install it. `docs/reviews.md` in the kit shows the verdict format.
- Folders that run native code: RED4ext's `red4ext/plugins`, and CET's loader folders `bin/x64/scripts`, `bin/x64/plugins` and `bin/x64/update`. Keep only what you built. `update` turns on a file-path overlay when present; `CrashDumps` turns on local minidumps and patches the unhandled-exception filter. Keep both absent unless you want those features.

## Mod settings

- Save a mod's settings as JSON in its own folder with CET's global `json` and `io.open` on a relative path, which CET
  resolves inside the mod's folder: `local f = io.open("settings.json", "w"); f:write(json.encode(t)); f:close()`, and
  read it back with `pcall(json.decode, f:read("*a"))` so a broken file does not stop the mod.
- Load them in `onInit`. Save them when the settings window closes. Give the window a "Defaults" button.
- Tested offline against a fake CET; the save and load path has not been checked in a live game.

## Reloading and installing

- CET loads mods at game start, and again on "Reload all mods" in CET's overlay. The reload takes about a second and keeps the session. Ask the player to press it; it is their overlay.
- Changes to a mod's Lua take effect only after a reload or a game start.
- Ask before closing the game or changing its install.
