# On-screen messages and holocalls (2.5, measured)

## On-screen message at the top of the screen

Measured recipe:

```lua
local defs = Game.GetAllBlackboardDefs()
local msg = SimpleScreenMessage.new()
msg.message = "Text to show"
msg.isShown = true
msg.duration = 5            -- Float, seconds (the game's own scripts use 5.0 and 1.5)
Game.GetBlackboardSystem():Get(defs.UI_Notifications):SetVariant(defs.UI_Notifications.OnscreenMessage, ToVariant(msg), true)
```

- Send the same message with `isShown = false` to show nothing. The HUD recipe in `hud-and-ink.md` uses this to keep
  the game's own message from appearing.
- When the player is watching a live session, announcing each step this way works well: they see what the agent is
  about to do.

## Holocall (a call from a contact, with subtitles)

Measured with the in-game contact id `judy`; other contacts are untested. The call shows the game's own call UI with
the contact's avatar and name in the top left, and the lines appear as normal subtitles ("Name: text"). This is the
code that ran, with the contact made a parameter:

```lua
-- Find the contact by id. Assigning ctx.stateFilter.active directly writes to a copy and finds nothing:
-- build a fresh filter and assign it whole.
local jm = Game.GetJournalManager()
local ctx = JournalRequestContext.new()
local filt = JournalRequestStateFilter.new()
filt.active = true
filt.inactive = true
ctx.stateFilter = filt
local contact
for _, c in ipairs(jm:GetContacts(ctx) or {}) do       -- the array comes back directly
    local ok, id = pcall(function() return c:GetId() end)
    if ok and id == "judy" then
        contact = { id = id, name = Game.GetLocalizedText(c:GetLocalizedName(jm)) }
        break
    end
end

local function phone() return Game.GetScriptableSystemsContainer():Get("PhoneSystem") end

-- phase: "IncomingCall" (rings) | "StartCall" | "EndCall"; mode: "Audio" | "Video"
function CALL(phase, mode)
    local r = questTriggerCallRequest.new()
    r.caller = CName.new(contact.id)
    r.addressee = CName.new("player")
    r.callPhase = Enum.new("questPhoneCallPhase", phase)
    r.callMode = Enum.new("questPhoneCallMode", mode or "Audio")
    r.visuals = Enum.new("questPhoneCallVisuals", "Default")
    r.isRejectable = true
    r.showAvatar = true
    r.isPlayerTriggered = false
    phone():QueueRequest(r)
end

LINES, seq = {}, 0
function SAY(text, seconds)
    HIDE()
    seq = seq + 1
    local l = scnDialogLineData.new()
    l.id = CRUID(0x4A5544590000 + seq)          -- keep the number below 2^53: a Lua double holds it exactly
    l.text = text
    l.type = Enum.new("scnDialogLineType", "OwnerlessRegular")   -- other types need a speaker object
    l.speakerName = contact.name
    l.isPersistent = true
    l.duration = seconds or 5
    LINES = { l }
    local defs = Game.GetAllBlackboardDefs()
    Game.GetBlackboardSystem():Get(defs.UIGameData):SetVariant(defs.UIGameData.ShowDialogLine,
        ToVariant(LINES, "array:scnDialogLineData"), true)
end

function HIDE()
    if #LINES == 0 then return end
    local defs = Game.GetAllBlackboardDefs()
    Game.GetBlackboardSystem():Get(defs.UIGameData):SetVariant(defs.UIGameData.HideDialogLineByData,
        ToVariant(LINES, "array:scnDialogLineData"), true)
    LINES = {}
end

-- The quest fact the phone system keeps for this call: 0 Ended, 1 Initializing, 2 Talking, 3 Rejected.
function CALL_STATE()
    local name = Game.GetPlayer():GetPhoneCallFactName(CName.new(contact.id), CName.new("player"))
    return Game.GetQuestsSystem():GetFactStr(name)
end
```

- **Forced call** (measured, the simplest): `CALL("StartCall")` straight away. No ring, no pickup; the call is up.
- **Ringing call** (measured): `CALL("IncomingCall")`, then poll `CALL_STATE()` once per frame or slower (never in a
  loop inside one request) until it reads 2, the player picked up. Give up after a few seconds. A ring ended after
  about 3 s while the game window was not in front.
- **Hang up**: `HIDE()`, then `CALL("EndCall")`. The fact goes back to 0.
- Pace the lines yourself, from `onUpdate` or one request per line. Lines of 223 characters took 3 subtitle rows and
  232 characters 4 rows, both shown in full.
