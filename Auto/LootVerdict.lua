-- Loot Verdict: one line in an item's tooltip that says what to do with it: "Sell to vendor: 25s",
-- "Auction: 1g 20s" or "Keep (quest)". It weighs what a vendor pays for one (the game's item
-- facts) against the last known auction price of one (Auto/Prices.lua), the house's cut counted,
-- and shows only while an auction price is known (the rules: Auto/PricesModel.lua, Verdict).
-- The line is added with the game's own post call for item tooltips (Core/AdapterJunk.lua,
-- Adapter.OnItemTooltip); no field of the tooltip is written. Behind the row windows.loot_verdict.
-- No work is done but at a tooltip of an item.
local _, ns = ...

local Verdict = ns.Module("LootVerdict", { "lootVerdict" }, "Loot Verdict")
ns.LootVerdict = Verdict

local ROW = "windows.loot_verdict"
local on = true    -- the row, read at login and again at each change of it

-- The row's value; a row not yet in the settings counts as on.
local function row()
    local ok, value = pcall(ns.Registry.Get, ROW)
    return not ok or value and true or false
end

-- The line for the item with this id, or nil.
function Verdict.Line(itemID)
    if not on then
        return nil
    end
    local auction = ns.Prices.Get(itemID)
    if not auction then
        return nil
    end
    local vendor, quest = ns.Adapter.ItemFacts(itemID)
    return ns.PricesModel.Verdict(vendor, auction, quest, ns.Adapter.CoinText)
end

function Verdict.OnLogin()
    on = row()
    ns.Listen("setting", "LootVerdict", function(key)
        if key == ROW then
            on = row()
        end
    end)
    -- (this runs inside the game's tooltip code: a fault is caught and logged, and no line is added)
    ns.Adapter.OnItemTooltip(function(itemID)
        local ok, text = ns.Call("LootVerdict", Verdict.Line, itemID)
        return ok and text or nil
    end, ns.Theme.Color("gold"))
end
