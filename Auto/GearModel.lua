-- The rules of equipment sets as binds, with no game calls (Auto/GearSets.lua is the module).
-- A set is the game's own: the player makes it in the character window, on the Equipment
-- Manager tab. Here a set is { name, icon, worn = true when all of it is on, lost = how many of
-- its items the game cannot find, items = { place = item number, 0 for a place the set wants
-- empty }, gone = { the places whose item is not in the bags } }. A place that the set leaves as
-- it is has no entry in items. A place is the game's number for it: 1 is the head, 19 the tabard.
local _, ns = ...

local Model = {}

Model.LIST = "Equipment Sets"       -- the name of their list in the bind list
-- The bind of a set is a click on this button. The click's button name is the set's key.
Model.BUTTON = "GamepadSuiteGear"
-- The places the game changes in a fight: main hand, off hand and ranged
-- (Blizzard_FrameXMLBase/Constants.lua 158 to 162).
Model.IN_FIGHT = { [16] = true, [17] = true, [18] = true }
Model.PLACES = { "Head", "Neck", "Shoulders", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrists", "Hands",
    "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main Hand", "Off Hand", "Ranged", "Tabard" }
-- The chat line for a bind whose set the character does not have any more.
Model.NO_SET = "This equipment set is gone or has a new name. Bind it again from the list Equipment Sets on the Binds tab."

-- A set's key: "s" and each byte of its name as two plain characters. The key is made from the
-- name, so a profile from another character brings the bind only to a character that has a set
-- with that name (Core/ProfileRules.lua finds a bind by its command). The name itself is not
-- used: it can hold a space or any other character, and a click's button name is one plain word.
-- Limit: with a name of more than 28 bytes the command is longer than a profile text takes
-- (80, Core/ProfileRules.lua), so that bind is not in the text. A shorter key needs a list of
-- names that is kept for the account.
function Model.Key(name)
    return "s" .. name:gsub(".", function(char)
        return ("%02x"):format(char:byte())
    end)
end

-- The bind of a set, as the game names it.
function Model.Command(name)
    return "CLICK " .. Model.BUTTON .. ":" .. Model.Key(name)
end

-- The set with this key, or nil.
function Model.Find(sets, key)
    for _, set in ipairs(sets) do
        if Model.Key(set.name) == key then
            return set
        end
    end
end

-- The sets as entries for the bind list, in the game's order.
function Model.Binds(sets)
    local out = {}
    for index, set in ipairs(sets) do
        out[index] = { kind = "command", id = Model.Command(set.name), name = set.name, detail = "Equipment set", icon = set.icon }
    end
    return out
end

-- The places a press changes: where the character does not wear the set's item. A place whose
-- item is not in the bags is left out: nothing can go there. worn = { place = item number, 0 for
-- an empty place }.
-- Limit: an item is known by its number, so two rings of one sort count as the same ring.
function Model.Changes(set, worn)
    local gone, out = {}, {}
    for _, place in ipairs(set.gone) do
        gone[place] = true
    end
    for place = 1, #Model.PLACES do
        local item = set.items[place]
        if item and not gone[place] and item ~= (worn[place] or 0) then
            out[#out + 1] = place
        end
    end
    return out
end

-- Of those places, the ones that wait for the end of a fight: every place but the three that
-- the game changes in one.
function Model.Later(changes)
    local out = {}
    for _, place in ipairs(changes) do
        if not Model.IN_FIGHT[place] then
            out[#out + 1] = place
        end
    end
    return out
end

-- The chat line for a press in a fight that leaves a part of the set for later.
function Model.LaterText(set)
    return set.name .. ": only your weapons change in combat. The rest goes on after combat."
end

-- The chat line for a press out of a fight of a set that is on already, and for a swap of a press
-- that the game could not end (EQUIPMENT_SWAP_FINISHED with false).
function Model.OnText(set)
    return set.name .. ": this equipment set is on already."
end

function Model.FailText(set)
    return set.name .. ": the game could not put it all on."
end

-- The chat line for a set with an item that is not in the bags (sold, or in the bank): the
-- places it cannot fill. Where the game says an item is lost and not which, the line has no
-- place. nil when every item is there.
function Model.GoneText(set)
    local names = {}
    for index, place in ipairs(set.gone) do
        names[index] = Model.PLACES[place] or ("place " .. place)
    end
    if #names == 0 then
        return set.lost > 0 and (set.name .. ": not every item of this equipment set is in your bags.") or nil
    end
    local last = table.remove(names)
    return set.name .. ": nothing in your bags for " .. (#names > 0 and (table.concat(names, ", ") .. " and ") or "") .. last .. "."
end

-- For a wheel, and for a tap on a fixed slot: the click that does what a set's key does, by the
-- set's bind ("GamepadSuiteGear s54616e6b 1" is the button, the key and the press). names is
-- { key = the set's name }.
function Model.Clicks(names)
    local out = {}
    for key in pairs(names) do
        out["CLICK " .. Model.BUTTON .. ":" .. key] = Model.BUTTON .. " " .. key .. " 1"
    end
    return out
end

if ns then
    ns.GearModel = Model
end
return Model
