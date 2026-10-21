-- Stay Seated While Eating: while the character eats or drinks, a small push of the left stick
-- does not stand it up (a stick that drifts on a handheld would). A full push that lasts half a
-- second stands it up on purpose. The right stick turns the camera as always. It ends at once
-- when the meal ends, when a fight starts and when a window takes the controller. It steps aside
-- while mouse mode is on or a wheel is open: their own stick frames need the sticks then, and
-- while automation is paused (Auto/Automation.lua). The switch is on the Automation tab, page
-- Duels, Death and Eating.
--
-- The addon knows of the meal by the buff that food and drink give (Core/AdapterExtras.lua).
-- On this game a frame of an addon that takes the sticks takes every stick: one frame cannot
-- keep the left stick and hand the right one on. So for the time of the meal two frames show,
-- the two of a wheel turned round (Screen/WheelModel.lua says why two):
--   the ear hears every stick and hands every stick on to the game;
--   the wall takes every stick it is told of. It is up only from the left stick's own name
--   until it has the walking stick, so the camera's stick comes to the ear.
-- Auto/ExtrasModel.lua has the rule (SeatStick). ControllerForever holds both sticks for a meal
-- and turns the camera by hand; here the camera stays the game's.
--
-- That the wall is up in time is not proved on this game. So each meal gives one line in the
-- log (kind "seated"): how long, what ended it, how far the left stick was pushed, and how
-- often the wall took each stick and how often each passed.
local _, ns = ...

local Seated = ns.Module("Seated", { "auraByName" }, "Stay Seated While Eating")
ns.Seated = Seated

local Model = ns.ExtrasModel

local MAX_NOTES = 12    -- lines of meals for the log in one session

local ear, wall
local ready = false     -- the ear's switch is set: before that the ear would take every stick
local broken = false    -- a fault in the stick's code: the frames stay away, the sticks are the game's
local stood = false     -- the player stood up on purpose in this meal: the stick is free until the meal ends
local full              -- when the full push that is on now began; nil with no full push
local began, most = 0, 0    -- for the log: when the frames came, the left stick's biggest push
local seen = {}         -- what the frames remember in one meal (Model.SeatStick), with the counts for the log
local notes = 0
local wheel             -- the wheel that is open now, or nil

-- Takes the left stick or gives it back, by what the game says now. fight: a fight starts now
-- (the game tells of it before it locks anything). The frames only show and hide here: the
-- game lets that be done at any time.
function Seated.Update(fight)
    fight = fight or ns.Adapter.InCombat()
    -- the game hides buffs from addon code in combat: it is asked out of combat only, and only
    -- while the switch is on
    local on = ns.Registry.Get("auto.stay_seated") and not ns.Automation.Paused()
    local eating = on and not fight and ns.Adapter.Eating()
    if not eating then
        stood = false
    end
    local pointer = ns.Pointer.IsOn()
    local free = ns.Pad.Gameplay() and not wheel and not pointer
    local hold = ready and not broken and Model.Seated(on, eating, free, stood)
    if hold == ear:IsShown() then
        return
    end
    ear:SetShown(hold)
    wall:Hide()
    if hold then
        began, most, full = GetTime(), 0, nil
        seen = { kept = 0, passed = 0, turned = 0, lost = 0 }
    elseif notes < MAX_NOTES then
        notes = notes + 1
        ns.Log.Add("seated", string.format("the left stick was kept for %.1f s; ended by %s; its biggest push was %.2f. Walking stick: the wall took it %d times, it passed %d times. "
            .. "Camera's stick: it passed %d times, the wall took it %d times.", GetTime() - began,
            fight and "a fight" or stood and "a full push" or not on and (ns.Automation.Paused() and "Pause Automation" or "the switch") or not eating and "the end of the meal"
            or wheel and "a wheel" or pointer and "mouse mode" or "a window", most, seen.kept, seen.passed, seen.turned, seen.lost))
    end
end

-- The left stick moved while it is kept. A full push that is still on after half a second
-- stands the character up: the stick goes back to the game, and the game does the rest.
local function push(x, y)
    most = math.max(most, math.sqrt(x * x + y * y))
    if not Model.Full(x, y) then
        full = nil
    elseif not full then
        local mine = GetTime()
        full = mine
        C_Timer.After(Model.STAND, function()
            if full == mine and ear:IsShown() then
                stood = true
                ns.Call("Seated", Seated.Update)
            end
        end)
    end
end

-- One stick told to the ear, or to the wall (onWall). The rule says if the wall must be up for
-- the stick that comes next.
local function stick(name, onWall, x, y)
    wall:SetShown(Model.SeatStick(seen, name, onWall, GetTime(), x * x + y * y))
    if name == "Left" then
        push(x, y)
    end
end

-- The script of one of the two frames. After a fault both frames go and stay away.
local function heard(onWall)
    return function(_, name, x, y)
        if not ns.Call("Seated", stick, name, onWall, x or 0, y or 0) then
            broken = true
            wall:Hide()
            ear:Hide()
        end
    end
end

-- A frame with nothing to see. While it shows, it is told of the sticks before the game is.
local function plain(name, strata, onWall)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata(strata)
    f:SetSize(1, 1)
    f:SetPoint("TOPLEFT")
    f:EnableMouse(false)
    f:Hide()
    f:EnableGamePadStick(true)
    f:SetScript("OnGamePadStick", heard(onWall))
    return f
end

function Seated.OnLogin()
    -- the wall is over the ear: when both show, the wall is told
    ear = plain("GamepadSuiteSeated", "BACKGROUND", false)
    wall = plain("GamepadSuiteSeatedWall", "TOOLTIP", true)
    -- The switch that hands a frame's sticks on to the game. The game lets it change out of a
    -- fight only, so it is set one time here (after the fight, for a login in a fight).
    ns.Queue.Run("SeatedEar", function()
        ear:SetPropagateKeyboardInput(true)
        wall:SetPropagateKeyboardInput(false)
        ready = true
        ns.Log.Add("seated", "The ear's switch that hands the sticks on to the game reads " .. tostring(ear:GetPropagateKeyboardInput()) .. ".")
        Seated.Update()
    end)
    local function look()
        Seated.Update()
    end
    -- the player's own buffs only: the game is not asked to tell of anybody else's
    ns.OnUnit("UNIT_AURA", "player", "Seated", look)
    ns.On("PLAYER_REGEN_DISABLED", "Seated", function()
        Seated.Update(true)
    end)
    ns.On("PLAYER_REGEN_ENABLED", "Seated", look)
    ns.On("PLAYER_ENTERING_WORLD", "Seated", look)
    ns.Listen("pad", "Seated", look)
    ns.Listen("pointer", "Seated", look)
    ns.Listen("automation:paused", "Seated", look)
    ns.Listen("wheel", "Seated", function(id)
        wheel = id or nil
        Seated.Update()
    end)
    ns.Listen("setting", "Seated", function(key)
        if key == "auto.stay_seated" then
            Seated.Update()
        end
    end)
end
