-- Auction Prices: the store of the last known auction price of one of each item, kept for the
-- account. The Auction House View starts its posts from it, the Professions View shows costs
-- with it, and the loot verdict (Auto/LootVerdict.lua) weighs a vendor's price against it.
--
-- The interface the other parts use (keep it as it is):
--   ns.Prices.Get(itemID) gives the price in copper (or nil) and its age in seconds (or nil).
--   ns.Prices.OnChanged(owner, fn) calls fn() after a scan or an update (owner names the caller).
--
-- Where the prices come from (the facts are in build_plan/packs/P21_auction_view.md, part 8):
--   a. What the player browses or searches while the auction house is open: the lowest price of
--      each item in the game's answer. The answers are only read, whoever asked.
--   b. A scan, started by a press in the Auction House View and never by itself: one empty browse
--      query and its pages, each request only while the game's throttle lets it go and no more
--      than the game's limit in a minute. Paced by the game's events; it stops when the auction
--      house closes, when a page does not come, or when the view stops it.
--   c. Auctionator's price and its age, while Auctionator is loaded (its public API, read only).
--   The newer of ours and Auctionator's wins (Auto/PricesModel.lua).
-- No work is done while the auction house is closed. The log (kind "prices") says when a scan
-- started and how it ended.
local _, ns = ...

local Prices = ns.Module("Prices", {}, "Auction Prices")
ns.Prices = Prices

local Model = ns.PricesModel

local EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }

local store             -- the saved table of the account: { items = { [item id] = { p, t } } }
local owners = {}       -- who asked to hear of a change: owner -> fn
local open = false      -- the auction house is open
local scan              -- the scan that runs: { id, step ("first" or "more"), found, waiting, at }; nil for none
local made = 0          -- scans made in this session (each has its own id)
local times = {}        -- when the requests of the last minute went (GetTime)
local soon = false      -- a word of a change is on its way
local notes = 0

local function note(text)
    if notes < 30 then
        notes = notes + 1
        ns.Log.Add("prices", text)
    end
end

-- The kept prices. Before the saved file is loaded, a table that is not kept.
local function items()
    if not store then
        local ok, saved = pcall(ns.Registry.Store, "prices")
        if ok and type(saved) == "table" then
            store = saved
            store.items = type(store.items) == "table" and store.items or {}
        end
    end
    return store and store.items or {}
end

-- The price of one of an item and its age in seconds, or nil and nil.
function Prices.Get(itemID)
    if type(itemID) ~= "number" then
        return nil, nil
    end
    local theirs, days = ns.Adapter.AuctionatorPrice(itemID)
    return Model.Pick(items()[itemID], theirs, days, ns.Adapter.PricesNow())
end

function Prices.OnChanged(owner, fn)
    owners[owner] = fn
end

-- Everyone who asked hears of a change, half a second after the last of a burst of answers.
local function changed()
    if soon then
        return
    end
    soon = true
    C_Timer.After(0.5, function()
        soon = false
        for owner, fn in pairs(owners) do
            ns.Call(owner, fn)
        end
    end)
end

-- Keeps the lowest prices of a reading. During a scan the others hear of it at its end.
local function record(rows)
    local lows, count = Model.Lowest(rows)
    if count > 0 then
        Model.Keep(items(), lows, ns.Adapter.PricesNow())
        if scan then
            scan.found = scan.found + count
            ns.Send("prices:scan", scan.found, false)
        else
            changed()
        end
    end
    return count
end

-- ---------------------------------------------------------------- the scan
-- The scan ends: why is "done", "stopped", "closed", "failed" or "late". True when one ran.
local function stop(why)
    if not scan then
        return false
    end
    local found = scan.found
    scan = nil
    note("the scan ended (" .. why .. ") with " .. found .. " prices")
    ns.Send("prices:scan", found, why)
    changed()
    return true
end

-- Each wait of the scan (for the throttle, the minute's limit or a page) has PAGE_WAIT seconds; a
-- step of the scan in between starts a new wait.
local function wait()
    scan.at = scan.at + 1
    local id, at = scan.id, scan.at
    C_Timer.After(Model.PAGE_WAIT, function()
        if scan and scan.id == id and scan.at == at then
            stop("late")
        end
    end)
end

-- The next request of the scan, when the game's throttle and the minute's limit let it go; else
-- it waits for the throttle's event, or for the minute's limit with one timer.
local function send()
    if not (scan and open) then
        return
    end
    local can, after = Model.CanSend(times, GetTime())
    if not can then
        -- (no wait for a page runs while the minute's limit holds)
        scan.due, scan.at = true, scan.at + 1
        local id = scan.id
        C_Timer.After(after, function()
            if scan and scan.id == id and scan.due then
                send()
            end
        end)
        return
    end
    wait()
    if not ns.Adapter.PricesReady() then
        scan.due = true
        return
    end
    scan.due = false
    local ok, why = ns.Adapter.PricesSend(scan.step)
    if not ok then
        note("a request of the scan did not run: " .. tostring(why))
        stop("failed")
        return
    end
    Model.Sent(times, GetTime())
    scan.waiting = true
end

-- A page of the scan came: the next one, or the end.
local function page()
    if scan and scan.waiting then
        scan.waiting, scan.step = false, "more"
        if ns.Adapter.PricesFull() then
            stop("done")
        else
            send()
        end
    end
end

-- Starts the scan (on true) or stops it. True when it started or stopped. It starts only while
-- the auction house is open, and not over a scan that runs.
function Prices.Scan(on)
    if not on then
        return stop("stopped")
    elseif scan or not open then
        return false
    end
    made = made + 1
    scan = { id = made, step = "first", found = 0, at = 0, waiting = false }
    note("a scan started")
    ns.Send("prices:scan", 0, false)
    send()
    return scan ~= nil
end

-- True while a scan runs, and how many prices it found so far.
function Prices.Scanning()
    return scan ~= nil, scan and scan.found or 0
end

-- ---------------------------------------------------------------- what the store hears
local HANDLERS = {
    AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = function()
        record(ns.Adapter.PricesRows())
        page()
    end,
    AUCTION_HOUSE_BROWSE_RESULTS_ADDED = function(added)
        record(ns.Adapter.PricesRows(added))
        page()
    end,
    AUCTION_HOUSE_BROWSE_FAILURE = function()
        stop("failed")
    end,
    ITEM_SEARCH_RESULTS_UPDATED = function(itemKey)
        if type(itemKey) == "table" then
            record(ns.Adapter.PricesSearch(itemKey))
        end
    end,
    COMMODITY_SEARCH_RESULTS_UPDATED = function(itemID)
        if itemID then
            record(ns.Adapter.PricesSearch(nil, itemID))
        end
    end,
    AUCTION_HOUSE_THROTTLED_SYSTEM_READY = function()
        if scan and scan.due then
            send()
        end
    end,
}

-- The auction house opened (on) or closed: the answers are heard only while it is open.
local function hear(on)
    open = on
    for _, event in ipairs(EVENTS) do
        if on then
            ns.On(event, "Prices", HANDLERS[event])
        else
            ns.Off(event, "Prices")
        end
    end
    if not on then
        stop("closed")
    end
end

function Prices.OnLogin()
    items()
    if not ns.Adapter.Results().prices then
        note("the game's auction house calls are not all there: prices come from Auctionator only")
        return
    end
    ns.On("AUCTION_HOUSE_SHOW", "Prices", function()
        hear(true)
    end)
    ns.On("AUCTION_HOUSE_CLOSED", "Prices", function()
        hear(false)
    end)
end
