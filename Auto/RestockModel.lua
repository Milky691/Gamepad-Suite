-- The rules of Restock, with no game calls: which thing of a vendor is ammunition, a drink or
-- food, which one is bought, how many, and the words of the chat line. Class reagents too: which
-- ones the character's known spells use (the table below), and how many of each to buy.
--
-- The game files every item under a class and a subclass, each a number of its own lists.
-- Arrows and bullets are the class Projectile. Food and drink are one subclass of the class
-- Consumable; the name of the item's use effect tells the two apart ("Food", "Drink": the
-- adapter reads both names from the game, in the game's language).
--
-- Which kind is bought: the best one this vendor sells that the level can use now (the highest
-- level the item asks for; of two with the same level, the one that costs more). Ammunition must
-- also fit the bow or gun in the ranged slot: arrows for a bow or a crossbow, bullets for a gun.
-- How many: the count the player set, less what the bags hold of that kind or better (the same
-- item, or another of its kind that asks for the same level or more). A lower thing in the bags
-- does not count, so the character always carries the best the vendor has; it is never sold. Whole
-- lots of the vendor (a vendor sells five drinks as one lot), never more than the count, never
-- more than the vendor has left, and never more than the gold allows: at least one tenth of the
-- gold the character had at the vendor's door stays.
--
-- Class reagents are another count: up to that many of each reagent the character's spells use,
-- less what the bags hold of that item (every stack). A reagent counts only for a spell in the
-- spellbook, and a spell whose ranks use different items counts only the item of the highest rank
-- known. They are planned after the three supplies, from the same gold.
local _, ns = ...

local Model = {}

-- The game's numbers: the classes Consumable and Projectile, the subclass Food and drink.
Model.CONSUMABLE, Model.MEAL, Model.PROJECTILE = 0, 5, 6
-- The kind of a ranged weapon (a subclass of the class Weapon) -> the kind of projectile it
-- shoots: a bow (2) and a crossbow (18) shoot arrows (2), a gun (3) shoots bullets (3).
Model.SHOOTS = { [2] = 2, [18] = 2, [3] = 3 }
-- The three supplies, in the order they are bought and named.
Model.KINDS = { "ammo", "drink", "food" }

-- The class reagents: item numbers and the number of every rank of the spells that use them
-- (build_plan/packs/P26_class_reagents.md says where each number comes from). A use is
-- { item, spells }: any one of the spells needs the item. Or { ranks = { { spell, item }, ... } }:
-- each rank needs an item of its own, from the lowest rank up. A reagent that no merchant sells on
-- this game (Light Feather, Shiny Fish Scales, Fish Oil) is listed all the same: a vendor that
-- lists one is bought from.
Model.REAGENTS = {
    { item = 17030, spells = { 20608 } },                                           -- Ankh: Reincarnation
    { item = 17033, spells = { 19752 } },                                           -- Symbol of Divinity: Divine Intervention
    { item = 21177, spells = { 25898, 25782, 25916, 25894, 25918, 25895, 25890 } }, -- Symbol of Kings: the Greater Blessings
    { item = 17020, spells = { 23028 } },                                           -- Arcane Powder: Arcane Brilliance
    { item = 17031, spells = { 3561, 3562, 3565, 3567, 3563, 3566 } },              -- Rune of Teleportation: the teleports
    { item = 17032, spells = { 10059, 11416, 11419, 11417, 11418, 11420 } },        -- Rune of Portals: the portals
    { item = 17056, spells = { 130, 1706 } },                                       -- Light Feather: Slow Fall, Levitate
    { ranks = { { 21562, 17028 }, { 21564, 17029 } } },                             -- Prayer of Fortitude: Holy Candle, Sacred Candle
    { item = 17029, spells = { 27683, 27681 } },                                    -- Sacred Candle: Shadow Protection, Spirit
    { item = 5140, spells = { 1856, 1857 } },                                       -- Flash Powder: Vanish
    { ranks = { { 20484, 17034 }, { 20739, 17035 }, { 20742, 17036 }, { 20747, 17037 }, { 20748, 17038 } } }, -- Rebirth: the seeds
    { ranks = { { 21849, 17021 }, { 21850, 17026 } } },                             -- Gift of the Wild: Wild Berries, Wild Thornroot
    { item = 17057, spells = { 131 } },                                             -- Shiny Fish Scales: Water Breathing
    { item = 17058, spells = { 546 } },                                             -- Fish Oil: Water Walking
    { item = 5565, spells = { 1122 } },                                             -- Infernal Stone: Inferno
    { item = 16583, spells = { 18540 } },                                           -- Demonic Figurine: Ritual of Doom
}
-- Every item of the table: { [item number] = true }.
Model.REAGENT_ITEMS = {}
for _, use in ipairs(Model.REAGENTS) do
    if use.item then
        Model.REAGENT_ITEMS[use.item] = true
    end
    for _, rank in ipairs(use.ranks or {}) do
        Model.REAGENT_ITEMS[rank[2]] = true
    end
