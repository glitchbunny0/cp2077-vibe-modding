# Custom meshes and entities in the scene (WolvenKit CLI -> archive -> CET spawn)

Use this to put code-generated flat geometry into the world: depth-correct, covered by walls, NPCs and the first-person weapon. An ink or ImGui overlay is drawn over the finished frame and can never do that.

In this file, `wkit` stands for the WolvenKit CLI binary. Run it as described in `wolvenkit-cli-linux.md`.

## 1. Templates from the game's archives

- The CLI imports geometry over an existing game mesh. The entity is easiest to make by editing a game `.ent`. So fetch templates first.
- Copy the one archive you need from the game's `archive/pc` folder into the work folder. Do not mount the game folder into the container.
- `wkit archive X.archive -l` lists the paths. `wkit unbundle X.archive -o raw -r '<regex>$'` extracts matches. `wkit convert serialize F -o json` writes editable JSON (create the output folder first).
- Known-good templates in `basegame_4_gamedata.archive`:
  - mesh `base\environment\decoration\advertising\signage\neon_signs\neon_ai_off.mesh` (signages.mt local materials, three appearances);
  - entity `base\prefabs\environment\decoration\advertising\signage\neon_japanese_text\neon_karaoke_small_text_ball.ent` (no appearances; components: a transform animator, a placeholder, and one entMeshComponent bound to the animator).

## 2. Geometry to glb (standard library only)

WolvenKit's glb importer requires, per mesh:

- exactly one primitive;
- POSITION, NORMAL and TANGENT, and in practice TEXCOORD_0 too;
- at least one triangle;
- a node and mesh name of the form `submesh_NN_LOD_1`;
- fewer than 65,536 vertices.

Axes: glTF (x, y, z) becomes game (x, -z, y). A flat figure drawn in the glTF XY plane facing +z faces game -Y, with its feet at the origin. Use one submesh per material or colour.

- Stacked 2D layers: push each draw layer about 0.2 mm toward the viewer, or they z-fight.
- Many small details on one shape: put them all half a layer above it rather than a layer each, or the stack grows deep.
- Share vertices: one index per exact position, per submesh. Buffer size matters (see section 6).
- Verify before importing: rasterise the glb back to a PNG (sort triangles by depth) and look at it.

## 3. Import, materials and round trip

- Copy the template mesh to `cooked/<path>.mesh`, and put the glb at `raw/<same path>.glb`. Then run `wkit import raw -o cooked -k`. Without `-k` the CLI says "Direct mesh importing is not implemented".
- Always round-trip after importing: `convert serialize`, edit the JSON, then `convert deserialize`. The raw import output spawned no entity in game. The round-tripped files did.
- Materials are edited in the JSON:
  - `localMaterialBuffer.materials`;
  - `materialEntries` (name plus index, which is its position; `isLocalInstance` 1);
  - `appearances[].Data.chunkMaterials` (one name per chunk, in chunk order, which matches the glb mesh order).
- WolvenKit regenerates `rawData` and `rawDataHeaders` from `materials` when it writes.
- Several appearances on one mesh are cheap: one appearance per variant.

## 4. Entity

Start from the template:

- drop the animator and keep the placeholder;
- one entMeshComponent per mesh, each with a unique `id` and its own `name`;
- `parentTransform` null, `visualScale` 1, `meshAppearance` set to the variant, and `mesh` set to the DepotPath of your mesh.

Edit both the editor `components` list and the runtime `compiledData.Data.Chunks` (plus `CruidDict`). Set `resolvedDependencies` to your meshes. The writer derives CRUIDs from the chunks, so dropping a chunk is fine.

## 5. Pack, install and hot-swap

