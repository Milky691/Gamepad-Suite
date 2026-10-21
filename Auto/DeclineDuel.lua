-- Auto Decline Duel: when a player asks the character to duel, the duel is declined at once with the game's own call
-- for the Decline button of its question (Core/AdapterDeath.lua), and one chat line names who asked, so a duel the
-- player wanted is not lost without a word. Off at the start. Pause Automation stops it (Auto/Automation.lua).
--
-- The game's question is never hidden by the addon: the game hides it itself when the duel ends, and the decline
-- brings that end (Blizzard_Game/Mainline/EventImplementation.lua 432 to 435). A duel to the death of a Hardcore realm
-- (DUEL_TO_THE_DEATH_REQUESTED) is left to the player: the game does not hide that question at the end of a duel, and
-- such a duel is asked on purpose.
--
-- The work is one call at the game's event. The log (kind "duel") has the first three declines of a session: if the
-- call ran and if the game's question showed at that moment, then at the end of the duel how long the server took and
-- if the question is gone one frame later. That proves the decline in one try.
local _, ns = ...

local Duel = ns.Module("DeclineDuel", { "declineDuel" }, "Auto Decline Duel")
ns.DeclineDuel = Duel

local KEY = "helpers.decline_duel"
local MAX_NOTES = 3
local notes = 0
local declined          -- when the last duel was declined, while the log waits for its end; nil else

local live = false       -- the module runs: its check passed at login

local function on()
    return ns.Registry.Has(KEY) and ns.Registry.Get(KEY) and not ns.Automation.Paused()
end

-- True while a duel asked now is declined at once: Rumble Events gives such a duel no rumble (Auto/RumbleEvents.lua).
function Duel.Answers()
    return live and on() and true or false
end

function Duel.OnLogin()
    live = true
    ns.On("DUEL_REQUESTED", "DeclineDuel", function(name)
        if not on() then
            return
        end
        local ok, err = ns.Adapter.DeclineDuel()
        if ok then
            ns.Print("declined a duel from " .. (type(name) == "string" and name or "a player") .. ".")
        end
        if notes < MAX_NOTES then
            notes = notes + 1
            declined = ok and GetTime() or nil
            ns.Log.Add("duel", "a duel was asked: CancelDuel " .. (ok and "ran" or "was refused (" .. tostring(err) .. ")")
                .. "; the game's question showed then: " .. tostring(ns.Adapter.DuelAskShown()))
        end
    end)
    ns.On("DUEL_FINISHED", "DeclineDuel", function()
        if not declined then
            return
        end
        local after = GetTime() - declined
        declined = nil
        -- the game hides its question at this event too: one frame later the log looks
        C_Timer.After(0, function()
            ns.Log.Add("duel", string.format("the game ended the duel %.1f s after the decline; its question shows one frame later: %s",
                after, tostring(ns.Adapter.DuelAskShown())))
        end)
    end)
end
