-- The rules of the bind Feed Pet and of the pop-up Pet Hungry (Auto/PetHungry.lua), with no game
-- calls: which food the pet gets, what the chat says when a press can feed nothing, and the words
-- and the cause of the pop-up.
local _, ns = ...

local Model = {}

-- The food to feed, from what the pet eats of the bags (the adapter's list, in the order of the
-- bags: { { bag =, slot =, id =, level =, count = } }). nil for an empty list.
-- The food of the highest level wins: the game gives a pet the most for food near its own
-- level, and refuses food far under it. Among stacks of one level the smallest goes first, so a
-- place in the bags comes free.
-- Limit: a young pet gets the best food too, where a lesser one would do. The level rule is
-- the server's and not in the game's interface files; with it known, take the lowest food that
-- still gives the most.
function Model.Best(foods)
    local best
    for _, food in ipairs(foods) do
        if not best or food.level > best.level or (food.level == best.level and food.count < best.count) then
            best = food
        end
    end
    return best
end

-- What stops a feed: "pet" (no pet is out), "dead" (it is dead), "food" (the bags hold nothing it
-- eats), "spell" (the player does not know Feed Pet), or nil. pet: true or "alive", "dead", or
-- nil; known: false when the player cannot cast Feed Pet at all (nil counts as known).
function Model.Missing(pet, food, known)
    return not pet and "pet" or pet == "dead" and "dead" or not food and "food" or known == false and "spell" or nil
end

-- What the chat says for each, one time.
Model.TEXT = {
    pet = "Feed Pet: you have no pet with you.",
    dead = "Feed Pet: your pet is dead. Revive it first.",
    food = "Feed Pet: your bags hold no food that your pet eats.",
    spell = "Feed Pet: you cannot cast Feed Pet now.",
}

-- The pop-up Pet Hungry. Its title by the step of happiness: 2 content (the game's word), 1 unhappy.
Model.HUNGRY = { [2] = "Your pet is hungry", [1] = "Your pet is unhappy" }

-- The words under it: the food the press feeds, how many the bags hold, and the damage the pet does
-- now (the game's own tooltip shows the same, Blizzard_FrameXML/PetHappiness.lua 104).
function Model.FoodLine(name, count, damage)
    return (name or "Food") .. " x" .. count .. " in your bags." .. (damage and (" Damage " .. damage .. "%.") or "")
end

-- The chat line when the bags hold nothing it eats: the kinds it eats, the game's own names.
function Model.NoFood(step, diet)
    local start = "Pet Hungry (Screen, Pop-ups): " .. (step == 1 and "your pet is unhappy." or "your pet is hungry.")
    if #diet == 0 then
        return start .. " Your bags hold no food it eats."
    end
    return start .. " It eats " .. table.concat(diet, ", ") .. ". Your bags hold none."
end

-- A cause shows one time in a session: the pet, the step it fell to, and if food was found.
function Model.Cause(pet, step, found)
    return tostring(pet) .. ":" .. tostring(step) .. ":" .. (found and "food" or "none")
end

if ns then
    ns.FeedPetModel = Model
end
return Model
