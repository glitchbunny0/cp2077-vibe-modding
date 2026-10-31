# Contributing

Thanks for helping. This kit grows the way it was built: someone's agent measures something in the running game, and
it becomes a rule every other agent can use. Pull requests are welcome; so are issues when you found something but
can't open a PR.

## Where things go

| You have | It goes | In |
|---|---|---|
| A fact about the game or a framework, measured in the running game | the matching file in `skills/cp2077-vibe-modding/references/` (a new topic gets a new file and a row in `SKILL.md`'s routing table) | this repo |
| A rule that keeps the game alive (a call that crashes or freezes it) | `references/runtime-safety.md`, and the short list in `SKILL.md` if it is easy to hit | this repo |
| A crash or hang you isolated | a row in `docs/crash-probing.md`'s incident table, plus the rule above | this repo |
| An upstream source worth mirroring (repo or GitBook space) | `refs.toml`, then `tools/fetch_refs.py update --only NAME`; commit `refs.toml` and `refs.lock.json` together | this repo |
| A source review | a row in `docs/reviews.md` (brief: `docs/review-brief.md`) | this repo |
| A build script, or a patch to make an upstream project build or run on a new patch | `tools/windows/`, `patches/`, with a row in `docs/building.md` | this repo |
| A new ready-made game call (`uvmod cet NAME`), a uvmod command, a bridge change | see uvmod's [CONTRIBUTING.md](https://github.com/glitchbunny0/unreal-vibe-modding/blob/main/CONTRIBUTING.md) | uvmod |
| A mod | your own repository; open a PR here only for the facts you learned building it | elsewhere |

## The bar for a fact

A wrong fact in the skill crashes someone else's game, so:

- **Say how you know.** Tag it **measured** (it ran in the game), **static** (read from the scripts or the RTTI dump)
  or **untested**. A measured fact names the game patch and the CET version (and other frameworks it needs).
- **Show the call.** A short Lua snippet that ran, or the exact signature, beats a description.
- **Write rules, not stories.** The rule, then why. No session narrative, no dates of when you found it.
- **Generic engine behaviour, not mod design.** "Traffic lights are device entities, `ToggleLightEvent` switches their
  bulbs" belongs here; the tuned values and choices of one particular mod do not.
- **Names are guesses.** If a function's name and its behaviour disagree, the behaviour you saw wins; say so.
- **Patches change things.** If a fact changed with a new patch, keep both with their patch numbers until the old patch
  is gone.

## Checks

CI runs on every pull request: every git source in `refs.toml` is locked at a full commit, the PowerShell scripts parse,
`tools/*.sh` passes shellcheck, and every skill has its front matter and links every file in its `references/`. Run
`python3 tools/fetch_refs.py status` after changing a pin.

## What does not belong here

- Game files, extracted assets, decompiled game code, anything under `refs/`, or strings copied from the game's
  executable. Names of types and functions, and how they behave, are fine.
- Machine details: host names, user names, local paths, IP addresses.
- Story or quest content beyond the names a recipe needs (others may not have finished the game).
- Anything aimed at online play, other players' sessions, or getting around anti-cheat.

Contributions are accepted under this repository's MIT license.
