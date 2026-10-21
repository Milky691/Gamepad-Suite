-- Restock: when the player opens a vendor that sells them, the suite buys the ammunition, the
-- drinks and the food the character is short of, up to the counts on the page Restock:
-- the best kind the vendor has for the level, with only that kind or better in the bags counted.
-- The fourth count, Class Reagents, buys up to that many of each reagent the spells in the
-- spellbook use (an Ankh for Reincarnation), unless the Reagent Economy talent spares them.
-- One chat line then names what came into the bags and the cost. With nothing bought there is
-- no line. Pause Automation stops it, and so does View held as the vendor opens (for that visit,
-- as Auto Sell Junk and Auto Repair). Auto/RestockModel.lua has the rules: which kind, how many,
-- how much gold stays.
--
-- The work is done at the game's events only. The vendor opens: one look at its list and at the
-- bags, and the calls that buy. The game can need a moment to load a thing of the vendor; then
-- that kind waits for the game's word that an item is loaded. The buy call asks the server, so
-- the chat line waits for the game's word that the bags changed, and counts what came. When the
-- vendor closes first, the line names what had come by then.
--
-- The log (kind "restock") has, for a vendor with supplies: the numbers the game gives its
-- things, the ranged weapon, each kind's best thing here and how many of it or better the bags
-- hold, what was asked for, and what came. For a vendor that lists a class reagent, with the
-- count above 0 and a known spell that uses one: the spells known, the reagents they use, the
-- answer on Reagent Economy and each of those reagents' line here (a few lines of its own, so
-- the others keep theirs).
local _, ns = ...

local Restock = ns.Module("Restock", { "restock" }, "Restock")
ns.Restock = Restock

local Model = ns.RestockModel
local get = ns.Registry.Get

local MAX_NOTES = 12    -- lines for the log in one session
local MAX_REAGENT_NOTES = 4 -- the lines about reagents, besides those
local reagentNotes = 0
local REAGENTS = "helpers.restock_reagents"
local open = false      -- a vendor's window is open
local budget            -- the copper that may still be spent at this vendor; nil before the first look
local settled = {}      -- the kinds that are done at this vendor: bought, or nothing to buy
local asked = {}        -- what was asked of the vendor and is not counted yet
local due = false       -- a look is due at the next step
local notes = 0
local toldView = false  -- the log has a visit with View held (once a session)

local function note(text)
    if notes < MAX_NOTES then
        notes = notes + 1
        ns.Log.Add("restock", text)
    end
end

