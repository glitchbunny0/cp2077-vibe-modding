# HUD, ink widgets, ImGui and the camera (2.5, measured with CET only)

## What draws and what does not

| Thing | Result on 2.5 |
|---|---|
| `inkImage` with a copied `textureAtlas` and `SetTexturePart` | draws |
| `inkShape` preset, Fill | draws |
| `inkShape` preset, Border | draws the preset as an open polyline |
| `inkRectangle`, `inkText` | draw |
| `inkShape` with a `vertexList` written by a script | does not draw |
| `inkQuadShape` with a copied atlas part and four vertices | does not draw |
| `inkVectorGraphicWidget:LoadSVG(path)`, absolute or mod-relative | no error; nothing drawn |

- `inkShape` draws only the named preset of its `shapeResource` (an `inkShapeCollectionResource`). `ChangeShape(name)` loads that preset and copies its points into `vertexList`.
- A script-written `vertexList` never reaches the screen: not without a resource, not before the first draw, not after it. `ChangeShape` to an unknown name keeps the old preset.
- Consequence: runtime vector art does not work from CET. 2D art on the HUD has to come from images (atlases) and preset shapes, moved with widget transforms.
- Untested: custom `.inkshapes` libraries or `.inkatlas` resources built with WolvenKit, custom resource paths loaded from CET, and concave preset fills.
- Widgets that construct from CET: `inkImage.new()`, `inkVideo.new()`, `inkShape.new()`, `inkVectorGraphicWidget.new()`.

## HUD root, without Codeware and without a mod reload

Measured: this works in a running game.

```lua
ObserveAfter("OnscreenMessageGameController", "OnScreenMessageUpdate", function(self)
    hudController = self  -- the callback only keeps a reference
end)
```

- Then set `UI_Notifications.OnscreenMessage` to a `SimpleScreenMessage` with `isShown = false`, so the game's own message does not show (`messages-and-calls.md`).
- `hudController:GetRootWidget()`, then `GetParentWidget()` three times, returns the HUD `Root` canvas. It measured 3840x2160 nominal, with 64 children.
- Codeware's `GetInkSystem` is a Codeware API. You do not need Codeware for this route.
- To find a HUD ink shape, walk the children with `GetWidgetByIndex` and match names. Examples measured: a widget named `selection_bg`, a preset named `dialogItem`, and a shape with five vertices in pixel coordinates.
- Script aliases that exist: `inkRectangle` (not `inkRect`), `inkCanvas`, `inkText`, `inkImage`, `inkShape`, `inkQuadShape`.
- Coordinates: at a 1440-pixel-high window the HUD units mapped about 1:1 to pixels, so content with y beyond about 1400 fell off the screen. Measured at one window size; check at yours.
- Remove test widgets with `hud:RemoveChild(w)`. They also vanish on a restart.

### Per-frame transforms

- `SetRotation`, `SetScale`, `SetShear` and `SetTranslation` on a widget, around `SetRenderTransformPivot(0.5, 0.5)`: eight calls in one frame took under 1 ms.

### Untested: projected world HUD

- `inkProjectedHUDGameController.RegisterScreenProjection` is native and protected. It needs a redscript subclass or a hooked instance. Not tested from CET.

## Ink effects

- Names from the 2.5 set, for use with `AddEffect` and `SetEffectEnabled`: ScanlineWipe, LinearWipe, RadialWipe, LightSweep, BoxBlur, Mask, Glitch, PointCloud, ColorFill, InnerGlow, ColorCorrection, Multisampling, Blackwall.
- Their behaviour is untested in this kit.

## Camera projection

- `Game.GetCameraSystem()` gives the camera API.
- `ProjectPoint(Vector4)` returns NDC: x and y run from -1 to 1. The returned `w` is 1 for a point in front of the camera and 0 for a point behind it. `w` is not a depth.
- `IsInCameraFrustum` takes three arguments.
- `GetActiveCameraFOV()` returns the field of view. `GetAspectRatio()` returns the real aspect ratio, which can be wider than 16:9.
- To size something by distance, derive the scale as K / distance. K is pixels per metre times the distance, both measured at the target.

## ImGui drawing (CET overlay)

- In `onDraw`, paint on ImGui's background draw list. CET's ImGui binding takes colours as plain integers. Pass an ABGR value as a signed 32-bit integer: subtract 2^32 when the top bit is set.
- Projecting an entity to the screen each frame and painting shapes on that list works (measured).
