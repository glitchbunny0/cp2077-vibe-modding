# cp2077-vibe-modding

Agent-driven modding for Cyberpunk 2077: the upstream tools and documentation an agent needs,
pinned and mirrored locally, and (next) a bridge that lets an agent read and drive a running game
the way `unreal-vibe-modding` does for Unreal titles.

**Status:** sources and docs gathered and indexed, first source reviews recorded, Windows build
toolchain installed and checked. Nothing third-party has been built or installed on a game
machine yet. Target: patch 2.5 (game version 3.0.88.46235).

## Layout

| Path | What |
|---|---|
| `refs.toml` | Every upstream source: repo or GitBook space, pin, group, why it is here |
| `refs.lock.json` | Resolved commits and mirror digests for the pins (generated, committed) |
| `tools/fetch_refs.py` | Clones and mirrors everything into `refs/` (stdlib Python + git) |
| `refs/` | The clones and doc mirrors (gitignored, never committed) |
| `docs/landscape.md` | What each tool does for an agent, where it runs, its 2.5 status, the gaps |
| `docs/where-to-look.md` | Question-to-file map across the clones and wikis |
| `docs/reviews.md` | Source review verdicts, required before anything third-party is built |
| `docs/building.md` | Build host, toolchain versions and how each project builds |
| `tools/windows/toolchain-smoke.ps1` | Checks the Windows toolchain with one hello world per build system |
| `AGENTS.md` | Rules for agents working here |

## Getting the sources

```sh
tools/fetch_refs.py sync                # everything at the locked commits (~370 MB)
tools/fetch_refs.py sync --with-heavy   # plus WolvenKit's source (~255 MB more)
tools/fetch_refs.py status              # compare refs/ with the lock
tools/fetch_refs.py update --only cet   # move one pin forward, rewrite its lock entry
```

`sync` is idempotent and skips anything already at its locked commit. GitBook spaces are
mirrored page by page from their `llms.txt` index (four spaces, about 790 pages).

## What is in refs/

Frameworks (CET, RED4ext and its SDK, redscript with its language server and debugger, TweakXL,
ArchiveXL, Codeware, RedHotTools, red-cli), agent-useful plugins (RedSocket, RedFileSystem,
RTTIDumper, RedMemoryDump, NativeDB with its 2.5 RTTI dump, red-lib), the existing agent bridges
(cet-mcp, wolvenkit-mcp, WkMCP), examples and typedefs, CDPR's script and tweak sources as REDmod
ships them, and the modding, scripting, WolvenKit and RED4ext wikis as markdown.

## License

MIT for the files in this repository. Everything under `refs/` keeps its own license and is not
redistributed here.
