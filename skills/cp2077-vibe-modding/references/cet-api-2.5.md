# CET API on patch 2.5 (CET 1.38.1)

Calling conventions and working snippets. Items are measured on 2.5 with CET 1.38.1 unless marked static or untested. Check every name in the 2.5 dump before you use it (`engine-sources.md`).

## Calling conventions

- **Out parameters come back as extra return values, success first.** `local ok, items = ts:GetItemList(player)`. The same holds for `GetTargetParts`.
- **Static calls that take a struct change it in place.** `WorldTransform.SetPosition(wt, v4)`, `WorldTransform.SetWorldPosition(wt, wp)` and `WorldPosition.SetVector4(wp, v4)` write into the struct they are given.
- **TweakDB record lookups need the full record type.** `TweakDB:GetRecords` needs a name such as `gamedataItem_Record`.
- **`Game.GetRTTISystem` does not exist on 2.5.** Use `tostring(DumpType(name, false))` and parse the text.
- **`NameToString` is a global function** that turns a CName into text.
- **64-bit values are LuaJIT cdata.** Entity ids and some quantities arrive as cdata. Call `tonumber()` on them before arithmetic.
- **Enum values** need the care in `runtime-safety.md` (rule: `EnumInt` only on enums).

## Names and text

- A record's `DisplayName()` returns a LocKey CName, not text. Resolve it with `Game.GetLocalizedTextByKey(record:DisplayName())`. The value `None` means the record has no name.
- An entity's `GetDisplayName()` is often `LocKey#N` or a secondary key. `Game.GetLocalizedText(s)` resolves both and returns plain text unchanged.

## Player state

```lua
local p = Game.GetPlayer()  -- nil in menus and on loading screens: check first
local eddies = Game.GetTransactionSystem():GetItemQuantity(p, MarketSystem.Money())
```

District and wanted level (measured):

```lua
local prevention = Game.GetScriptableSystemsContainer():Get("PreventionSystem")
local district = Game.GetLocalizedText(prevention:GetCurrentDistrict():GetDistrictRecord():LocalizedName())
local heat = EnumInt(prevention:GetHeatStage())  -- GetHeatStage returns an enum value, so EnumInt is safe here
```

Zone: read the `Zones` variable (type `gamePSMZones`) of the PlayerStateMachine blackboard.

Tracked quest (sketch of the measured walk): take the tracked entry from the journal manager, then walk up with `GetParentEntry()` until the entry is a `gameJournalQuest`. Bound the walk:

```lua
local entry = Game.GetJournalManager():GetTrackedEntry()
for _ = 1, 10 do              -- bounded (rule 1)
  if entry == nil then break end
  -- stop here when entry is a gameJournalQuest (test the type with IsA)
  entry = entry:GetParentEntry()
end
```

## Targets and nearby entities

- Build the query with `TargetSearchQuery.new()`, set `testedSet = TargetingSet.Complete`, and run it with
  `Game.GetTargetingSystem():GetTargetParts(player, query)`, which hands back `ok, parts` (out parameter).
- `Game['TSQ_ALL;']()` tests only the Visible set and often returns 0 hits. Do not use it for "what is nearby".
- The result can list one entity several times (one part per component). Dedupe by `GetEntityID().hash`, skip the player, and classify with `IsA`.
- What the player is looking at: `Game.GetTargetingSystem():GetLookAtObject(p, false, false)`.

## Stats

- `GetStatPoolValue(id, pool)` without the `perc` argument returns a percent, not the value. Pass `false` as `perc` to get the absolute value.

## Weather

- 2.5's weather system has no state getter and no setter (`GetWeatherState` and `SetWeather` are absent; rain only). Do not try to set weather.

## Hooks and events (CET's documented API; rules in `runtime-safety.md`)

- `Observe` is the same as `ObserveBefore`. `ObserveAfter` runs after the original function.
- `Override` replaces the function and passes the original in.
- `NewProxy` builds script callback objects.
- Events: `onInit`, `onUpdate` (runs on the main thread every frame), `onDraw`, `onShutdown`.

## Checklist for a new call

1. The name exists in the 2.5 dump (`DumpType` at runtime, or the text dump offline).
2. Out parameters are read as extra returns, success first.
3. `EnumInt` is only called on enum values.
4. Every loop has a bound.
5. Nothing here changes the save or the install unless the player said so.