- `wkit pack pack -o out` names the archive after the folder. Rename it as needed.
- Install it as `<game>/archive/pc/mod/<name>.archive`.
- Archives load only at game start. Every content change otherwise costs a full restart. Batch variants into one archive, one `.ent` per variant, rather than restarting for each guess.
- **Hot swap with RedHotTools.** Upstream RedHotTools RC3 crashes 2.5 at start (upstream issue #21). The kit carries an archives-only port in `patches/red-hot-tools/`; its build recipe is in `docs/building.md`. Check it on your own setup before relying on it.
- Hot-swap recipe (measured with the port):
  1. Copy the new archive to `<game>/archive/pc/hot/<name>.archive.part`. The watcher ignores other extensions.
  2. Rename it to `<name>.archive`.
  3. Wait about 1 s, then read the newest RedHotTools log for `Archives reload completed.`
  4. Despawn and respawn the entity.
- A swap replaces the mounted archive. Entity paths missing from the new archive stop spawning. Entities already spawned keep the old mesh until they are respawned.
- Plain archives do not need ArchiveXL. The RedHotTools call to ArchiveXL's reload returns false without it.
- Stage the next archive as `<name>.archive.next` while the game runs, since the game ignores that extension. Rename it into place only after the game has closed.
- Entity paths are the contract between the archive and the CET spawner. When you rename a variant, change both sides and install both before the same restart.
- Ask the player before closing the game. Closing loses unsaved progress.
- If a new archive spawns nothing after a restart, check the game's start time against the time you staged the archive: a game started earlier still runs the old archive.
- Spawned props vanish when a save is loaded.

## 6. Spawn and judge

Spawn (measured pattern):

```lua
local wt = WorldTransform.new()
WorldTransform.SetPosition(wt, v4)
WorldTransform.SetOrientationFromDir(wt, Vector4.new(fwd.x, fwd.y, 0, 0))
local id = exEntitySpawner.Spawn("base\\x\\y.ent", wt, "", TweakDBID.new(""))
-- spawning is async: a few seconds later
local e = Game.FindEntityByID(id)
-- ... later
exEntitySpawner.Despawn(e)
```

- The entity's +Y axis follows the direction you pass, so a figure built to face -Y faces the opposite way. For a figure ahead of the player, pass the player's forward direction: the figure then faces the player.
- The menu keeps a player object at the world origin. After startup, wait until |x| + |y| > 50 before you spawn anything.
- Compare variants in one screenshot: lay them out in a row, 2.4 m apart, 8 m ahead, in a fixed order. Then measure the median colour of each figure's pixels per column band.
- Invisible mesh? Diagnose in one restart with a row of: the game's mesh through your `.ent`; the game's mesh repacked by you; your mesh raw; your mesh round-tripped; a 1 m quad; a small version of your mesh.
- **Render-buffer limit.** A mesh with a large amount of render buffer (vertex plus index buffer size) spawned but never rendered when packed on Linux with Kraken. The same art at about 207 KB rendered. Keep every mesh under 256 KB (one Kraken block). Split large art into several mesh components. The build should refuse any mesh over the limit. Whether the block size or a 32k-vertex chunk was the cause is untested.

## 6b. Runtime levers on a spawned prop (measured on 2.5)

- `entEntity:GetComponents()` is not exposed to CET. Use `FindComponentByName(CName)`.
- `component:Toggle(false)` and `component:Toggle(true)` work live: the mesh disappears and reappears.
- Components written with `isEnabled: 0` in the `.ent` load hidden. `Toggle(true)` shows them. `IsEnabled()` reads the state back.
- `SetLocalPosition` and `SetLocalOrientation` on an entMeshComponent return the new value, but nothing moved on screen. Untested: a setter followed by a Toggle refresh, and the template's transform animator (`gameTransformAnimationDefinition`, driven by `gameTransformAnimationPlayEvent`).
- `chunkMask = 1ULL` had no visible effect, even after a Toggle.
- Inconclusive: `entAppearanceEvent` (with `appearanceName` and `componentName`, sent via `e:QueueEvent`), and a live write to `visualScale`. The player was moving during those tests.
- Toggling many components many times a second is suspected in an open hang (`runtime-safety.md`); keep the rate low.

## 7. Flat colours with the neon material (signages.mt)

Pin these per material:

- `BlinkingMinimumValue` 1 and `LightupMinimumValue` 1: no neon flicker and no uneven tube.
- `FresnelAmount` 0: no rim light.
- `ColorOneStart` and `ColorOneEnd` set the colour. `EmissiveEV` sets the glow.

Measured behaviour of `EmissiveEV`:

- EV 0.1 or below: no glow. The colour is lit only by the scene and shifts with it (a pure red read about 45% as bright in shade as in light). This is not a flat look.
- EV about 0.2 and up: the colour glows, and the red channel clips almost at once. At EV 0.2 to 0.5 about 95% of the red channel clipped. At EV 3 red washed to pink-white.
- The shader adds scene light on top of the emission, so the same EV reads differently in sun and in shade.

Ways to stop a wash-out:

- White decorations glowing at the same EV bloom over the colours next to them. Give them their own mesh or appearance, with a lower EV.
- Saturated bright colours desaturate first. Dimming the emitted colour and raising EV slightly is the thing to try.
- If lighting must not touch the colour at all: an emission-only material (black albedo plus an emissive colour) is the next thing to try. Untested.

## 8. From a scratch pipeline to repo code

- Use one Python orchestrator over the CLI, not a shell script. After every CLI step, check that each expected output file exists, and check mesh buffer sizes against the 256 KB limit. Exit codes prove nothing (see `wolvenkit-cli-linux.md`).
- Prove a port against a hand-built version first: the same render-buffer sizes from a real build, then serialize the built mesh back and check its material values.
- Tests: run geometry tests on real generator output (winding, layer order, vertex sharing). Run material and entity edits on small synthetic JSON shaped like the template. Game files never enter a repository. Sabotage each guarded behaviour once and confirm its own test fails.
- Keep the glb writer on the standard library only, so the tests run anywhere the repository is cloned.
