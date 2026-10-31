# AGENTS.md

Rules for any agent working in this repository.

## What this is

A kit for modding Cyberpunk 2077 (REDengine 4) with an agent: the upstream tools and documentation
it studies, notes on what they can do, the agent skill with the game's measured API
(`skills/cp2077-vibe-modding/`), and scripts that build and install the frameworks from reviewed
source. The bridge that lets an agent drive a running game is `uvmod` with `UVMOD_CET`
(github.com/glitchbunny0/unreal-vibe-modding). Patch target: **2.5** (game version 3.0.88.46235,
released 2026-10-22).

## refs/ is upstream, not ours

- `refs/` holds clones and doc mirrors listed in `refs.toml`. It is gitignored. Refresh it with
  `tools/fetch_refs.py sync` (pinned commits from `refs.lock.json`) or `update` (re-resolve refs
  and rewrite the lock). Commit `refs.toml` and `refs.lock.json` together when a pin changes.
- Read it freely. Never edit files there; copy what you need and credit it.
- Never commit, publish or ship anything from `refs/`. WolvenKit is GPL-3.0, and `game-scripts` /
  `game-tweaks` are CDPR's game content: study material for interoperability, nothing more.
- Cloning runs no upstream code. Building or running it is a separate step (next section).

## Builds and bridges

- A build script here builds only a commit that has a recorded review in `docs/reviews.md` (brief:
  `docs/review-brief.md`): build-time actions (downloads, `execute_process`, committed binaries) and
  runtime capabilities (network, process spawn, persistence, writes outside the game directory).
- CET Lua mods are native-trust code (they can write any file and load DLLs; see `docs/reviews.md`).
  A bridge that executes Lua or commands it receives never takes them from the network: file IPC
  inside the game folder, or a localhost socket that requires a shared secret. Nothing binds `0.0.0.0`.

## Keep machine details out

No hostnames, IPs, user names, install paths of a specific machine or SSH recipes in this
repository. Write paths relative to the game directory
(`<game>/bin/x64/plugins/cyber_engine_tweaks/mods/...`).

## Conventions

- Python: standard library only unless a dependency is clearly worth it.
- `skills/`: every game fact says how it is known: measured (ran in the game, with patch and CET version), static
  (read from the scripts or the RTTI dump) or untested. A wrong fact there crashes someone's game. The full bar and
  what goes where: `CONTRIBUTING.md`.
- Names of game types and functions are guesses about behaviour until a trace confirms them.