-- The bags changed, or the vendor closes (final): what came of each thing that was asked for.
-- When all of it is there, or at the close, the chat line is printed.
local function count(final)
    local all = asked[1] ~= nil
    for _, ask in ipairs(asked) do
        ask.came = math.min(ask.amount, math.max(0, ns.Adapter.Carried(ask.id) - ask.before))
        all = all and ask.came == ask.amount
    end
    if not (all or final and asked[1]) then
        return
    end
    ns.Off("BAG_UPDATE_DELAYED", "Restock")
    local bought, told = {}, {}
    for _, ask in ipairs(asked) do
        told[#told + 1] = ask.amount .. " of " .. ask.name .. ", " .. ask.came .. " came"
        if ask.came > 0 then
            bought[#bought + 1] = { kind = ask.kind, name = ask.name, amount = ask.came, stack = ask.stack,
                cost = math.floor(ask.came * ask.each + 0.5) }
        end
    end
    asked = {}
    note("asked for " .. table.concat(told, "; ") .. (final and " (counted when the vendor closed)" or ""))
    local line = Model.Line(bought)
    if line then
        ns.Print(line)
    end
end

-- A thing as the log names it: its number, the game's class and subclass, the name of its use
-- effect and the level it asks for.
local function numbers(item)
    return item.id .. " (" .. tostring(item.class) .. "." .. tostring(item.sub) .. " " .. tostring(item.spell) .. ", level " .. tostring(item.level) .. ")"
end

-- The log line about reagents: the spells of the table that are known, the items they use, the
-- answer on Reagent Economy and, if it is no, each of those items' line at this vendor.
local function reagentLine(known, needs, economy, here)
    local spells, lines = {}, {}
    for _, spell in ipairs(Model.ReagentSpells()) do
        if known[spell] then
            spells[#spells + 1] = spell
        end
    end
    for _, it in ipairs(here or {}) do
        lines[#lines + 1] = it.offer.id .. " (lot " .. it.offer.lot .. ", stack " .. it.offer.stack .. ", " .. Model.Coins(it.offer.price)
            .. ", carried " .. it.held .. ")"
    end
    return "reagents: spells known " .. table.concat(spells, ", ") .. "; they use " .. table.concat(needs, ", ")
        .. (economy and "; Reagent Economy yes, nothing bought" or "; Reagent Economy no; here " .. (lines[1] and table.concat(lines, ", ") or "none of them"))
end

-- One look at the open vendor: what is short is asked for. A kind that waits for the game to
-- load a thing is looked at again when the game says an item is loaded.
local function look()
    due = false
    if not (open and get("helpers.restock")) or ns.Automation.Paused() then
        return
    end
    local counts = { ammo = get("helpers.restock_ammo"), drink = get("helpers.restock_drink"), food = get("helpers.restock_food"),
        reagent = ns.Registry.Has(REAGENTS) and get(REAGENTS) or 0 }
    if counts.ammo + counts.drink + counts.food + counts.reagent == 0 then
        return
    end
    local words, offers, state = ns.Adapter.MealWords(), ns.Adapter.VendorOffers(), ns.Adapter.Supplies()
    budget = budget or Model.Budget(state.money)
    state.budget = budget
    -- the reagents the known spells use are worked out once at a visit; a talent that spares them buys none
    local known, needs, economy
    if counts.reagent > 0 and not settled.reagent then
        known, economy = ns.Adapter.KnownSpellSet(Model.ReagentSpells()), ns.Adapter.ReagentEconomy()
        needs = Model.Needed(known)
        state.reagents = not economy and needs or nil
    end
    local buys, left, waits, found = Model.Plan(offers, state, counts, words, settled)
    budget = left
    for _, kind in ipairs(Model.KINDS) do
        settled[kind] = true
    end
    settled.reagent = true
    for _, kind in ipairs(waits) do
        settled[kind] = nil
    end
    local sells, wants, lists = {}, {}, false
    for _, offer in ipairs(offers) do
        if offer.class == Model.PROJECTILE or offer.class == Model.CONSUMABLE and offer.sub == Model.MEAL then
            sells[#sells + 1] = numbers(offer) .. " lot " .. offer.lot .. " stack " .. offer.stack .. " for " .. Model.Coins(offer.price)
        elseif Model.REAGENT_ITEMS[offer.id] then
            lists = true
        end
    end
    for _, buy in ipairs(buys) do
        local ask = { kind = buy.kind, id = buy.offer.id, name = buy.offer.name, stack = buy.offer.stack,
            each = buy.offer.price / buy.offer.lot, before = ns.Adapter.Carried(buy.offer.id), amount = 0 }
        for _, amount in ipairs(buy.calls) do
            if ns.Adapter.BuyFromVendor(buy.offer.index, amount) then
                ask.amount = ask.amount + amount
            end
        end
        wants[#wants + 1] = ask.amount .. " of " .. ask.id .. " in " .. #buy.calls .. " calls"
        if ask.amount > 0 then
            asked[#asked + 1] = ask
        end
    end
    if sells[1] then
        local best = {}
        for _, kind in ipairs(Model.KINDS) do
            local it = found[kind]
            if it then
                best[#best + 1] = kind .. " best here: " .. it.offer.name .. " (level " .. it.offer.level .. "); carried of that or better: " .. it.held
            end
        end
        note("the vendor sells " .. table.concat(sells, ", ") .. "; the words are " .. words.food .. " and " .. words.drink
            .. "; ranged weapon of kind " .. tostring(state.weapon) .. "; " .. (best[1] and table.concat(best, "; ") or "best here: none")
            .. "; gold " .. Model.Coins(state.money)
            .. "; asked for " .. (wants[1] and table.concat(wants, ", ") or "nothing")
            .. (waits[1] and "; waits for the game to load: " .. table.concat(waits, ", ") or ""))
    end
    if lists and needs and needs[1] and reagentNotes < MAX_REAGENT_NOTES then
        reagentNotes = reagentNotes + 1
        ns.Log.Add("restock", reagentLine(known, needs, economy, found.reagents))
    end
    if asked[1] then
        ns.On("BAG_UPDATE_DELAYED", "Restock", function()
            count(false)
        end)
    end
    if waits[1] then
        -- the game loads many items in one step: one look for all of them, a step later
        ns.On("GET_ITEM_INFO_RECEIVED", "Restock", function()
            if not due then
                due = true
                C_Timer.After(0, function()
                    ns.Call("Restock", look)
                end)
            end
        end)
    else
        ns.Off("GET_ITEM_INFO_RECEIVED", "Restock")
    end
end

function Restock.OnLogin()
    ns.On("MERCHANT_SHOW", "Restock", function()
        -- the game can say this a second time for the vendor that is open: what was asked for
        -- is still on its way then, and a new look would buy it again
        if open then
            return
        end
        open, budget, settled = true, nil, {}
        -- View held as the vendor opens: the player buys by hand, as Auto Sell Junk and Auto Repair
        -- leave it (Auto/Vendor.lua); open stays set, so nothing of this visit buys
        if ns.Adapter.ViewHeld() then
            if get("helpers.restock") and not toldView then
                toldView = true
                ns.Log.Add("restock", "the vendor opened with View held: nothing bought")
            end
            return
        end
        look()
    end)
    ns.On("MERCHANT_CLOSED", "Restock", function()
        if open then
            open = false
            ns.Off("GET_ITEM_INFO_RECEIVED", "Restock")
            count(true)
        end
    end)
end
