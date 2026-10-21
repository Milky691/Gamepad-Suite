-- Low Battery Warning: one chat line when the controller's battery runs low, once in a session.
-- In combat the line waits for the end of combat. The game tells of each change of the battery's
-- level, and the level at login is read one time: nothing is asked on a timer. Off at the start.
-- The line comes only for a drop the game tells of after a plain Medium or High: a controller that
-- reports no battery (a Steam Deck gives Unknown at login and Critical six seconds later, the
-- owner's 0.28.1 log) and a level read at login never warn. Wired or Unknown ends what a Medium or
-- High told. The log (kind "battery") has the first levels the game gave, so one session tells
-- whether this controller reports its battery at all.
local _, ns = ...

local Battery = ns.Module("Battery", { "battery" }, "Low Battery Warning")
ns.Battery = Battery

local told = false
local notes = 0
local plain = false     -- the last level that told the charge was Medium or High, with no Wired or Unknown after it
local why = false       -- the log said once why a low level gave no line

local function tell()
    ns.Off("PLAYER_REGEN_ENABLED", "Battery")
    ns.Print("Your controller battery is low.")
end

local function heard(level, login)
    if notes < 4 then
        notes = notes + 1
        ns.Log.Add("battery", "the game gives the battery level " .. tostring(level) .. " (0 and 1 are low, 4 is a cable, 5 is unknown)")
    end
    local low = ns.Adapter.BatteryLow(level)
    if ns.Adapter.BatteryPlain(level) then
        plain = true
    elseif level ~= nil and not low then
        plain = false
    end
    if told or login or not low or not ns.Registry.Get("feel.battery_note") then
        return
    elseif not plain then
        if not why then
            why = true
            ns.Log.Add("battery", "a low level came with no Medium or High before it: no line")
        end
        return
    end
    told = true
    if ns.Adapter.InCombat() then
        ns.On("PLAYER_REGEN_ENABLED", "Battery", tell)
    else
        tell()
    end
end

function Battery.OnLogin()
    ns.On("GAME_PAD_POWER_CHANGED", "Battery", function(level)
        heard(level)
    end)
    heard(ns.Adapter.BatteryLevel(), true)
end
