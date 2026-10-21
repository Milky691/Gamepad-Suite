-- Auto Sell Junk, the part for the items the player marked as junk (Windows/JunkMark.lua): with
-- Auto Sell Junk and Mark Junk on, the vendor also buys every stack in the bags whose item is
-- marked, after the game's own sale of gray items (Auto/Vendor.lua) is over. Never an item a quest
-- needs, a gray item, a stack on its way, or an item a vendor does not buy (Auto/JunkModel.lua).
-- One chat line at the end says how many went and what they brought.
--
-- The Merchant View's X starts the same run (JunkSell.Sell): the player's press, so it needs Mark
-- Junk on but not Auto Sell Junk, and Pause Automation does not stop it.
-- One stack at a time, each at the game's word: the next stack is asked for when the bags say
-- that the last one left its place. The server drops quick follow-up sales (ForeverPlus's notes,
-- Modules/AutoSellGray.lua 13 to 20), so a sale that is asked for only after the answer to the
-- last one is never dropped, and no timer loop runs. Three seconds with no answer end the run.
-- A fight, the vendor's close, View held as it opens, or Pause Automation stop it. The log (kind "junk") says what
-- was asked for and why the run ended.
local _, ns = ...

local JunkSell = ns.Module("JunkSell", { "questNeeds", "junkSell" }, "Auto Sell Junk")
ns.JunkSell = JunkSell

local Model, Coins = ns.JunkModel, ns.RestockModel.Coins
local get = ns.Registry.Get

local run       -- nil, or the run: { grays (the game's gray sale is not over), sold, copper, known, asked, names, press }
local notes, told = 0, {}

local function note(text, once)
    if notes < 10 and not (once and told[once]) then
        notes = notes + 1
        if once then
            told[once] = true
        end
        ns.Log.Add("junk", text)
    end
end

local function finish(why)
    ns.Off("BAG_UPDATE_DELAYED", "JunkSell")
    note("sold " .. run.sold .. " marked items; " .. why)
    if run.sold > 0 then
        ns.Print(Model.SaleLine(run.sold, run.known and Coins(run.copper) or nil, run.names))
    end
    run = nil
end

-- One step, at the start and each time the bags changed: the stack asked for left, so the vendor
-- took it, and the next one is asked for.
local function step()
    if run.grays then
        if ns.Adapter.GraySalePending() then
            return
        end
        run.grays = false
    end
    local things = ns.Adapter.JunkBags()
    local asked = run.asked
    if asked then
        if not Model.Gone(things, asked) then
            return
        end
        local price = ns.Adapter.ItemPrice(asked.id)
        run.sold, run.copper, run.known = run.sold + asked.count, run.copper + (price or 0) * asked.count, run.known and price ~= nil
        if not run.names[asked.name] then
            run.names[asked.name], run.names[#run.names + 1] = true, asked.name
        end
        run.asked = nil
    end
    if ns.fightStarted or ns.Adapter.InCombat() then
        return finish("a fight started")
    elseif not run.press and ns.Automation.Paused() then
        return finish("automation is paused")
    end
    local thing = Model.NextSale(things, ns.Adapter.JunkMarks(), Model.Needs(ns.Adapter.QuestLog()))
    if not thing then
        return finish("nothing marked is left")
    end
    local ok, why = ns.Adapter.SellBagItem(thing)
    if not ok then
        return finish(why)
    end
    run.asked = thing
    note("asked the vendor to buy " .. thing.name .. " x" .. thing.count .. (run.sold == 0 and " (the gray sale was waited for: "
        .. tostring(run.waited) .. ")" or ""), "asked")
    local mine = run
    C_Timer.After(Model.ANSWER, function()
        if run == mine and run.asked == thing then
            ns.Call("JunkSell", finish, "the game gave no answer for " .. thing.name .. " in " .. Model.ANSWER .. " seconds")
        end
    end)
end

-- press: the Merchant View's X asked for it, not the vendor's opening.
local function start(press)
    if run or not ((press or get("helpers.sell_junk")) and get("helpers.mark_junk")) then
        return false
    end
    local grays = ns.Adapter.GraySalePending()
    run = { grays = grays, waited = grays, sold = 0, copper = 0, known = true, names = {}, press = press }
    ns.On("BAG_UPDATE_DELAYED", "JunkSell", step)
    step()
    return true
end

-- The Merchant View's X: the marked stacks are sold after the game's own sale of the gray items,
-- one at a time. True when a run began (none runs already).
function JunkSell.Sell()
    return start(true)
end

function JunkSell.OnLogin()
    ns.On("MERCHANT_SHOW", "JunkSell", function()
        -- the view of the held button is read at the opening; the start waits one frame, so the
        -- game's window shows and its own gray sale has been asked for
        if not ns.Adapter.ViewHeld() then
            C_Timer.After(0, function()
                ns.Call("JunkSell", start)
            end)
        end
    end)
    ns.On("MERCHANT_CLOSED", "JunkSell", function()
        if run then
            finish("the vendor closed")
        end
    end)
    ns.On("PLAYER_REGEN_DISABLED", "JunkSell", function()
        if run then
            finish("a fight started")
        end
    end)
end
