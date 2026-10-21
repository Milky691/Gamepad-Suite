-- Cancel: a bind, in the list Game Actions. One press stops the cast in progress, takes away the
-- targeting circle of a spell that waits for a place or a target, and drops the target.
--
-- The game does the three things, not the addon: the bind clicks one of the game's secure
-- buttons (Core/AdapterCancel.lua says why). So the bind works in a fight.
local _, ns = ...

local Cancel = ns.Module("Cancel", { "secure" }, "Cancel")
ns.Cancel = Cancel

local BUTTON = "GamepadSuiteCancel"
-- the game's own picture of a red cross on a button
local ART = "Interface\\Icons\\Misc_RnRRedXButton"

-- The bind list's entry (Core/Catalog.lua).
function Cancel.Bind()
    return { kind = "command", id = "CLICK " .. BUTTON .. ":LeftButton", name = "Cancel", detail = "Stops your cast and drops your target", icon = ART }
end

-- The button is made out of a fight: the game lets no addon set up a secure button in one. A
-- login in a fight makes it when the fight ends.
function Cancel.OnLogin()
    ns.Queue.Run("Cancel", function()
        local button, text, fromGame = ns.Adapter.CancelButton(BUTTON)
        -- The game's interface files do not have the command words. So the log keeps the words in
        -- use, and for the first three presses what the press left behind, a moment after it.
        ns.Log.Add("cancel", "the button runs " .. text .. " (" .. fromGame .. " of 3 words from the game's own list)")
        local logged = 0
        button:HookScript("PostClick", function()
            if logged < 3 then
                logged = logged + 1
                C_Timer.After(0.3, function()
                    ns.Log.Add("cancel", "a press left behind: " .. ns.Adapter.CancelLeft())
                end)
            end
        end)
    end)
end
