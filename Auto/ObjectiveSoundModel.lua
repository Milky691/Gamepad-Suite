-- The rule of the quest objective sound, with no game calls. Auto/ObjectiveSound.lua looks at the quest log after each
-- change of it (Core/AdapterWorld.lua QuestStates) and plays what this file says.
local _, ns = ...

local Model = {}

-- What changed from one look at the quest log to the next. A look is { [quest number] = { done = the whole quest is
-- complete, [n] = objective n is done } }; before is nil for the first look. Gives "quest" when a quest became
-- complete, "objective" when an objective went from not done to done, nil when there is nothing to hear, and the
-- quest's number. One change gives one sound: the quest's wins. A quest that was not in the look before (the first
-- look, a new quest) only comes into the look: a quest that is done already when it comes makes no sound.
-- A quest the game completes by itself (auto in the look) makes no sound of ours when its last objective is done: the
-- game plays its own quest sound with its pop-up then (Blizzard_AutoQuestPopUpTracker.lua 34 to 37).
local function gameSounds(quest)
    if not quest.auto then
        return false
    end
    for _, done in ipairs(quest) do
        if not done then
            return false
        end
    end
    return true
end

function Model.Heard(before, now)
    local heard
    for id, quest in pairs(now) do
        local was = before and before[id]
        if was and quest.done and not was.done then
            return "quest", id
        end
        for n, done in ipairs(was and not gameSounds(quest) and quest or {}) do
            if done and was[n] == false then
                heard = id
            end
        end
    end
    return heard and "objective" or nil, heard
end

if ns then
    ns.ObjectiveSoundModel = Model
end
return Model
