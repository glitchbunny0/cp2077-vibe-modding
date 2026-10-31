# Review brief: read-only security review of third-party source

The brief every third-party repository went through before anything from it was built or installed on the game
machine (verdicts: `docs/reviews.md`). Give it to a read-only agent session or subagent, with the `<...>` parts filled
in, one session per 6-7 repositories, all in parallel, and ask for a structured answer such as
`{repos: [{repo, verdict, findings: [..]}], summary}`. Build nothing until every verdict is in, and read each
SUSPICIOUS hit yourself in the source before recording it.

Put a mod and the framework it runs inside (CET, RED4ext) in the SAME review, or state the framework's wrapper
semantics in the brief: a reviewer who sees only the mod judges its file and process calls by plain Lua rules and gets
the scope wrong in both directions (CET wraps `io.open`/`os.remove`/`os.rename` to the mod's folder but hands
`io.input`/`io.output` through unwrapped). Also ask for every build-time fetch at a commit other than the pinned refs
(FetchContent tags, submodule SHAs) so those commits get a row too.

---

You are reviewing third-party open-source <kind of project, e.g. RED4ext plugins: a DLL loaded by RED4ext
inside the game process, plus sometimes Lua or redscript files> for malicious or dangerous code. The owner wants to
build these from source and run them on their machine, and asked for a malware check first.

Repos are cloned (shallow, read-only use) under <dir>/<owner>__<repo>/. Your repos and the part that
matters (from an earlier census; verify, it may differ):
1. <owner>__<repo> (<mod dir>; <notes: networking expected for a multiplayer/admin mod, so judge where it
   connects; huge repo, so check only this subtree plus whatever it builds from>)
2. ...

STRICT RULES: read-only. Do NOT build, run, execute, import or source anything from these repos (no
cmake, cargo, npm, or python/ps1/bat/sh/node from them). Do not fetch URLs found in them. Use read_file,
search_files, and terminal only for grep/find/file/wc/strings-style inspection. Do not modify the repos.

CHECK, in each repo:
A. Build-time risk (we will run its build scripts in a container): CMakeLists.txt / *.cmake / xmake.lua /
   build.rs / build scripts: execute_process, file(DOWNLOAD), FetchContent/ExternalProject URLs (list
   them), add_custom_command running scripts, pre/post-build steps, paths outside the build tree.
   Committed binaries (.dll .exe .lib .a .obj .so .pyd .node, large blobs): list them with size, and say
   whether the build links or uses them.
B. Runtime behaviour of the code and of any scripts the mod installs: network (sockets, WinHTTP/WinINet/
   curl, listeners and their bind address/port, hosts contacted), process creation (CreateProcess,
   ShellExecute, system(), WinExec, popen, os.execute, io.popen), download-and-execute, LoadLibrary of
   non-system paths, registry/persistence (Run keys, scheduled tasks, services, startup folder),
   writes/deletes outside the game/mod folder, credential/token/cookie/clipboard access, keylogging beyond
   normal keybinds, anti-debug/obfuscation, encoded blobs decoded at runtime, crypto-mining, telemetry.
   Judge each hit against the mod's stated purpose: an admin HTTP server on localhost is expected, while a
   0.0.0.0 bind or an unknown host is a finding.
C. Build shape in one line: a template mod that links the host library (`set(TARGET X)`,
   `add_library(X SHARED)`, `target_link_libraries(X PUBLIC RED4ext.SDK)`), its own copied ABI header, or
   another build system.

Be efficient: grep for the indicator APIs first, then read the hits in context. Vendored upstream
libraries (sol2, nlohmann json, imgui, lua sources) may be skipped after you confirm the path and the
header comment, but name the ones you skipped.

FINAL ANSWER, per repo:
REPO <name> @ <git short sha>: CLEAN | SUSPICIOUS | MALICIOUS
- build-time: <findings or 'nothing beyond normal cmake'>, fetch URLs: [...], committed binaries: [...]
- runtime capabilities: <network/process/file/registry facts with file:line>
- findings needing a human look: <file:line + why> (or none)
- template: <one line>
End with a 2-line overall summary. No claim without file:line evidence.
