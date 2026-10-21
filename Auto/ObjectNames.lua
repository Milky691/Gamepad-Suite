-- Object Names: the name of the object in reach that can be used (a chest, a herb, a mailbox) shows above it, on the
-- game's own name plate. The game shows a name plate over the thing in reach while its setting for that is on, and its
-- gamepad mode holds the setting off (Blizzard_Gamepad/Core.lua 23). The owner wants the name for objects only, not for
-- people: the setting is on only while the thing in reach is an object, looked at again at each change of the thing in
-- reach (the game's event; no polling). Not changed in a fight, as the game can lock its name plate settings there: the
-- look comes again when the fight ends. Off gives the setting back once and then touches nothing of the game's.
-- InteractGlow sets the same setting of the game (for people too): while it is loaded, Object Names steps aside.
local _, ns = ...

local Names = ns.Module("ObjectNames", { "objectNames" }, "Object Names")
ns.ObjectNames = Names

local KEY = "screen.object_names"
local shown       -- what the row set last: true, false, or nil while it has set nothing
local told = false

local function look()
    if ns.Adapter.InCombat() then
        return
    elseif ns.Adapter.AddonLoaded("InteractGlow") then
        if not told then
            told = true
            ns.Log.Add("screen", "Object Names: InteractGlow is loaded and sets the name plates, so Object Names steps aside")
        end
        return
    end
    if not ns.Registry.Get(KEY) then
        if shown ~= nil then
            ns.Adapter.ObjectName(nil)
            shown = nil
        end
        return
    end
    local want = ns.Adapter.ObjectInReach()
    if want ~= shown then
        shown = want
        ns.Adapter.ObjectName(want)
        if want and not told then
            told = true
            ns.Log.Add("screen", "Object Names: an object is in reach, its name plate is on")
        end
    end
end

function Names.OnLogin()
    ns.On("PLAYER_SOFT_INTERACT_CHANGED", "ObjectNames", look)
    ns.On("PLAYER_REGEN_ENABLED", "ObjectNames", look)
    -- The game's controller interface came on (it sets its own 0 again) or went (it takes ours away), Blizzard_Gamepad/
    -- Core.lua 1 to 41: what the row set is gone. It is set again one frame after the game's word.
    ns.On("INPUT_DEVICE_INTERFACE_TRANSITION", "ObjectNames", function()
        shown = nil
        C_Timer.After(0, function()
            ns.Call("ObjectNames", look)
        end)
    end)
    ns.Listen("setting", "ObjectNames", function(key)
        if key == KEY then
            look()
        end
    end)
    look()
end
