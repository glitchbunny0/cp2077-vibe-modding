# Skinned meshes, custom rigs and animgraphs driven from CET (2.5, measured)

Proved on a 2 m, two-colour strip with four bones. The graph bent the strip every frame, and script-set angles landed exactly. Example: a bone angle of 40 degrees put the next joint at 0.5 (sin 40, 1 + cos 40), which is (0.321, 0.883).

## Mesh

- Make a glb with one skin. Its joints are root-level nodes with identity rotation. Each joint's translation is its bind position: WolvenKit reads each joint's local transform as the bone's model-space bind.
- Axes: glTF (x, y, z) becomes game (x, -z, y).
- Vertex data: JOINTS_0 as u16, plus WEIGHTS_0.
- Import with `-k` over a bone-less template (the neon template in `custom-mesh-props.md`). WolvenKit 10 beta adds the mesh bones (`boneNames`, `boneRigMatrices`, `bonePositions`), vertexFactory 3 and the skin layout.
- Two materials render skinned (measured): `engine\materials\metal_base.remt` (BaseColor `base\materials\placeholder\white.xbm` plus a `BaseColorScale` Vector4), and signages.mt.

## Rig (.rig JSON)

- Any small game rig can serve as the template, for example `base\items\interactive\electronics\int_electronics_001.rig`.
- Fields: `boneNames` (Root, Trajectory, then yours), `boneParentIndexes`, and `boneTransforms`, which are local QsTransforms. Root has translation W = 1; the other bones have W = 0.
- Mesh bones map to rig bones by name.
- WolvenKit's glb-to-rig import is work in progress. Write the rig JSON yourself.

## Animgraph (JSON, built in code)

Shape taken from the game's `fan.animgraph` and `projectile_base.animgraph`.

- `Root.nodes` lists the Output first.
- Chain: ReferencePoseTerminator, then RotateBone (bone, axis, angleNode, `useIncrementalMode` 0, `clampRotation` 0), then more RotateBone nodes, then Output.
- **`nodesToInit` must list every reachable node**: Root first, then parents before children. An empty `nodesToInit` makes the graph silently inert. The mesh holds its bind pose and no error appears anywhere.
- Emit handles in WolvenKit's key order: `$type` first, then the rest alphabetically. `nodesToInit` comes before `rootNode`, so Root is defined there. `rootNode` is a HandleRefId.
- RotateBone angles are in degrees. The axis is in the bone's local space. For identity bones, `Y_Axis` is game Y, which bends the figure in its own plane when it faces -Y.
- `animAnimNode_FloatTimeDependentSinus` (`min`, `max`, `frequencyFactor`) moves with no input at all. Use it as a self-test.
- Measured: its value is (min + max) / 2 + (max - min) / 2 * sin(frequencyFactor * t + phaseFactor). `frequencyFactor` is in radians per second. A fit over 48 s had a residual of 0.8 deg^2. So an idle loop can run inside the graph with no per-frame script.
- `animAnimNode_DampFloat` (`inputNode`, `defaultIncreaseSpeed`, `defaultDecreaseSpeed`, speed links null, `wrapAroundRange` 0) eases a variable toward a newly set value. A speed of 180 deg/s gave a pose change over about 0.4 s.
- `animAnimNode_FloatMathOp` with `operationType` `AGMO_Add` or `AGMO_Multiply` (enum `animEAnimGraphMathOp`) sums or scales values.
- A negative amplitude: use a positive amplitude and phase + pi. A minimum above the maximum is untested.
- Scale check: 48 bones, each with a variable, a DampFloat and a RotateBone, plus 21 sinus nodes and 36 math nodes (206 nodes in `nodesToInit`), ran fine.

## Entity

- `entAnimationControllerComponent` named `animController`.
- `entAnimatedComponent` named `anim`: rig, graph, and `controlBinding` set to an `entAnimationControlBinding` that points at `animController`.
- `entSkinnedMeshComponent`: `skinning` set to an `entSkinningBinding` that points at `anim`, and `parentTransform` null.
- An entEntity root works; a gameObject root also works.
- Copy the component JSON from a device `.ent` that has an animated part, for example `base\gameplay\devices\home_appliances\fans\air_conditioning_1.ent`.

## Inputs from CET

Both routes were proved, and any number of inputs can be used.

- **Float variables.** Declare a `variables.floatVariables` entry (`animAnimVariableFloat` with name, min, max and default), and read it with `animAnimNode_FloatVariable`. Set it from CET:

```lua
local ev = AnimInputSetterFloat.new()
ev.key = CName.new("my_angle_1")  -- any name you declare in the graph
ev.value = 40
ent:QueueEvent(ev)
```

- **Animation features.** Declare an `animFeatures` entry with `name` and `className`, and read a field with `animAnimNode_FloatInput` (`group` = the feature name, `name` = the field). Send `AnimInputSetterAnimFeature` with `key` and `value = AnimFeature_X.new()`. Features are limited to the fields of existing script classes.

## Reading the pose back

- Add an entSlotComponent with `parentTransform` set to an `entHardTransformBinding` that points at `anim`. Each slot carries a `boneName`.
- Call `slot:GetSlotTransform(CName.new("s_b2"))` with one argument. It returns the transform. Then convert it:

```lua
local ok, wt = slot:GetSlotTransform(CName.new("s_b2"))
local pos = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(wt))
```

- This reads the animated pose, not the bind pose.

## Hot-loading while iterating

- New resource paths and a new archive name for each iteration hot-loaded cleanly through the hot-swap route (`custom-mesh-props.md`, section 5). This was measured without a restart.
