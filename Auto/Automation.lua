-- Pause Automation: a bind, in the list Game Actions. One press pauses every automation feature of the addon, the next
-- press resumes them. One chat line each time. The player's settings are not touched: the pause is one saved value of
-- its own (Core/Registry.lua, Registry.Store), kept over a reload and a logout until the next press. A login while paused
-- says so in chat, so a player who forgot sees why nothing runs.
--
-- The rest of the addon asks Automation.Paused() before it acts, at the one place where each feature decides: Auto Sell
-- Junk and Auto Repair (Auto/Vendor.lua, Auto/JunkSell.lua), Restock, Auto Quest and Skip Gossip (Quests.Paused), Fast
-- Loot, Pass on Gear You Cannot Wear, Stay Seated While Eating, Auto Decline Duel and Auto Release. Each change also
-- sends the message "automation:paused" with the new value, for a part that shows it (the Info Bar) or lets go of
-- something at once (Stay Seated While Eating).
--
-- Nothing runs but at a press. The button is a secure button of ours, so Sticky Layers hears its press too
-- (Core/BindCore.lua), as Voice Transcription's. A press in combat works the same: it changes one value of ours.
local _, ns = ...

local Automation = ns.Module("Automation", { "secure" }, "Pause Automation")
ns.Automation = Automation

local BUTTON = "GamepadSuitePauseAutomation"
-- the game's own pause button, from its stopwatch
local ART = "Interface\\TimeManager\\PauseButton"

local store     -- the saved place of the pause; nil until login, and while this module is off

-- The bind list's entry (Core/Catalog.lua).
function Automation.Bind()
    return { kind = "command", id = "CLICK " .. BUTTON .. ":LeftButton", name = "Pause Automation", detail = "Press again to resume", icon = ART }
end

-- True while the player has paused automation.
function Automation.Paused()
    return store ~= nil and store.paused == true
end

local function press()
    store.paused = not store.paused or nil
    local paused = Automation.Paused()
    ns.Print(paused and "automation paused." or "automation resumed.")
    ns.Send("automation:paused", paused)
end

-- Reset All Settings (Settings/Data.lua): the pause goes too, with no chat line of its own (the
-- reset's line says it). True when automation was paused.
function Automation.Resume()
    if not Automation.Paused() then
        return false
    end
    store.paused = nil
    ns.Send("automation:paused", false)
    return true
end

function Automation.OnLogin()
    store = ns.Registry.Store("automation")
    if Automation.Paused() then
        ns.Print("automation is paused. Press Pause Automation again to resume.")
    end
    -- made out of combat: the game lets no addon set up a secure button in combat
    ns.Queue.Run("Automation", function()
        local button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function()
            ns.Call("Automation", press)
        end)
    end)
end
