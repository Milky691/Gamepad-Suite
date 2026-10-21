-- Hide Error Text: a switch. (The ranked list calls it Hide Error Spam, ControllerForever's name: decision 30.)
-- It hides the game's red lines that come from a press made too soon: not enough rage, energy or mana, not ready
-- yet, out of range, another action in progress, no target. Every other line still shows
-- (inventory full, facing the wrong way). The on-screen buttons show the same states (too far red, no mana blue,
-- cooling gray). Off gives each line back as the game had it.
--
-- It uses the game's own switch for its red line frame (Core/AdapterWorld.lua), one call for each type, at login and
-- when the row changes. Off at login touches nothing of the game's. The log (kind "errors") has one line at the first
-- hide: how many types, and the names this build does not have.
local _, ns = ...

local Spam = ns.Module("ErrorSpam", { "errorTypes" }, "Hide Error Text")
ns.ErrorSpam = Spam

-- The types, as ControllerForever hides them on this game (its ControllerForever_Layout.lua 2794 to 2797). The first
-- eleven are named in the game's own code of this build; a name the build does not have is left out.
local NAMES = {
    "LE_GAME_ERR_OUT_OF_RAGE", "LE_GAME_ERR_OUT_OF_ENERGY", "LE_GAME_ERR_OUT_OF_MANA", "LE_GAME_ERR_OUT_OF_FOCUS",
    "LE_GAME_ERR_OUT_OF_COMBO_POINTS", "LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_SPELL_COOLDOWN", "LE_GAME_ERR_ITEM_COOLDOWN",
    "LE_GAME_ERR_OUT_OF_RANGE", "LE_GAME_ERR_SPELL_OUT_OF_RANGE", "LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS",
    "LE_GAME_ERR_GENERIC_NO_TARGET", "LE_GAME_ERR_NO_ATTACK_TARGET",
}

local hid      -- the types we hid, while the row is on; a type the game hid itself is not ours to give back
local told = false

local function apply()
    local on = ns.Registry.Get("screen.hide_error_spam")
    if on and not hid then
        hid = {}
        local found, missing = ns.Adapter.ErrorTypes(NAMES)
        for _, number in ipairs(found) do
            if not ns.Adapter.ErrorHidden(number) then
                hid[#hid + 1] = number
                ns.Adapter.ShowErrors(number, false)
            end
        end
        if not told then
            told = true
            ns.Log.Add("errors", ("hid %d types of red line (%d were hidden by the game); not in this build: %s"):format(#hid,
                #found - #hid, #missing > 0 and table.concat(missing, ", ") or "none"))
        end
    elseif not on and hid then
        for _, number in ipairs(hid) do
            ns.Adapter.ShowErrors(number, true)
        end
        hid = nil
    end
end

function Spam.OnLogin()
    apply()
    ns.Listen("setting", "ErrorSpam", function(key)
        if key == "screen.hide_error_spam" then
            apply()
        end
    end)
end
