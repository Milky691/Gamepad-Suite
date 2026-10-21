-- Skip Gossip: when an NPC's only choice opens a service (a vendor, a trainer, a flight master,
-- a guild charter, a bank) and the window has no quest, that choice is taken, so the service
-- opens at once. The service is known by the choice's picture (Auto/QuestsModel.lua); any other
-- choice, which can start an escort or an event, is never taken. Not inside a dungeon. Holding
-- View when the window opens pauses it, and with the game's controller interface on it acts only
-- while the dialogue view holds the talk (Auto/Quests.lua, Quests.Paused, says why). The choice
-- is taken inside the game's event, as the game's own window takes a lone choice
-- (GossipFrameShared.lua 191 to 199): the dialogue view then waits for the service to open. The
-- log (kind "gossip") says what was done, each reason to leave a window once.
local _, ns = ...

local Gossip = ns.Module("Gossip", { "gossip" }, "Skip Gossip")

local MAX_NOTES = 12
local lastId, lastTime, notes, told = nil, 0, 0, {}

local function note(text, once)
    if notes < MAX_NOTES and not (once and told[text]) then
        notes, told[text] = notes + 1, true
        ns.Log.Add("gossip", text)
    end
end

function Gossip.OnLogin()
    ns.On("GOSSIP_SHOW", "Gossip", function()
        if not ns.Registry.Get("helpers.skip_gossip") or ns.Adapter.InInstance() then
            return
        end
        local options, quests = ns.Adapter.GossipChoices()
        local choice, what = ns.QuestsModel.Skip(options, quests)
        local paused = choice and ns.Quests.Paused()
        if not choice or paused then
            note("left: " .. (paused or what), true)
            -- a choice that leads back to the same window is taken once, not again and again
        elseif not (choice.id == lastId and GetTime() - lastTime < 2) then
            lastId, lastTime = choice.id, GetTime()
            note("taken: the " .. what .. " (" .. tostring(ns.Adapter.ChooseGossip(choice)) .. ")")
        end
    end)
end
