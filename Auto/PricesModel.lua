-- The rules of the price store (Auto/Prices.lua), with no game calls: the lowest price of a
-- reading, which of two prices is the newer, the pace of the scan, and the words of the loot
-- verdict (Auto/LootVerdict.lua). The facts behind each rule are in
-- build_plan/packs/P21_auction_view.md, part 8.
--
-- A price kept in the store is { p = copper for one, t = the time it was seen, in the game's
-- seconds since 1970 }.
local _, ns = ...

local Model = {}

Model.DAY = 86400
Model.PER_MINUTE = 100   -- requests in a minute at most: the limit the game's notes give for its searches
Model.PAGE_WAIT = 15     -- seconds to wait for the next page of the scan before it stops
-- The house's cut of a sale on a faction auction house, 5 in 100. The game's code has no number for
-- it; the mail of a sale shows it (Blizzard_MailFrame/MailFrame.lua 834).
Model.CUT = 0.05

-- The lowest price of one of each item in a reading: rows is a list of { id, price }; a row with
-- no id or a price of 0 is left out. Returns item id -> copper, and how many items it has.
function Model.Lowest(rows)
    local lows, count = {}, 0
    for _, row in ipairs(rows) do
        local id, price = row.id, tonumber(row.price)
        if id and price and price > 0 then
            if not lows[id] then
                count = count + 1
            end
            lows[id] = math.min(lows[id] or price, price)
        end
    end
    return lows, count
end

-- Keeps the lowest prices of a reading (Model.Lowest) in items, seen now. Each one is the newest
-- word on its item, so it takes the place of the one before. Returns how many were kept.
function Model.Keep(items, lows, now)
    local count = 0
    for id, price in pairs(lows) do
        items[id] = { p = math.floor(price), t = now }
        count = count + 1
    end
    return count
end

-- The newer of two prices: ours (an entry of the store, or nil) and Auctionator's (its price and
-- its age in whole days, or nil). Counted in whole days as Auctionator counts them; on the same
-- day ours wins. Returns the price and its age in seconds, or nil and nil.
function Model.Pick(entry, theirs, days, now)
    local ours = entry and tonumber(entry.p) and entry.p > 0 and entry or nil
    theirs = tonumber(theirs) and theirs > 0 and theirs or nil
    if not theirs then
        if ours then
            return ours.p, math.max(0, now - (ours.t or now))
        end
        return nil, nil
    end
    local age = tonumber(days) and math.max(0, days) * Model.DAY or nil
    if ours and not (age and age < math.floor((now - (ours.t or now)) / Model.DAY) * Model.DAY) then
        return ours.p, math.max(0, now - (ours.t or now))
    end
    return theirs, age
end

-- The pace of the scan: true when another request may go now, given the times of the requests
-- sent so far (a list, oldest first; the ones older than a minute are dropped from it). Else false
-- and the seconds until one more may go.
function Model.CanSend(times, now)
    while times[1] and now - times[1] >= 60 do
        table.remove(times, 1)
    end
    if #times < Model.PER_MINUTE then
        return true
    end
    return false, 60 - (now - times[1])
end

-- A request went at the time now.
function Model.Sent(times, now)
    times[#times + 1] = now
end

-- The loot verdict of an item: what one brings at a vendor (vendor, copper or nil), its last known
-- price at the auction house (auction), and whether it is a quest item. Nil while no auction price
-- is known. coins(copper) writes gold.
function Model.Verdict(vendor, auction, quest, coins)
    auction = tonumber(auction)
    if not (auction and auction > 0) then
        return nil
    elseif quest then
        return "Keep (quest)"
    end
    vendor = tonumber(vendor) or 0
    if vendor > 0 and vendor >= math.floor(auction * (1 - Model.CUT)) then
        return "Sell to vendor: " .. coins(vendor)
    end
    return "Auction: " .. coins(auction)
end

if ns then
    ns.PricesModel = Model
end
return Model
