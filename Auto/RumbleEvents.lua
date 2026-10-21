-- Rumble Events: the controller rumbles on game events that call for the player's eyes, which are
-- often away from a handheld's screen: a ready check, a group invite, a summon, a resurrection
-- offer, a whisper, the player's death, a loss of control (a stun, a fear), a level up, a duel or
-- a trade request. A row of the page Rumble Events turns each group on (the events and their
-- patterns are in RumbleModel.lua); the row Rumble sets the strength and Off. Events that come
-- together give one pattern (Rumble.Event). The first of each event goes in the log, so one play
-- tells which ones this game build sends. An event that a feature of the suite answers by itself
-- rumbles not: the question is gone before the player looks up (a duel with Auto Decline Duel on
-- and not paused, Auto/DeclineDuel.lua).
local _, ns = ...

local Events = ns.Module("RumbleEvents", { "rumble" }, "Rumble Events")
ns.RumbleEvents = Events

local told = {}

-- Some events also come for the player's own act: these say if one counts.
local COUNTS = {
    READY_CHECK = function(initiator)
        return not ns.Adapter.IsPlayer(initiator)
    end,
    CHAT_MSG_WHISPER = function(...)
        return not ns.Adapter.FromPlayer((select(12, ...)))
    end,
}

-- The events a feature of the suite answers by itself, while it does: the feature's name for the log.
local ANSWERED = {
    DUEL_REQUESTED = function()
        return ns.DeclineDuel and ns.DeclineDuel.Answers and ns.DeclineDuel.Answers() and "Auto Decline Duel"
    end,
}

function Events.OnLogin()
    for event, entry in pairs(ns.RumbleModel.EVENTS) do
        local function heard(...)
            if COUNTS[event] and not COUNTS[event](...) then
                return
            end
            local by = ANSWERED[event] and ANSWERED[event]()
            if by then
                if not told["answered " .. event] then
                    told["answered " .. event] = true
                    ns.Log.Add("rumble", "no rumble for " .. event .. ": a feature of the suite answers it (" .. by .. ")")
                end
                return
            end
            local on = ns.Registry.Get(entry.row)
            if not told[event] then
                told[event] = true
                ns.Log.Add("rumble", "an event came: " .. event .. " (row on: " .. tostring(on) .. ", controller in use: " .. tostring(ns.Adapter.PadActive()) .. ")")
            end
            if on then
                ns.Rumble.Event(entry.pattern)
            end
        end
        if entry.unit then
            -- (the game raises at a unit event it does not have)
            if not pcall(ns.OnUnit, event, entry.unit, "RumbleEvents", heard) then
                ns.Log.Add("rumble", "this game build does not send " .. event)
            end
        else
            ns.On(event, "RumbleEvents", heard)
        end
    end
end
