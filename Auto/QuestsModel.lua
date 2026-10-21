-- The rules of Auto Quest and Skip Gossip, with no game calls: the one step to take at a window
-- of a talk, or none and why.
local _, ns = ...

local Model = {}

-- True for a quest that comes back: repeatable (the game's notes name it repeatable, its own gossip
-- window reads isRepeatable, Mainline/GossipFrame.lua 38), or a daily, weekly or scheduled one
-- (Enum.QuestFrequency 1 to 3; 0 is a one-time quest: QuestLogDocumentation.lua 1486 to 1496).
function Model.Repeats(quest)
    return quest ~= nil and (quest.repeatable or quest.isRepeatable or (quest.frequency or 0) ~= 0) and true or false
end

-- Auto Quest. kind is the window: "gossip", "greeting" (a quest list with no gossip), "offer",
-- "progress" or "handin". data is what the adapter read of it (Core/AdapterDialogue.lua:
-- DialogueGossip, DialogueGreeting, DialogueQuest). Gives the step and its value for
-- Adapter.DialogueDo, or nil and the reason in a few words for the log.
-- One step at a time: the next window of the NPC takes over, and its own event comes.
-- data.trivial: the offer is a grey quest, far under the player's level. data.full: the quest
-- log has no room ("20 of 20"). data.size and data.party: the quest's suggested group size, and
-- the player is in a group.
function Model.Step(kind, data)
    if kind == "gossip" or kind == "greeting" then
        -- a quest to hand in first, then a quest on offer that is not far under the player's level
        for _, row in ipairs(data.rows) do
            if row.ready then
                return row.act, row.id
            end
        end
        local why = "no quest to take or to hand in"
        for _, row in ipairs(data.rows) do
            if (row.act == "gossipOffer" or row.act == "greetOffer") and not row.dim then
                if data.full then
                    return nil, "the quest log is full (" .. data.full .. ")"
                elseif not Model.Repeats(row.quest) then
                    return row.act, row.id
                end
                -- (a quartermaster offers it at every visit: it stays on the list for A)
                why = "a repeatable quest: the player chooses"
            end
        end
        return nil, why
    elseif data.confirm then
        -- the game asks first: a quest that flags for PvP, or one that costs money at the hand-in
        return nil, "the game asks first (" .. data.confirm .. ")"
    elseif kind == "offer" then
        -- (a quest that the game took by itself only needs the window closed the game's way)
        if data.auto then
            return "ack"
        elseif data.trivial then
            return nil, "a grey quest: the player chooses"
        elseif data.full then
            return nil, "the quest log is full (" .. data.full .. ")"
        elseif (data.size or 0) > 0 and data.party then
            -- (an escort starts its walk at the accept: the others may still read or loot)
            return nil, "a group quest in a group: the player chooses"
        end
        return "accept"
    elseif kind == "progress" then
        if not data.completable then
            return nil, "the quest is not done yet"
        end
        return "complete"
    elseif #data.choices > 1 then
        return nil, "a choice of rewards: the player chooses"
    end
    -- the number the game's own button sends: 0 with no choice, 1 for the one choice
    -- (Mainline/QuestFrame.lua 151 to 166, QuestInfo.lua 1056)
    return "reward", #data.choices
end

-- Skip Gossip. The pictures of a choice that only opens a service, as the game gives them on
-- this game build (each seen there at more than one NPC with other words: ForeverPlus's notes of
-- 2026-09-20 and 09-27): vendor, trainer, flight master, guild charter, bank. A plain choice has
-- a picture of its own (132053), the kind that can start an escort or an event: it is never taken,
-- and neither is a picture that is not in this list. Nor are the spirit healer and the innkeeper.
Model.SERVICE = { [132060] = "vendor", [132058] = "trainer", [132057] = "flight master", [132055] = "guild charter", [132050] = "bank" }

-- The choice to take, or nil and why. options: the NPC's choices ({ id, place, icon }); quests:
-- how many quests the window offers or takes.
function Model.Skip(options, quests)
    if quests > 0 then
        return nil, "the window has a quest"
    elseif #options ~= 1 then
        return nil, #options .. " choices"
    elseif not Model.SERVICE[options[1].icon] then
        return nil, "the one choice is no service (picture " .. tostring(options[1].icon) .. ")"
    end
    return options[1], Model.SERVICE[options[1].icon]
end

if ns then
    ns.QuestsModel = Model
end
return Model
