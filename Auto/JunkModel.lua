-- The rules of Quest Item Guard and Mark Junk, with no game calls: what a quest needs, the mark of
-- junk, what Auto Sell Junk sells for a mark, a sale seen in the vendor's buyback list, and the
-- words of the chat lines and of the tooltip's line.
--
-- A quest needs an item when an objective of the kind "item" names it ("Linen Cloth: 3/10"),
-- finished or not: the items go to the quest giver at the hand-in. The whole name must match.
-- A thing in the bags: { bag, slot, id, name, count, quality, noValue, locked, quest }, quest
-- being the game's own mark of a quest item.
local _, ns = ...

local Model = {}

-- How long a sale may wait for the game's answer, in seconds.
Model.ANSWER = 3

local POOR = 0      -- the game's quality of a gray item

-- The item an objective's text names, or nil. "Linen Cloth: 3/10", "3/10 Linen Cloth" and
-- "Linen Cloth: 10/10 (Complete)" give "Linen Cloth". (Spaces are named one by one: the class %s
-- can take a byte of a letter with a mark.)
function Model.ObjectiveItem(text)
    if type(text) ~= "string" then
        return nil
    end
    local name = text:gsub("\194\160", " "):gsub("\226\128\175", " ")
    name = name:gsub("(%d+[ \t]*/[ \t]*%d+)[ \t]*%b()[ \t]*$", "%1")
    name = name:gsub("%d+[ \t]*/[ \t]*%d+", "")
    name = name:match("^[ \t:]*(.-)[ \t:]*$")
    return name ~= "" and name or nil
end

-- The needs of the quest log: item name -> the title of the first quest that names it.
-- quests: { { title, objectives = { { kind, text } } } }.
function Model.Needs(quests)
    local needs = {}
    for _, quest in ipairs(quests) do
        for _, objective in ipairs(quest.objectives) do
            local name = objective.kind == "item" and Model.ObjectiveItem(objective.text)
            if name and not needs[name] then
                needs[name] = quest.title
            end
        end
    end
    return needs
end

-- The quest a thing is needed for: its title; true for the game's own quest item that no
-- objective names; nil when no quest needs it.
function Model.Needed(thing, needs)
    return needs[thing.name] or (thing.quest and true) or nil
end

-- Y on a thing in the bags: the mark changes (marks: item id -> true, changed in place), or the
-- thing is refused. Gives the chat line.
function Model.Toggle(marks, thing, needs)
    local quest = Model.Needed(thing, needs)
    if quest == true then
        return thing.name .. " is a quest item. It cannot be junk."
    elseif quest then
        return thing.name .. " is needed for " .. quest .. ". It cannot be junk."
    elseif thing.quality == POOR then
        return thing.name .. " is gray, so it is junk already."
    elseif thing.noValue then
        return "Vendors do not buy " .. thing.name .. "."
    end
    marks[thing.id] = not marks[thing.id] or nil
    return thing.name .. (marks[thing.id] and " is junk now." or " is not junk now.")
end

-- True when Auto Sell Junk sells a thing for its mark: marked, not gray (the game's own sale
-- takes those), bought by a vendor, and needed by no quest.
function Model.Sells(thing, marks, needs)
    return marks[thing.id] == true and thing.quality ~= POOR and not thing.noValue and not Model.Needed(thing, needs)
end

-- The next stack to sell: the first, in the bags' order, that sells and is not on its way.
function Model.NextSale(things, marks, needs)
    for _, thing in ipairs(things) do
        if not thing.locked and Model.Sells(thing, marks, needs) then
            return thing
        end
    end
    return nil
end

-- True when the stack asked for is no longer in its place as it was.
function Model.Gone(things, asked)
    for _, thing in ipairs(things) do
        if thing.bag == asked.bag and thing.slot == asked.slot then
            return thing.id ~= asked.id or thing.count ~= asked.count
        end
    end
    return true
end

-- The sales between two looks at the vendor's buyback list (each { link, name }): the entries
-- that are there more often than before.
-- Limit: a full list (12) that drops the oldest stack of an item as the same item is sold
-- again looks the same; compare the entries' places if players ask.
function Model.Sold(before, after)
    local had = {}
    for _, entry in ipairs(before) do
        had[entry.link] = (had[entry.link] or 0) + 1
    end
    local sold = {}
    for _, entry in ipairs(after) do
        if (had[entry.link] or 0) > 0 then
            had[entry.link] = had[entry.link] - 1
        else
            sold[#sold + 1] = entry
        end
    end
    return sold
end

-- ---------------------------------------------------------------- words
function Model.TipLine(quest)
    return "Needed for " .. quest
end

function Model.SoldLine(name, quest)
    return "You sold " .. name .. ", needed for " .. quest .. ". Buy it back on the vendor's Buyback tab."
end

-- quest: a title, or true for the game's own quest item.
function Model.HeldLine(name, quest)
    return name .. (quest == true and " is a quest item." or " is needed for " .. quest .. ".") .. " Press X again to sell it."
end

-- coins: the price as text, or nil when the game did not know every price. names: the stacks
-- that went, named after the count when there are three at most.
function Model.SaleLine(count, coins, names)
    local which = names and #names > 0 and #names <= 3 and ": " .. table.concat(names, ", ") or ""
    return "Sold " .. count .. (count == 1 and " item" or " items") .. " you marked as junk" .. (coins and " for " .. coins or "") .. which .. "."
end

if ns then
    ns.JunkModel = Model
end
return Model
