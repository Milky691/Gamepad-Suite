-- Weapon Items: a rogue's poison, a caster's oil, a warrior's stone. Its use leaves the game waiting for a weapon, and
-- the character window trip is 5 to 9 presses. When a use of ours (an item bind on a button or in a fixed slot: the
-- "press" of the bind core and the slots, with an item) leaves the game waiting for an item, the pop-up
-- (Screen/Popup.lua) names the item and offers the hands that hold a weapon: "Hold for main hand" on Y, "Hold for off
-- hand" on X (an off hand with a shield gets no hint). The let-go gives the waiting use that weapon
-- (Core/AdapterWeapon.lua). A wrong pairing is the game's to refuse with its own red line.
--
-- The Consumables Wheel needs none: its entry gives the main hand by itself (Core/ConsumableRules.lua Text), and Item
-- Actions works in the bags, where the game's own X gives a waiting use its item.
-- Not after a spell that waits for an item (Disenchant, Pick Lock: no use of ours), not from a profession window, not
-- for food or a potion (nothing waits), not while a game window has the controller (the game's own X in the bags gives
-- a waiting use its item; the pop-up waits 10 seconds and shows only if the use still waits). Once for each use. It goes
-- after 10 seconds, at the let-go, and when the wait ends (CURRENT_SPELL_CAST_CHANGED: the player pressed something
-- else). In combat it waits for the end, and shows only if the use still waits. While a loot roll card shows, X is its
-- Greed: the off hand's hint is dim (Screen/PopupHold.lua).
--
-- If the weapon does not take the use at the let-go (the use still waits one frame later), the hold turns to "hold,
-- let go, press" for the session, and the press clicks a secure button of ours whose click gives that slot's weapon;
-- if even that fails, the hand's hold is off for the session with one chat line. The log (kind "weapon") has the first
-- offer and each way's first result.
--
-- It has no row, as the battleground's buttons have none: it shows only after the player's own use left the game
-- waiting, once for each use, and goes when the wait ends, so it never stands unasked (the Pop-ups page holds five rows
-- and Back: build_plan/packs/P42_popups_fix.md).
local _, ns = ...

local Weapon = ns.Module("WeaponItem", { "secure", "weaponItems" }, "Weapon Items")
ns.WeaponItem = Weapon

local SECONDS, WAIT = 10, 10
local MAIN, OFF = 16, 17

local told = {}
local function note(kind, text)
    if not told[kind] then
        told[kind] = true
        ns.Log.Add("weapon", text)
    end
end

-- The act of one hand.
local function hand(slot, key, words)
    local way   -- how the last act gave the weapon, for the log
    return { key = key, words = "Hold for " .. words, go = "Let go for " .. words, steps = "Hold, let go, press: " .. words,
        again = "Press once more: " .. words, fight = (words:gsub("^%l", string.upper)) .. " after combat", fallback = "press",
        log = "weapon " .. slot,
        line = "Weapon Items (Screen, Pop-ups): the " .. words .. " hold is off for this session. The weapon did not take the item.",
        can = function()
            local main, off = ns.Adapter.WeaponHands()
            return slot == MAIN and main or slot == OFF and off
        end,
        done = function(_, clicked)
            way = clicked and "a press of our secure button" or "a let-go"
            return clicked or ns.Adapter.GiveHand(slot)
        end,
        check = function()
            local waits = ns.Adapter.SpellWaits()
            note("check " .. slot .. way, way .. " gave slot " .. slot .. "; the use still waited after: " .. tostring(waits))
            return not waits
        end }
end
local ACTS = { hand(MAIN, "Y", "main hand"), hand(OFF, "X", "off hand") }

-- The wait ended (the weapon took it, or the player did something else): the pop-up goes.
local function changed()
    if not ns.Adapter.SpellWaits() then
        ns.Off("CURRENT_SPELL_CAST_CHANGED", "WeaponItem")
        ns.Popup.Hide("weapon")
    end
end

-- One frame after a use of ours: does the game wait for an item, and which hands can take it.
local function look(what)
    if not ns.Adapter.SpellWaits() then
        return
    end
    local main, off = ns.Adapter.WeaponHands()
    note("offer", "a use of ours left the game waiting for an item (" .. tostring(what) .. "); weapons: main " .. tostring(main)
        .. ", off " .. tostring(off))
    if not (main or off) or (ACTS[1].off or not main) and (ACTS[2].off or not off) then
        return
    end
    ns.On("CURRENT_SPELL_CAST_CHANGED", "WeaponItem", changed)
    ns.Popup.Show({ owner = "weapon", title = ns.Adapter.BindItemName(what) or "Weapon item", seconds = SECONDS, wait = WAIT, calm = true,
        key = "Y", acts = ACTS, valid = ns.Adapter.SpellWaits })
end

local function used(what)
    C_Timer.After(0, function()
        ns.Call("WeaponItem", look, what)
    end)
end

function Weapon.OnLogin()
    -- the two secure buttons of the press, made out of a fight
    ns.Queue.Run("WeaponItem", function()
        ACTS[1].secure = ACTS[1].secure or ns.Adapter.HandButton("GamepadSuiteWeaponMain", MAIN)
        ACTS[2].secure = ACTS[2].secure or ns.Adapter.HandButton("GamepadSuiteWeaponOff", OFF)
    end)
    -- a press of an item bind of ours (the bind core's word: "item:" and the item)
    ns.Listen("press", "WeaponItem", function(signature)
        if type(signature) == "string" and signature:find("^item:") then
            used(signature:sub(6))
        end
    end)
end
