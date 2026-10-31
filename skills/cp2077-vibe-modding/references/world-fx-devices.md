# World: raycasts, effects and devices (2.5)

## Raycasts

- Measured: `Game.GetSpatialQueriesSystem():SyncRaycastByCollisionGroup(from, to, group, false, false)`, where `from`
  and `to` are Vector4 (w = 1) and `group` is `"Static"`, `"Terrain"` or `"Vehicle"`.
- It returns `hit, trace`: `hit` is true when the ray hit something; `trace.position` and `trace.normal` are Vector3.
- City ground is in the `"Static"` group. `"Terrain"` misses it.
- For an "is this point in view" check, cast from the camera (`GetActiveCameraWorldTransform`) and stop the ray a
  little short of the point, so the thing you test does not block its own ray.

## Effects (FxResource and FxSystem)

Measured recipe:

```lua
local r = FxResource.new()
r.effect = "base\\fx\\...\\x.effect"   -- CET hashes this path string
local wp, t = WorldPosition.new(), WorldTransform.new()
WorldPosition.SetVector4(wp, v4)      -- statics write into the struct they are given
WorldTransform.SetWorldPosition(t, wp)
local fx = Game.GetFxSystem():SpawnEffect(r, t, true)  -- returns an FxInstance
-- fx:IsValid() is false right after the spawn (the load is async); about 0.5 s later it is true
fx:Kill()                                 -- ends the effect
```

- Find effect paths by searching the game's scripts and tweak sources for `base\fx\` and `.effect` (about 400 matches
  in the 2.31 sources).
- Identity orientation looked right for effects placed on the ground.
- Kill what you spawn, and cap how many effects live at once.

## Lights

- Traffic lights and crossing lights are device entities. A `TargetingSet.Complete` query finds them under the classes
  `TrafficLight` and `CrossingLight`. The entity origin is at the light head.
- Street lamps are not entities. They are baked scenery, and CET cannot reach them.
- `FlickerEvent` (from `LightComponent.SetFlickerParams`), queued on a light entity: no visible change (measured).
- What works (measured): queue `ToggleLightEvent` with `toggle` on the entity to switch all its bulbs off, and again to
  switch them on.
- Restore a traffic light with `e:DetermineLightsFixedState()`. It is protected, but CET can call it, and it shows the
  current colour again. Other light devices: toggle back to the device's `GetDevicePS():IsON()` state.

## Screens and glitches

- Queue `QuestStartGlitch.new()` on a device entity to make it glitch, and `QuestStopGlitch.new()` to stop it
  (measured on vending machines). The device's base handlers call its own `StartGlitching(DEFAULT)` and
  `StopGlitching`.
- Device classes that override the glitch with a visible result (static, from the scripts): TV, LcdScreen,
  BillboardDevice, RetractableAd, ArcadeMachine, VendingMachine, Terminal (and Computer), Jukebox, Radio, Speaker,
  Intercom, NcartTimetable, HoloTable, DataTerm. Other classes: untested.
