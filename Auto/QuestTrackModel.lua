-- The rules of the bind Track Nearest Quest, with no game calls: which quest a press goes to.
-- A quest here is one entry of the adapter's list: { id =, title =, far =, here = }. far is the
-- distance to the quest's next step, squared, as the game gives it; nil for a quest with no
-- place on the map. here is true for a quest on the continent the character is on.
local _, ns = ...

local Model = {}

-- A press this many seconds after the one before, or sooner, goes on to the next quest.
Model.AGAIN = 10

-- The quests a press can go to, the nearest first. A quest with no place on the map is left
-- out. A quest of another continent comes after all quests of this one. Two quests at one
-- distance stay in the order of the quest log.
function Model.Near(quests)
    local near, place = {}, {}
    for i, quest in ipairs(quests) do
        if quest.far then
            near[#near + 1], place[quest] = quest, i
        end
    end
    table.sort(near, function(a, b)
        if a.here ~= b.here then
            return a.here
        elseif a.far ~= b.far then
            return a.far < b.far
        end
        return place[a] < place[b]
    end)
    return near
end

-- The quest for a press. near is Model.Near's list. tracked is the quest the game points at now.
-- last is the quest that the press before chose, and since the seconds since that press; both
-- nil for a first press.
--   A press gives the nearest quest.
--   When the game points at the nearest quest already, the press gives the next nearest: a
--   press that changes nothing tells the player nothing.
--   A press soon after the one before goes on from its quest: the next nearest, then the one
--   after it, and after the farthest the nearest again.
-- nil for an empty list.
function Model.Pick(near, tracked, last, since)
    local from = since and since <= Model.AGAIN and last or nil
    if not from and near[1] and near[1].id == tracked then
        from = tracked
    end
    for i, quest in ipairs(near) do
        if quest.id == from then
            return near[i % #near + 1]
        end
    end
    return near[1]
end

-- The distance in yards, for the log.
function Model.Yards(far)
    return math.floor(math.sqrt(far) + 0.5)
end

-- What stops a press: "none" (the quest log is empty), "place" (no quest of the log has a place
-- on the map), or nil.
function Model.Missing(quests, near)
    return not quests[1] and "none" or not near[1] and "place" or nil
end

-- What the chat says for each, one time.
Model.TEXT = {
    none = "Track Nearest Quest: your quest log is empty.",
    place = "Track Nearest Quest: none of your quests has a place on the map.",
    full = "Track Nearest Quest: your tracked list is full; the arrow still points.",
}

if ns then
    ns.QuestTrackModel = Model
end
return Model
