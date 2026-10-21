-- Objective Sound: a switch. When an objective of a quest in the log is done, the game's own objective sound plays
-- (the one its quest tracker plays for a new objective). When the whole quest is complete, the game's "quest complete"
-- sound plays in its place. You hear it with your eyes on the fight. A quest the game completes by itself makes no
-- sound of ours at its last objective: the game plays its own with its pop-up.
--
-- Events only: after each change of the quest log (QUEST_LOG_UPDATE, as the game's own quest list) the log is read
-- again and held against the last read (Auto/ObjectiveSoundModel.lua). The first read, at login or when the row comes
-- on, only notes the log, so login makes no sound. Off lets the event go. The log (kind "questsound") has the first
-- three sounds.
local _, ns = ...

local Sound = ns.Module("ObjectiveSound", { "questSound" }, "Objective Sound")
ns.ObjectiveSound = Sound

local SOUNDS = { objective = "UI_QUEST_ROLLING_FORWARD_01", quest = "UI_AUTO_QUEST_COMPLETE" }
local NOTES = 3

local last          -- the last read of the quest log, nil before the first
local noted = 0

local function look()
    local now = ns.Adapter.QuestStates()
    local heard, id = ns.ObjectiveSoundModel.Heard(last, now)
    last = now
    if heard then
        ns.Adapter.Sound(SOUNDS[heard])
        noted = noted + 1
        if noted <= NOTES then
            ns.Log.Add("questsound", ("quest %d: %s (%s)"):format(id, heard == "quest" and "complete" or "an objective is done", SOUNDS[heard]))
        end
    end
end

local function follow()
    last = nil
    if ns.Registry.Get("feel.objective_sound") then
        ns.On("QUEST_LOG_UPDATE", "ObjectiveSound", look)
        look()
    else
        ns.Off("QUEST_LOG_UPDATE", "ObjectiveSound")
    end
end

function Sound.OnLogin()
    follow()
    ns.Listen("setting", "ObjectiveSound", function(key)
        if key == "feel.objective_sound" then
            follow()
        end
    end)
end
