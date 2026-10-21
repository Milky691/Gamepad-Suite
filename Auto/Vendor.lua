-- Auto Sell Junk and Auto Repair: when the player opens a vendor, the gray items in the bags are
-- sold with the game's own call for its Sell All Junk button, and the gear is repaired at a vendor
-- that can repair, with the guild's money when the guild gives enough for all of it. One chat line
-- for each. Holding View as the vendor opens leaves both to the player, as Pause Automation does.
-- Both are off at the start.
-- The items the player marked as junk are sold after the gray ones by Auto/JunkSell.lua.
--
-- The work is done at the game's events only. The sale is one call that asks the server, so its
-- chat line waits for the game's word that the bags changed and counts the gray items that went;
-- when the vendor closes first, the line names what went by then. A repair the player cannot pay
-- yet (the gold of the sale is on its way) waits for the game's word that the gold changed, while
-- the vendor is open. The log (kind "vendor") has what the game said at the first few vendors.
local _, ns = ...

local Sell = ns.Module("SellJunk", { "sellJunk" }, "Auto Sell Junk")
local Repair = ns.Module("Repair", { "repair" }, "Auto Repair")
ns.SellJunk, ns.Repair = Sell, Repair

local Coins = ns.RestockModel.Coins
local get = ns.Registry.Get

local before          -- the gray items when the sale was asked for; nil while no sale waits for its line
local waiting         -- the cost of a repair that waits for gold; nil while none waits
local notes = 0

local function note(text)
    if notes < 10 then
        notes = notes + 1
        ns.Log.Add("vendor", text)
    end
end

-- The bags changed, or the vendor closes (final): once every junk item is gone, or at the close,
-- the chat line names the gray items that went and what they brought.
local function counted(final)
    if not before or not (final or ns.Adapter.JunkLeft() == 0) then
        return
    end
    ns.Off("BAG_UPDATE_DELAYED", "SellJunk")
    local now = ns.Adapter.Grays()
    local sold, copper = before.count - now.count, before.copper - now.copper
    note("sold " .. sold .. " of " .. before.count .. " gray items" .. (final and " (counted when the vendor closed)" or ""))
    if sold > 0 then
        ns.Print("Sold " .. sold .. (sold == 1 and " gray item" or " gray items")
            .. ((before.known and now.known and copper > 0) and " for " .. Coins(copper) or "") .. ".")
    end
    before = nil
end

function Sell.OnLogin()
    ns.On("MERCHANT_SHOW", "SellJunk", function()
        -- (the game can say this a second time for the vendor that is open)
        if before or not get("helpers.sell_junk") or ns.Adapter.ViewHeld() or ns.Automation.Paused() then
            return
        end
        local grays = ns.Adapter.Grays()
        local on, junk = ns.Adapter.SellJunk()
        note("a vendor: the game's sale of junk is " .. (on and "on" or "off") .. ", " .. junk .. " junk items, " .. grays.count .. " gray items in the bags")
        if on and junk > 0 then
            before = grays
            ns.On("BAG_UPDATE_DELAYED", "SellJunk", function()
                counted(false)
            end)
        end
    end)
    ns.On("MERCHANT_CLOSED", "SellJunk", function()
        counted(true)
    end)
end

local function stopWaiting()
    waiting = nil
    ns.Off("PLAYER_MONEY", "Repair")
end

-- One look at the open vendor: repairs all gear when the guild's money or the player's gold pays
-- for it, else waits for the gold to change. Paused automation (Auto/Automation.lua) stops a wait too.
local function repair()
    local cost, gold, guild = ns.Adapter.RepairCost()
    if not cost or ns.Automation.Paused() then
        stopWaiting()
        return
    end
    local byGuild = guild >= cost
    if not byGuild and gold < cost then
        if not waiting then
            note("a repair of " .. Coins(cost) .. " waits for gold (" .. Coins(gold) .. ")")
            ns.On("PLAYER_MONEY", "Repair", repair)
        end
        waiting = cost
        return
    end
    stopWaiting()
    if ns.Adapter.RepairAll(byGuild) then
        ns.Print("Repaired your gear for " .. Coins(cost) .. (byGuild and ", paid by your guild." or "."))
    end
end

function Repair.OnLogin()
    ns.On("MERCHANT_SHOW", "Repair", function()
        if not waiting and get("helpers.repair") and not ns.Adapter.ViewHeld() then
            repair()
        end
    end)
    ns.On("MERCHANT_CLOSED", "Repair", function()
        if waiting then
            ns.Print("Your gear is not repaired. It costs " .. Coins(waiting) .. ", more than your gold.")
            stopWaiting()
        end
    end)
end
