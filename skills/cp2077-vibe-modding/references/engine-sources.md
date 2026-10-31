# Engine sources: where the 2.5 truth lives

Use this before any capability question: "can CET do X", "does the engine have Y", "is Z implemented natively". Upstream mirrors of CDPR's scripts and tweaks stop at patch 2.31, so 2.5 needs local copies.

## Sources for 2.5

| What | Where | Notes |
|---|---|---|
| 2.5 script source | `tools/redmod/scripts/` in the game folder (from a 2.5 install), or decompile the game's `r6/cache/final.redscripts` with redscript | `.script` files, CRLF line endings. Diff with `diff -rq --strip-trailing-cr`. |
| 2.5 tweak source | `tools/redmod/tweaks/` in the game folder | Same method as the scripts. |
| 2.5 RTTI text dump | One file per class, with its parent chain and natives. Also `globals.txt`. | `import function` marks a native function registered in RTTI. Best for "does this class exist, and what is its signature". |
| 2.5 RTTI JSON | `refs/nativedb/src/assets/reddump/*.json`, from `tools/fetch_refs.py sync` | Compact keys (see below). |
| C++ type layouts | `refs/red4ext-sdk/include/RED4ext/Scripting/Natives/Generated/` | For native types. |

- Read the game folder's `tools/redmod/` read-only. Copy it out; do not run anything from it.
- The RTTI text dump ships as a zip with LZMA entries. Extract it with Python's `zipfile`. Info-ZIP's `unzip` skips LZMA entries: it reports "need PK compat. v6.3" and exits with 81, and leaves a tenth of the files out.
- The kit's notes do not say which tool produced the text dump. Treat the dump as the 2.5 reference and record its provenance when you publish a result.
- Before you name a function in code, grep it in the 2.5 dump or script source.
- Tag each claim you make from these sources: VERIFIED-IN-SOURCE (with file and line), DOCUMENTED, or INFERRED.

## RTTI names are not behaviour

- A name in the RTTI proves the type is registered. It does not prove that working code is behind it.
- To check whether a subsystem is native, read the release executable (below).
- A name is a guess about behaviour until a trace confirms it.

## Is a subsystem native? Read the executable

1. Copy the release executable (`<game>/bin/x64/Cyberpunk2077.exe`, about 67 MB) to a scratch folder. Never publish the executable or any strings taken from it.
2. Extract the strings in both encodings: `strings -n 6 exe` for ASCII and `strings -n 6 -el exe` for UTF-16LE.
3. Assert messages carry CDPR source-file paths. Count those paths per module to see which native modules are compiled in.
4. Runtime log and assert strings next to a symbol name show what the code does. Neighbouring strings usually belong to the same class or config group. Find the symbol with `grep -n`, then print a window around it with `sed -n`.
5. Imports: parse the PE import table with Python's `struct` module. The DOS header holds the PE header offset at 0x3c. The data directory at index 1 lists the import descriptors. Ordinal imports have the top bit set.
   - WS2_32 ordinals: 1 accept, 2 bind, 13 listen, 17 recvfrom, 20 sendto, 23 socket, 115 WSAStartup.

## Does a resource ship? Read the archive indexes

- Archives index files by the FNV-1a 64-bit hash of the path (lowercase, backslashes).
- Header, 40 bytes: magic `RDAR` (u32 value 1380009042), version u32, indexPosition u64, indexSize u32.
- Index: fileTableOffset u32, fileTableSize u32, crc u64, count u32, segCount u32, depCount u32. Then `count` entries of 56 bytes each, starting with the u64 name hash. The layout follows WolvenKit's `ArchiveReader.cs`.
- Reading only the indexes of a full set of archives takes seconds.
- Always include known-present control paths in a lookup. Then a miss means something.

## Reflection JSON (NativeDB dump) keys

- Class: `b` is the name, `a` the parent, `e` the properties, `f` the functions.
- A function entry omits `b` when it equals `a`. Look it up with `f.get('b', f['a'])`.
- Some entries have no `b` at all. Use `.get` everywhere.
- `JournalManager` is not in the dump. Its native name is `gameJournalManager`.

## Modding documentation: what is current

- No current public CET Lua typedefs exist. The last public set covers CET 1.27 and patch 2.01. The 2.5 RTTI dump is enough to generate fresh LuaLS definitions.
- The old GitHub wikis of CET (2020) and redscript (2021) are stale. The GitBook "Scripting Cyberpunk" space replaced them; prefer it.
- For a question-to-file map, see the kit's `docs/where-to-look.md`.

## Briefing a subagent for static analysis

Subagents start blank. Each brief should carry:

- the paths above (scripts, RTTI text dump, and the kit's `docs/where-to-look.md`);
- when snippets are wanted, the CET facts and the crash and hang rules from `runtime-safety.md`;
- the rule: grep every API name in the 2.5 dump or scripts before naming it, and tag each claim VERIFIED-IN-SOURCE, DOCUMENTED or INFERRED with file and line;
- read-only work; any clones go in a scratch folder;
- a request for the full report in a scratch file and a short summary back.
