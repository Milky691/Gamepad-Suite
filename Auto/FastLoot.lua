-- Fast Loot: when a loot window opens, everything in it that is free for the player goes to the
-- bags at once, with the game's own call for one slot (Core/AdapterVendor.lua). An item that
-- binds on pickup still asks first: the game shows its own question, and the addon never answers
-- it. A slot locked to the player (a roll, another player's loot) stays. With no free bag slot
-- only the coins are taken, and one chat line says so: the game's own loot window would stop at
-- its first red line (Blizzard_UIPanels_Game/Mainline/LootFrame.lua 190 to 197), and the items
-- stay for the player's hand or Destroy Gray Item. Holding View as the
-- window opens leaves it all to the player, as Pause Automation does. Off at the start.
--
-- With Fast Loot off the game's own auto loot works as it does with the game's own Interact: the
-- game takes the loot by itself when the player's setting says so. The suite's Interact does not
-- set that for each loot as the game's own does, so it is set here at login, after each loot and
-- when the player changes the setting (Core/AdapterRolls.lua says why).
--
-- The work is done at the game's event that the loot is ready, once for each loot window (the
-- game can say it twice). The log (kind "loot") has, for the first few windows, what the game
-- said of its own auto loot and what Fast Loot took.
local _, ns = ...

local Loot = ns.Module("FastLoot", { "fastLoot" }, "Fast Loot")
ns.FastLoot = Loot

local taken = false   -- this loot window was looted already
local seen = false    -- this loot window is in the log already
local notes = 0
local setting         -- the player's auto loot setting, as it was set for the game at the last look

local function settle()
    setting = ns.Adapter.AutoLootRest()
end

function Loot.OnLogin()
    settle()
    ns.Adapter.OnAutoLootSetting(settle)
    ns.On("LOOT_READY", "FastLoot", function(auto)
        if not seen and notes < 6 then
            notes = notes + 1
            ns.Log.Add("loot", "a loot is ready; the game loots it by itself: " .. tostring(auto) .. " (auto loot in the player's settings: "
                .. tostring(setting) .. "); Fast Loot " .. (ns.Registry.Get("helpers.fast_loot") and "on" or "off"))
        end
        seen = true
        if taken or not ns.Registry.Get("helpers.fast_loot") or ns.Adapter.ViewHeld() or ns.Automation.Paused() then
            return
        end
        taken = true
        -- with no free slot each item would only bring the game's red line: the coins alone
        local full = ns.Adapter.BagSpace() == 0
        local took, locked, left = ns.Adapter.LootAll(full)
        if full and took + left > 0 then
            ns.Print("Fast Loot: bags full. " .. (took > 0 and "The coins were taken." or "Nothing was taken."))
        end
        if notes < 6 then
            notes = notes + 1
            ns.Log.Add("loot", full and "fast loot took " .. took .. " slot" .. (took == 1 and "" or "s") .. " (coins); " .. left .. " items left: the bags are full"
                or "fast loot took " .. took .. " slots; " .. locked .. " were locked to the player")
        end
    end)
    ns.On("LOOT_CLOSED", "FastLoot", function()
        taken, seen = false, false
        settle()
    end)
end
