# patches

Our patches on upstream sources, applied by the build scripts in `tools/windows/` to a fresh checkout of the pinned
commit. Each patch stays under its upstream's license (both below are MIT, by psiberx); why each exists and what it
changes is its row in `docs/reviews.md`.

| Patch | On | Applied by |
|---|---|---|
| `red-hot-tools/de93c5696f-archives-only-2.5.patch` | psiberx/cp2077-red-hot-tools `de93c5696f` (rc.3), with `lib/Red` synced to psiberx/red-lib `398a7104a5` | `tools/windows/build-red4ext-rht.ps1` |
