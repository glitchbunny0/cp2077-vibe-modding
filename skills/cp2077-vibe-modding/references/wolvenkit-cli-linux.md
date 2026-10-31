# WolvenKit CLI on Linux (10.0.0-beta.1)

## Version and licence

- Patch 2.5 needs WolvenKit 10.0.0-beta.1, the first release with 2.5 support. 9.1.0 predates 2.5.
- WolvenKit is community-made and is not CDPR. Its README says it shows how CDPR's engine reads and writes its formats. It is GPL-3.0.
- The Linux compressor `libkraken.so` is a reverse-engineered Oodle (Powzix's Kraken, GPL). Its compressor files are marked for educational use only. On Windows the CLI uses the game's own Oodle DLL instead. Check the terms before you redistribute any of it.
- It is framework-dependent: it needs the .NET 10 runtime.

## Running it boxed

- Run the CLI in a container with no network access, the CLI folder mounted read-only, and only a work folder writable.
- Give the container a dedicated work folder, never a repository root.
- `uncook` joins names taken from the archive into output paths without a guard against rooted or `..` paths. Run it only on archives you trust.
- `pack` deletes same-named targets in its output folder. Keep that folder free of anything you want to keep.

## Linux limits (measured)

- Texture conversion throws on non-Windows. A PNG to `.xbm` conversion needs the Windows CLI. Without textures, use flat colours as vertex colours or material parameters.
- `pack` silently skips files whose extension it does not know, and stores non-CR2W files raw. Name every file with its real game extension before packing.
- `import` on Linux drops the file extension. For example, the output was named `parts.`, with a trailing dot and no extension. Rename the file before packing.
- `convert serialize -o DIR` writes its output flat into `DIR`, not mirrored. Create `DIR` first.
- Every run warns "Oodle couldn't be loaded" on Linux. The warning is expected when Kraken is in use.
- Exit codes prove little. The CLI carries on past skipped extensions and dropped names. Check that each expected output file exists.
- Only `libkraken.so` and `libwwtools.so` load on Linux. The other native libraries are Windows-only.

## What was smoke-tested

- A CSV import to a CR2W `C2dArray`.
- `pack` with Kraken: one KARK block, 18.5 KB to 12 KB.
- `archive -l`, and `unbundle` producing a byte-identical file.
- `convert serialize` to JSON, which reported GameVersion 2500.
- A CLI call takes about 0.6 s.

## Kraken-packed archives

- Kraken-packed archives load in the game.
- Keep each mesh's render buffers under 256 KB. A mesh with larger buffers spawned but never rendered (see `custom-mesh-props.md`).