end

-- Every spell number of the table, each once: what to ask the spellbook.
function Model.ReagentSpells()
    local list, seen = {}, {}
    local function add(spell)
        if not seen[spell] then
            seen[spell] = true
            list[#list + 1] = spell
        end
    end
    for _, use in ipairs(Model.REAGENTS) do
        for _, spell in ipairs(use.spells or {}) do
            add(spell)
        end
        for _, rank in ipairs(use.ranks or {}) do
            add(rank[1])
        end
    end
    return list
end

-- The items the known spells use, each once, in the order of the table. known: { [spell number] = true }.
function Model.Needed(known)
    local items, seen = {}, {}
    local function add(item)
        if not seen[item] then
            seen[item] = true
            items[#items + 1] = item
        end
    end
    for _, use in ipairs(Model.REAGENTS) do
        if use.ranks then
            for i = #use.ranks, 1, -1 do
                if known[use.ranks[i][1]] then
                    add(use.ranks[i][2])
                    break
                end
            end
        else
            for _, spell in ipairs(use.spells) do
                if known[spell] then
                    add(use.item)
                    break
                end
            end
        end
    end
    return items
end

-- What a thing is to Restock: "ammo", "drink", "food" or nil. item has class, sub and spell
-- (the name of its use effect); words has the game's names of the two effects: food, drink.
function Model.Kind(item, words)
    if item.class == Model.PROJECTILE then
        return "ammo"
    elseif item.class == Model.CONSUMABLE and item.sub == Model.MEAL and item.spell then
        return item.spell == words.drink and "drink" or item.spell == words.food and "food" or nil
    end
    return nil
end

-- The most a purchase may cost: one tenth of the gold stays (rounded up, in copper).
function Model.Budget(money)
    return money - math.ceil(money / 10)
end

-- True for a thing of the vendor that gold alone buys now.
local function sold(offer)
    return offer.buyable and not offer.extended and offer.lot >= 1 and offer.left ~= 0
end

-- True when a thing of the vendor can be of the kind, by its class and subclass alone: the
-- game knows these two at once, also for a thing it has not loaded yet.
local function could(offer, kind)
    if kind == "ammo" then
        return offer.class == Model.PROJECTILE
    end
    return offer.class == Model.CONSUMABLE and offer.sub == Model.MEAL
end

-- The best thing of a kind that the vendor sells and the level can use. The second value is
-- true when the game has not loaded one of the vendor's things yet (it has no level): the
-- answer can change when it has, so nothing is bought before.
function Model.Best(offers, kind, level, words, shoots)
    local best, wait = nil, false
    for _, offer in ipairs(offers) do
        if could(offer, kind) and sold(offer) then
            if offer.level == nil then
                wait = true
            elseif offer.usable and Model.Kind(offer, words) == kind and (kind ~= "ammo" or offer.sub == shoots)
                and offer.level <= level and (not best or offer.level > best.level
                    or offer.level == best.level and offer.price / offer.lot > best.price / best.lot) then
                best = offer
            end
        end
    end
    return best, wait
end

-- How many the bags hold of the best thing or better: things of its kind (and of its kind of
-- projectile) that ask for its level or more. carried is the list of the things in the bags:
-- each { class, sub, spell, level, count }. nil when the game has not loaded one of them yet.
function Model.Held(carried, best, kind, words)
    local held = 0
    for _, item in ipairs(carried) do
        if could(item, kind) and item.level == nil then
            return nil
        elseif Model.Kind(item, words) == kind and item.sub == best.sub and item.level >= best.level then
            held = held + item.count
        end
    end
    return held
end

-- How many of a thing to buy, and the cost: want is the count to carry, have what is carried,
-- budget the copper that may be spent. Whole lots only.
function Model.Amount(want, have, offer, budget)
    local lots = math.floor(math.max(0, want - have) / offer.lot)
    if offer.left > 0 then
        lots = math.min(lots, offer.left)
    end
    if offer.price > 0 then
        lots = math.min(lots, math.floor(budget / offer.price))
    end
    return lots * offer.lot, lots * offer.price
end

-- The amounts of the calls that buy `amount` of a thing: the game takes one stack at most in
-- one call (offer.stack), in whole lots.
function Model.Calls(amount, offer)
    local most = math.max(offer.lot, math.floor(offer.stack / offer.lot) * offer.lot)
    local calls = {}
    while amount > 0 do
        calls[#calls + 1] = math.min(amount, most)
        amount = amount - calls[#calls]
    end
    return calls
end

-- The reagents to buy at this vendor: for each item of state.reagents (what the known spells
-- use), up to `want` of it, less what the bags hold of that item. Whole lots, from the first line
-- of the vendor that sells it for gold. Returns the purchases (the shape of Plan's, kind
-- "reagent"), the budget that is left, and for the log { offer, held } of each item sold here.
-- A reagent needs no data from the game: it is found by its number.
function Model.Reagents(offers, state, want, budget)
    local buys, here = {}, {}
    for _, id in ipairs(state.reagents) do
        for _, offer in ipairs(offers) do
            if offer.id == id and sold(offer) then
                local held = 0
                for _, item in ipairs(state.carried) do
                    if item.id == id then
                        held = held + item.count
                    end
                end
                here[#here + 1] = { offer = offer, held = held }
                local amount, cost = Model.Amount(want, held, offer, budget)
                if amount > 0 then
                    budget = budget - cost
                    buys[#buys + 1] = { kind = "reagent", offer = offer, amount = amount, cost = cost, calls = Model.Calls(amount, offer) }
                end
                break
            end
        end
    end
    return buys, budget, here
end

-- What to buy at this vendor. offers: the vendor's things. state: money left to spend
-- (budget), level, weapon (the kind of the ranged weapon, nil for none), carried, reagents (the
-- items the known spells use; nil for none). counts: what the player set (ammo in stacks; reagent
-- is the count of each reagent). skip: the kinds that are settled at this visit. Returns the
-- purchases ({ kind, offer, amount, cost, calls }), the budget that is left, the kinds that
-- wait for the game to load a thing, and for the log each kind's best thing here and how many
-- the bags hold of it or better ({ [kind] = { offer, held } }; found.reagents is the list of
-- Model.Reagents).
function Model.Plan(offers, state, counts, words, skip)
    local shoots = Model.SHOOTS[state.weapon]
    local buys, waits, found, budget = {}, {}, {}, state.budget
    for _, kind in ipairs(Model.KINDS) do
        if counts[kind] > 0 and not skip[kind] and (kind ~= "ammo" or shoots) then
            local offer, wait = Model.Best(offers, kind, state.level, words, shoots)
            local held = offer and Model.Held(state.carried, offer, kind, words)
            if wait or offer and not held then
                waits[#waits + 1] = kind
            elseif offer then
                found[kind] = { offer = offer, held = held }
                local want = kind == "ammo" and counts.ammo * offer.stack or counts[kind]
                local amount, cost = Model.Amount(want, held, offer, budget)
                if amount > 0 then
                    budget = budget - cost
                    buys[#buys + 1] = { kind = kind, offer = offer, amount = amount, cost = cost, calls = Model.Calls(amount, offer) }
                end
            end
        end
    end
    if (counts.reagent or 0) > 0 and not skip.reagent and state.reagents then
        local more, left, here = Model.Reagents(offers, state, counts.reagent, budget)
        for _, buy in ipairs(more) do
            buys[#buys + 1] = buy
        end
        budget, found.reagents = left, here
    end
    return buys, budget, waits, found
end

-- An amount of copper as the chat shows it: "1g 14s 20c", with no part that is zero.
function Model.Coins(copper)
    local parts = {}
    for _, coin in ipairs({ { 10000, "g" }, { 100, "s" }, { 1, "c" } }) do
        local n = math.floor(copper / coin[1])
        copper = copper - n * coin[1]
        if n > 0 then
            parts[#parts + 1] = n .. coin[2]
        end
    end
    return parts[1] and table.concat(parts, " ") or "0c"
end

-- The chat line for what came into the bags: each { kind, name, amount, stack, cost }.
-- "Bought 2 stacks of Sharp Arrow and 20 Ice Cold Milk for 14s 20c." nil when nothing came.
function Model.Line(bought)
    local parts, cost = {}, 0
    for _, buy in ipairs(bought) do
        local stacks = buy.kind == "ammo" and buy.amount % buy.stack == 0 and math.floor(buy.amount / buy.stack)
        if stacks then
            parts[#parts + 1] = stacks .. (stacks == 1 and " stack of " or " stacks of ") .. buy.name
        else
            parts[#parts + 1] = buy.amount .. " " .. buy.name
        end
        cost = cost + buy.cost
    end
    if not parts[1] then
        return nil
    end
    local last = table.remove(parts)
    return "Bought " .. (parts[1] and table.concat(parts, ", ") .. " and " or "") .. last .. " for " .. Model.Coins(cost) .. "."
end

if ns then
    ns.RestockModel = Model
end
return Model
