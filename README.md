# cp2077-vibe-modding

Vibe modding for Cyberpunk 2077: let an AI coding agent run Lua inside your running game, look at what it did, and
build a mod with you in small, checked steps. You play and say what you want; the agent probes the game, writes the
code, and verifies it live.

This repository is the kit around the tool. The tool itself is
[`uvmod`](https://github.com/glitchbunny0/unreal-vibe-modding) (CLI and MCP server), which reaches the game through
[Cyber Engine Tweaks](https://github.com/maximegmd/CyberEngineTweaks) (CET) and a small CET mod, VibeBridge. Here you
get what an agent needs to use it well:

- **An agent skill** ([`skills/cp2077-vibe-modding`](skills/cp2077-vibe-modding/SKILL.md)): the game's script API as
  measured live on patch 2.5 with CET 1.38.1. Calling conventions, the calls that crash or freeze the game, the HUD
  and ink widgets, effects, devices, on-screen text and phone calls, screenshots under HDR, and custom meshes.
- **The upstream sources and docs, pinned** (`refs.toml`, `tools/fetch_refs.py`): CET, RED4ext, redscript, TweakXL,
  ArchiveXL, Codeware, WolvenKit, NativeDB's RTTI dump, the existing agent bridges, CDPR's script and tweak sources as
  REDmod ships them, and the community wikis as markdown, all mirrored locally so an agent can read them offline.
- **Maps for those sources** (`docs/landscape.md`, `docs/where-to-look.md`): what each tool does for an agent, its 2.5
  status, and which file answers which question.
- **A crash probe** (`tools/windows/crash-probe.ps1`, `docs/crash-probing.md`): what ended the last session, and when.
  Run it before relaunching.
- **Building the frameworks from reviewed source** (optional, `docs/reviews.md`, `docs/building.md`,
  `tools/windows/`): source review verdicts, and scripts that build CET with its ASI loader, RED4ext and an
  archives-only RedHotTools for 2.5 from pinned commits and install them with a record that undoes the install.

> **Status:** works on patch 2.5 (game version 3.0.88.46235, GOG, Windows) with CET 1.38.1, CLI and MCP: with the agent
> on the game PC itself (Python 3.13; Lua, game handlers, log, crash report and screenshots; 30-50 ms round trip per request) and
> on another machine over SSH. Not tried yet: Steam and Epic installs, Linux with Proton. Please report what you find.

## Quick start

You need the game on Windows, Python 3.9 or later, and an agent that speaks MCP (Claude Code, Codex, Cursor, Hermes,
...).

1. **Install CET** v1.38.0 or later (the first releases for patch 2.5), from
   [its releases](https://github.com/maximegmd/CyberEngineTweaks/releases) or Nexus Mods, and start the game once so CET
   sets itself up. (Prefer building it yourself? See [Building from source](#building-from-source).)
2. **Install uvmod** and point it at CET's folder:

   ```sh
   pip install git+https://github.com/glitchbunny0/unreal-vibe-modding
   ```

   In `%USERPROFILE%\.config\uvmod\config` (or as an environment variable):

   ```ini
   UVMOD_CET=C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks
   ```

3. **Install VibeBridge** and load it: `uvmod install-bridge`, then start the game (or click "Reload all mods" in CET's
   overlay). Check with `uvmod status`, then try `uvmod cet overview` in a loaded save.
4. **Connect your agent** to `uvmod mcp`. With Claude Code: `claude mcp add uvmod -- uvmod mcp`. Elsewhere, the usual
   MCP entry:

   ```json
   { "mcpServers": { "uvmod": { "command": "uvmod", "args": ["mcp"] } } }
   ```

5. **Give it the skills**: copy [`skills/cp2077-vibe-modding`](skills/cp2077-vibe-modding) from this repository and
   [`skills/cet-vibe-modding`](https://github.com/glitchbunny0/unreal-vibe-modding/tree/main/skills/cet-vibe-modding)
   from uvmod's into your agent's skills folder (for Claude Code, `~/.claude/skills/`). The first holds the game
   facts, the second how to drive the game with uvmod without freezing it.
6. **Optional, recommended: the sources.** Clone this repository and run `tools/fetch_refs.py sync` (about 370 MB; git
   and Python 3.11 or later). The agent then reads CET's and the game's own scripts instead of guessing, with
   `docs/where-to-look.md` as its map.

Then ask for something small first ("show me what I'm looking at", "put a message on screen") and work up from there.

## Getting the sources

```sh
tools/fetch_refs.py sync                # everything at the locked commits (~370 MB)
tools/fetch_refs.py sync --with-heavy   # plus WolvenKit's source (~255 MB more)
tools/fetch_refs.py status              # compare refs/ with the lock
tools/fetch_refs.py update --only cet   # move one pin forward, rewrite its lock entry
```

`sync` is idempotent and skips anything already at its locked commit; a locked commit is fetched by its SHA and
checked. GitBook spaces are mirrored page by page from their `llms.txt` index (four spaces, about 790 pages).

Frameworks (CET, RED4ext and its SDK, redscript with its language server and debugger, TweakXL, ArchiveXL, Codeware,
RedHotTools, red-cli), agent-useful plugins (RedSocket, RedFileSystem, RTTIDumper, RedMemoryDump, NativeDB with its
2.5 RTTI dump, red-lib), the existing agent bridges (cet-mcp, wolvenkit-mcp, WkMCP), examples and typedefs, CDPR's
script and tweak sources as REDmod ships them, and the modding, scripting, WolvenKit and RED4ext wikis.

## Safety

- **Code the agent sends runs with the full power of a CET mod.** CET's Lua can write any file and load DLLs
  (`docs/reviews.md`, findings). VibeBridge takes requests only from files inside its own mod folder and never listens
  on the network: anything that can write to that folder can run code in your game, so keep it yours.
- **Your save is real.** Items, quest facts, stats and levels the agent changes end up in your next save. The skills
  tell the agent to ask first; back up your saves anyway.
- **Single player only.** Do not use this in any online or multiplayer session.
- **Some calls crash or freeze the game** rather than raising a Lua error. The skills list the ones measured so far;
  `docs/crash-probing.md` explains how to find out what happened.

## Building from source

The release builds of CET and the other frameworks are what most players use, and they work with uvmod. If you only
run code you built from source you read, as this project does on its own test machine:

- `docs/review-brief.md` is the read-only malware review brief used for every third-party repo, and `docs/reviews.md`
  records each verdict with the commit it covers.
- `docs/building.md` lists the Windows toolchain and how each project builds; `tools/windows/toolchain-smoke.ps1`
  checks the toolchain.
- `tools/windows/build-cet.ps1` builds CET and its ASI loader from the pinned commits into a staged game layout;
  `tools/windows/build-red4ext-rht.ps1` does the same for RED4ext and RedHotTools' archive hot reload, ported to 2.5 by
  `patches/red-hot-tools/`.
- `tools/windows/install-stage.ps1` installs a stage into the game and writes a record of every file it added;
  `-Uninstall -Record <file>` is meant to restore the folder from it (not exercised yet).
- `tools/wkit.sh` runs the WolvenKit CLI in a container with no network, for packing archives on Linux.

## Layout

| Path | What |
|---|---|
| `skills/cp2077-vibe-modding/` | The agent skill: measured 2.5 facts, rules that keep the game alive |
| `refs.toml`, `refs.lock.json` | Every upstream source with its pin and why it is here; the resolved commits and digests |
| `tools/fetch_refs.py` | Clones and mirrors everything into `refs/` (stdlib Python + git) |
| `refs/` | The clones and doc mirrors (gitignored, never committed) |
| `docs/landscape.md` | What each tool does for an agent, where it runs, its 2.5 status, the gaps |
| `docs/where-to-look.md` | Question-to-file map across the clones and wikis |
| `docs/crash-probing.md` | Reading the crash probe, isolating hangs, the incidents so far |
| `docs/review-brief.md`, `docs/reviews.md` | The source review brief and its verdicts |
| `docs/building.md` | Build host, toolchain versions, how each project builds, build records |
| `tools/windows/` | Toolchain check, framework builds, install with record, crash probe |
| `tools/wkit.sh` | WolvenKit CLI in a box |
| `patches/`, `locks/` | Our patches on upstream sources; xmake package locks of each build |
| `AGENTS.md` | Rules for agents working in this repository |

## Contributing

New facts, crash rules, source pins, reviews and build scripts are welcome as pull requests; `CONTRIBUTING.md` says
what goes where and the bar a fact has to meet. The skill asks your agent to offer back what it measures, so the usual
path is: your agent finds something, asks you, and opens the PR from your fork. New ready-made game calls and tool
changes go to [uvmod](https://github.com/glitchbunny0/unreal-vibe-modding).

## Legal

Not affiliated with or endorsed by CD PROJEKT RED. This repository holds only its own code and notes: the names of
game types and functions an agent calls, and how they behave, recorded for interoperability with a game the user
owns. It ships no game files, extracted assets or decompiled code. Everything under `refs/` is fetched from its
public upstream on your machine, keeps its own license (WolvenKit is GPL-3.0; CDPR's script and tweak sources are the
game's content, for study only) and is never redistributed here.

## License

MIT for the files in this repository; see `LICENSE`. The patch in `patches/` stays under its upstream's MIT license.
